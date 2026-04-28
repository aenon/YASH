#!/usr/bin/env bash
# tui.sh - Terminal UI for YASH

set -euo pipefail

SPINNER_FILE="/tmp/yash_spinner.pid"

# Start blinking dots spinner
start_spinner() {
    local current_pid
    current_pid=$(cat "$SPINNER_FILE" 2>/dev/null)
    
    # Don't show if already running
    if [[ -n "$current_pid" ]] && kill -0 "$current_pid" 2>/dev/null; then
        return
    fi
    
    # Blinking dots - use carriage return to stay on same line
    (
        while true; do
            printf "\r   \r"     # Spaces to clear
            sleep 0.3
            printf "\r.  \r"
            sleep 0.3
            printf "\r.. \r"
            sleep 0.3
            printf "\r...\r"
            sleep 0.3
        done
    ) &
    echo $! > "$SPINNER_FILE"
}

# Stop spinner and print newline
stop_spinner() {
    local current_pid
    current_pid=$(cat "$SPINNER_FILE" 2>/dev/null)
    
    if [[ -n "$current_pid" ]]; then
        kill "$current_pid" 2>/dev/null || true
        rm -f "$SPINNER_FILE"
        echo ""  # Newline after spinner
    fi
}

# Try dialog, fall back to read
prompt_user() {
    if command -v dialog >/dev/null 2>&1; then
        dialog --title "YASH" --inputbox "Your request:" 10 60 2>/tmp/yash_input.txt
        cat /tmp/yash_input.txt
    else
        local input
        read -r -p "You: " input || {
            # Ctrl-D pressed - print newline
            echo ""
            exit 1
        }
        echo "$input"
    fi
}

display_msg() {
    local msg="$1"
    if command -v dialog >/dev/null 2>&1; then
        dialog --title "YASH" --msgbox "$msg" 15 70
    else
        echo -e "YASH: $msg"
    fi
}

display_error() {
    local error="$1"
    if command -v dialog >/dev/null 2>&1; then
        dialog --title "YASH Error" --msgbox "$error" 10 50
    else
        echo "ERROR: $error" >&2
    fi
}

case "${1:-}" in
    prompt) prompt_user ;;
    display) shift; display_msg "$*" ;;
    error) shift; display_error "$*" ;;
    spinner) start_spinner ;;
    stop) stop_spinner ;;
    *) echo "Usage: $0 {prompt|display <msg>|error <msg>|spinner|stop}"
esac