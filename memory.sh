#!/usr/bin/env bash
# memory.sh - SQLite-backed memory for YASH

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MEMORY_DB="${MEMORY_DB:-$SCRIPT_DIR/memory.db}"

# Initialize database
init() {
    sqlite3 "$MEMORY_DB" "
        CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            role TEXT NOT NULL,
            content TEXT NOT NULL,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE IF NOT EXISTS memory (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            key TEXT UNIQUE NOT NULL,
            value TEXT NOT NULL,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
    "
    echo "Memory initialized at $MEMORY_DB"
}

# Store a message (with proper escaping)
store() {
    local role="$1"
    local content="$2"
    # Escape single quotes in content by doubling them
    local escaped_content="${content//\'/\'\'}"
    sqlite3 "$MEMORY_DB" "INSERT INTO messages (role, content) VALUES ('$role', '$escaped_content');"
}

# Get recent messages (for context window)
recent() {
    local limit="${1:-10}"
    sqlite3 "$MEMORY_DB" "SELECT role, content FROM messages ORDER BY id DESC LIMIT $limit;" | while IFS='|' read -r role content; do
        echo "$role: $content"
    done | tac
}

# Get all messages count
count() {
    sqlite3 "$MEMORY_DB" "SELECT COUNT(*) FROM messages;"
}

# Clear all messages (reset session)
clear() {
    sqlite3 "$MEMORY_DB" "DELETE FROM messages;"
    echo "Session reset - all messages cleared"
}

# Get long-term memory
get_memory() {
    local key="$1"
    sqlite3 "$MEMORY_DB" "SELECT value FROM memory WHERE key='$key';"
}

# Set long-term memory
set_memory() {
    local key="$1"
    local value="$2"
    sqlite3 "$MEMORY_DB" "INSERT OR REPLACE INTO memory (key, value, updated_at) VALUES ('$key', '$value', datetime('now'));"
}

# Compact: summarize old messages
compact() {
    local count="${1:-20}"
    
    # Get oldest N messages
    local old_messages
    old_messages=$(sqlite3 "$MEMORY_DB" "SELECT id, content FROM messages ORDER BY id ASC LIMIT $count;")
    
    if [[ -z "$old_messages" ]]; then
        echo "No messages to compact"
        return
    fi
    
    # Get the max ID we're compacting (the oldest still in the result set)
    local max_id
    max_id=$(echo "$old_messages" | tail -1 | cut -d'|' -f1)
    
    # Extract just the contents for summation
    local contents
    contents=$(echo "$old_messages" | cut -d'|' -f2-)
    
    # Create summary entry
    local summary_file="$SCRIPT_DIR/memory/summaries.md"
    mkdir -p "$(dirname "$summary_file")"
    echo -e "\n### Compaction $(date)\n$contents\n" >> "$summary_file"
    
    # Delete the compacted messages (delete all with id < max_id we kept)
    sqlite3 "$MEMORY_DB" "DELETE FROM messages WHERE id < $max_id;"
    
    echo "Compacted messages up to ID $max_id to $summary_file"
}

# Count tokens (rough estimate: 4 chars ≈ 1 token)
tokens() {
    local text
    text=$(sqlite3 "$MEMORY_DB" "SELECT GROUP_CONCAT(content, '') FROM messages;")
    echo $(( ${#text} / 4 ))
}

case "${1:-}" in
    init) init "$@" ;;
    store) shift; store "$@" ;;
    recent) shift; recent "${1:-10}" ;;
    count) count ;;
    clear|--clear) clear ;;
    get) shift; get_memory "$@" ;;
    set) shift; set_memory "$@" ;;
    compact) shift; compact "${1:-10}" ;;
    tokens) tokens ;;
    *) echo "Usage: $0 {init|store <role> <content>|recent [limit]|count|clear|get <key>|set <key> <value>|compact|tokens}"
esac