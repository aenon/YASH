#!/usr/bin/env bash
# heartbeat.sh - Health check process for YASH

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOGFILE="${LOGFILE:-$SCRIPT_DIR/heartbeat.log}"
INTERVAL="${HEARTBEAT_INTERVAL:-30}"

# Check if parent is still running
check_parent() {
    if [[ -n "${PPID:-}" ]] && kill -0 "$PPID" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Log heartbeat
beat() {
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "$timestamp alive" >> "$LOGFILE"
    
    # Notify systemd watchdog if available
    if [[ -n "${WATCHDOG_USEC:-}" ]]; then
        systemd-notify --ready --status="YASH heartbeat" 2>/dev/null || true
    fi
}

# Main loop
run() {
    echo "Heartbeat started (interval: ${INTERVAL}s, log: $LOGFILE)"
    while true; do
        if ! check_parent; then
            echo "Parent process gone, exiting"
            exit 0
        fi
        beat
        sleep "$INTERVAL"
    done
}

case "${1:-}" in
    run) run ;;
    beat) beat ;;
    *) echo "Usage: $0 {run|beat}"
esac