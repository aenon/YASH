#!/usr/bin/env bash
# tui.sh - Terminal UI for YASH

set -euo pipefail

# Try dialog, fall back to read
prompt_user() {
    if command -v dialog >/dev/null 2>&1; then
        dialog --title "YASH" --inputbox "Your request:" 10 60 2>/tmp/yash_input.txt
        cat /tmp/yash_input.txt
    else
        read -p "You: " input
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
    *) echo "Usage: $0 {prompt|display <msg>|error <msg>}"
esac