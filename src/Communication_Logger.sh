#!/bin/bash

set -euo pipefail

# --- Folder Setup ---
STORE_ROOT="./messages"
QUEUE="./queue/inbox"
CHAIN_LOG="./chain_of_custody.log"

mkdir -p "$STORE_ROOT" "$QUEUE" "$(dirname "$CHAIN_LOG")"

# --- Visual Separator ---
separator() {
    echo "------------------------------------------------------------" | tee -a "$CHAIN_LOG"
}

# --- Function: Log network state ---
log_network_state() {
    local ts=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "\n[$ts] [INFO] 🌐 Network Snapshot" | tee -a "$CHAIN_LOG"
    separator

    for iface in $(ip -o link show | awk -F': ' '{print $2}'); do
        mac=$(ip link show "$iface" | awk '/link\/ether/{print $2}')
        ip=$(ip -o -4 addr show "$iface" | awk '{print $4}')
        [ -z "$mac" ] && mac="unknown"
        [ -z "$ip" ] && ip="N/A"
        printf "  %-10s → MAC: %-17s | IP: %s\n" "$iface" "$mac" "$ip" | tee -a "$CHAIN_LOG"
    done

    separator
}

# --- Function: Process new encrypted message file ---
process_message() {
    local FILE="$1"
    local ts=$(date +"%Y-%m-%d %H:%M:%S")
    local id=$(date +%s)-$RANDOM
    local dest="$STORE_ROOT/msg_${id}.txt"

    # Extract fields
    USER=$(grep 'USER=' "$FILE" | cut -d'=' -f2)
    MAC=$(grep 'MAC=' "$FILE" | cut -d'=' -f2)
    CIPHERTEXT=$(grep 'CIPHERTEXT=' "$FILE" | cut -d'=' -f2)
    IV=$(grep 'IV=' "$FILE" | cut -d'=' -f2)

    echo -e "\n[$ts] [INFO] 📨 New Encrypted Message Detected: $FILE" | tee -a "$CHAIN_LOG"
    separator

    # Save encrypted copy inside messages/
    if cp "$FILE" "$dest"; then
        echo "[$ts] [SUCCESS] Stored encrypted message at: $dest" | tee -a "$CHAIN_LOG"

        echo -e "\n[$ts] [INFO] 🔐 Encrypted Message Log" | tee -a "$CHAIN_LOG"
        separator
        echo "User: $USER" | tee -a "$CHAIN_LOG"
        echo "Source MAC: $MAC" | tee -a "$CHAIN_LOG"
        echo "Ciphertext: $CIPHERTEXT" | tee -a "$CHAIN_LOG"
        echo "AES IV: $IV" | tee -a "$CHAIN_LOG"
        separator

        # Hashing for integrity
        echo -e "\n[$ts] [INFO] 🔒 SHA-256 Hash Verification" | tee -a "$CHAIN_LOG"
        (sha256sum "$dest" 2>/dev/null || shasum -a 256 "$dest") | tee -a "$CHAIN_LOG"

        # Delete inbox file
        rm -f "$FILE"
        echo -e "\n[$ts] [INFO] 🧹 Removed inbox file: $FILE" | tee -a "$CHAIN_LOG"
    else
        echo "[$ts] [ERROR] ❌ Failed to store: $FILE" | tee -a "$CHAIN_LOG"
        return 1
    fi

    # Add network logging
    log_network_state
}

# --- Monitor queue ---
monitor_queue() {
    echo "📡 Monitoring $QUEUE for new encrypted messages..."
    echo "Press Ctrl+C to stop."
    mkdir -p "$QUEUE"

    while true; do
        for NEWFILE in "$QUEUE"/*; do
            [ -e "$NEWFILE" ] || { sleep 1; continue; }
            process_message "$NEWFILE"
        done
        sleep 1
    done
}

# --- Script Start ---
separator
echo "[INFO] Encrypted Communication Logger Started: $(date)" | tee -a "$CHAIN_LOG"
echo "[INFO] Watching directory: $QUEUE" | tee -a "$CHAIN_LOG"
separator

monitor_queue
