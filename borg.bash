#!/bin/bash

set -xe

# Check if argument provided
if [[ $# -ne 1 ]]; then
    echo "Error: Please provide the path to the variable file"
    echo "Usage: $0 /path/to/variables.conf"
    exit 1
fi

VAR_FILE="$1"

# Check if variable file exists
if [[ ! -f "$VAR_FILE" ]]; then
    echo "Error: Variable file '$VAR_FILE' does not exist"
    exit 1
fi

# Source the variable file
source "$VAR_FILE"

# Validate required variables are set
REQUIRED_VARS=("BORG_REPO" "BORG_PASSPHRASE" "BACKUP_DIRS")
for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var}" ]]; then
        echo "Error: Required variable '$var' is not set in $VAR_FILE"
        exit 1
    fi
done
export BORG_REPO BORG_PASSPHRASE

# Set default values for optional variables
KEEP_DAILY="${KEEP_DAILY:-7}"
KEEP_WEEKLY="${KEEP_WEEKLY:-4}"
KEEP_MONTHLY="${KEEP_MONTHLY:-6}"
CHECK_FREQUENCY="${CHECK_FREQUENCY:-7}"
COMPACT_DAY="${COMPACT_DAY:-01}"

echo "[INFO] Using configuration from: $VAR_FILE"
echo "[INFO] Backing up: $BACKUP_DIRS to $BORG_REPO"

# check optimizations
if [[ -n "$OPT_COMPRESSION" ]]; then
    OPT_COMPRESSION="--compression $OPT_COMPRESSION"
fi
if [[ -n "$OPT_CHUNKER" ]]; then
    OPT_CHUNKER="--chunker-params $OPT_CHUNKER"
fi
borg create --verbose --stats     \
    $OPT_COMPRESSION $OPT_CHUNKER \
    --exclude-caches              \
    ::'{now:%Y-%m-%d_%H:%M}'      \
    "$BACKUP_DIRS"

borg prune -v --list --stats       \
    ::                             \
    --keep-daily="$KEEP_DAILY"     \
    --keep-weekly="$KEEP_WEEKLY"   \
    --keep-monthly="$KEEP_MONTHLY"

# === PERIODIC CHECK ===
# Run `borg check` once every 7 days
if [[ $(date +%u) -eq $CHECK_FREQUENCY ]]; then
    echo "[INFO] Running borg check..."
    borg check --verbose ::
fi

# === PERIODIC COMPACT ===
# Run `borg compact` once every 30 days
DAY_OF_MONTH=$(date +%d)
if [[ "$DAY_OF_MONTH" == "$COMPACT_DAY" ]]; then
    echo "[INFO] Running borg compact..."
    borg compact ::
fi

echo "[INFO] Backup completed successfully"
