#!/bin/bash
# ==========================================================
#  Communication Logger (Clean Plaintext Demo)
#  Author: Jackson Newton
#  Purpose: Log plaintext messages with MAC/IP tracking
# ==========================================================

set -euo pipefail

# --- Folder Setup ---
STORE_ROOT="./messages"
QUEUE="./queue/inbox"
CHAIN_LOG="./Communication_Logger/chain_of_custody.log"

# Ensure directories exist
mkdir -p "$STORE_ROOT" "$QUEUE" "$(dirname "$CHAIN_LOG")"

# --- Function: Draw a visual separator ---
separator() {
    echo "------------------------------------------------------------" | tee -a "$CHAIN_LOG"
}

# --- Function: Log network state ---
log_network_state() {
    local ts=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "\n[$ts] [INFO] 🌐 Network Snapshot" | tee -a "$CHAIN_LOG"
    separator

    for iface in $(ifconfig -l); do
        mac=$(ifconfig "$iface" 2>/dev/null | awk '/ether/{print $2}' | head -1)
        ip=$(ifconfig "$iface" 2>/dev/null | awk '/inet /{print $2}' | head -1)
        [ -z "$mac" ] && mac="unknown"
        [ -z "$ip" ] && ip="N/A"
        printf "  %-10s →  MAC: %-17s | IP: %s\n" "$iface" "$mac" "$ip" | tee -a "$CHAIN_LOG"
    done
    separator
}

# --- Function: Process new message files ---
process_message() {
    local FILE="$1"
    local ts=$(date +"%Y-%m-%d %H:%M:%S")
    local id=$(date +%s)-$RANDOM
    local dest="$STORE_ROOT/msg_${id}.txt"

    echo -e "\n[$ts] [INFO] 📨 New Message Detected: $FILE" | tee -a "$CHAIN_LOG"
    separator

    # Copy plaintext message instead of encrypting
    if cp "$FILE" "$dest"; then
        echo "[$ts] [SUCCESS] Stored plaintext message at: $dest" | tee -a "$CHAIN_LOG"

        echo -e "\n[$ts] [INFO] 📄 Message Content:" | tee -a "$CHAIN_LOG"
        separator
        cat "$FILE" | sed 's/^/    /' | tee -a "$CHAIN_LOG"
        separator

        # Compute hash
        echo -e "\n[$ts] [INFO] 🔒 SHA-256 Hash Verification" | tee -a "$CHAIN_LOG"
        (sha256sum "$dest" 2>/dev/null || shasum -a 256 "$dest") | tee -a "$CHAIN_LOG"

        # Remove original plaintext from inbox
        rm -f "$FILE"
        echo -e "\n[$ts] [INFO] 🧹 Removed message from inbox: $FILE" | tee -a "$CHAIN_LOG"
    else
        echo "[$ts] [ERROR] ❌ Failed to process message: $FILE" | tee -a "$CHAIN_LOG"
        return 1
    fi

    # Log network info for this message
    log_network_state
}

# --- Function: Monitor queue for new files ---
monitor_queue() {
    echo "📡 Monitoring $QUEUE for new messages..."
    echo "Press Ctrl+C to stop."
    mkdir -p "$QUEUE"

    while true; do
        for NEWFILE in "$QUEUE"/*; do
            [ -e "$NEWFILE" ] || { sleep 2; continue; }
            process_message "$NEWFILE"
        done
        sleep 2
    done
}

# --- Script Entry Point ---
separator
echo "[INFO] Communication Logger (Plaintext Demo) Started: $(date)" | tee -a "$CHAIN_LOG"
echo "[INFO] Watching directory: $QUEUE" | tee -a "$CHAIN_LOG"
separator

monitor_queue
