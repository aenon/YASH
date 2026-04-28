#!/usr/bin/env bash
# memory.sh - File-based memory for YASH
# Simpler than SQLite - just a plain text log

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEMORY_FILE="${MEMORY_FILE:-$SCRIPT_DIR/messages.log}"

# Initialize - create empty log
init() {
    touch "$MEMORY_FILE"
    echo "Memory initialized at $MEMORY_FILE"
}

# Store a message (append to log)
store() {
    local role="$1"
    local content="$2"
    # Escape newlines for single-line JSON
    local escaped_content="${content//$'\n'/\\n}"
    echo "{\"role\":\"$role\",\"content\":\"$escaped_content\"}" >> "$MEMORY_FILE"
}

# Get recent messages (last N lines)
recent() {
    local limit="${1:-10}"
    tail -n "$limit" "$MEMORY_FILE" | while IFS= read -r line; do
        # Extract using awk - simple field parsing
        role=$(echo "$line" | awk -F'"role":"' '{split($2,a,"\""); print a[1]}')
        content=$(echo "$line" | awk -F'"content":"' '{split($2,a,"\""); print a[1]}')
        echo "$role: $content"
    done
}

# Count messages
count() {
    wc -l < "$MEMORY_FILE" 2>/dev/null || echo 0
}

# Clear all messages
clear() {
    : > "$MEMORY_FILE"
    echo "Session reset - all messages cleared"
}

# Get/set long-term memory (key-value in files)
get_memory() {
    local key="$1"
    local mem_file="$SCRIPT_DIR/memory_$key"
    cat "$mem_file" 2>/dev/null || echo ""
}

set_memory() {
    local key="$1"
    local value="$2"
    local mem_file="$SCRIPT_DIR/memory_$key"
    echo "$value" > "$mem_file"
}

# Compact - summarize old messages to a file, then truncate
compact() {
    local count="${1:-20}"
    local summary_file="$SCRIPT_DIR/memory/summaries.md"
    
    # Get first N lines (oldest messages)
    local old_lines
    old_lines=$(head -n "$count" "$MEMORY_FILE" 2>/dev/null) || return
    
    if [[ -z "$old_lines" ]]; then
        echo "No messages to compact"
        return
    fi
    
    # Write to summary
    mkdir -p "$(dirname "$summary_file")"
    echo -e "\n### Compaction $(date)\n$old_lines\n" >> "$summary_file"
    
    # Remove compacted lines from front
    local total
    total=$(wc -l < "$MEMORY_FILE")
    if [[ "$total" -gt "$count" ]]; then
        tail -n $((total - count)) "$MEMORY_FILE" > "$MEMORY_FILE.tmp"
        mv "$MEMORY_FILE.tmp" "$MEMORY_FILE"
    else
        : > "$MEMORY_FILE"
    fi
    
    echo "Compacted $count messages to $summary_file"
}

# Count tokens (rough estimate: 4 chars ≈ 1 token)
tokens() {
    local text
    text=$(cat "$MEMORY_FILE")
    echo $(( ${#text} / 4 ))
}

case "${1:-}" in
    init) init ;;
    store) shift; store "$@" ;;
    recent) shift; recent "${1:-10}" ;;
    count) count ;;
    clear|--clear) clear ;;
    get) shift; get_memory "$@" ;;
    set) shift; set_memory "$@" ;;
    compact) shift; compact "${1:-20}" ;;
    tokens) tokens ;;
    *) echo "Usage: $0 {init|store <role> <content>|recent [limit]|count|clear|get <key>|set <key> <value>|compact|tokens}"
esac