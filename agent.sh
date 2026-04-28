#!/usr/bin/env bash
# agent.sh - Main YASH agent entry point

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="${WORKSPACE_DIR:-$SCRIPT_DIR}"
CONTEXT_FILE="${CONTEXT_FILE:-$SCRIPT_DIR/CONTEXT.md}"
MEMORY_FILE="${MEMORY_FILE:-$SCRIPT_DIR/messages.log}"
MAX_TOKENS="${MAX_TOKENS:-4000}"

# Load config (supports both .env and config.env for backward compatibility)
load_config() {
    if [[ -f "$SCRIPT_DIR/.env" ]]; then
        set -a
        source "$SCRIPT_DIR/.env"
        set +a
    elif [[ -f "$SCRIPT_DIR/config.env" ]]; then
        set -a
        source "$SCRIPT_DIR/config.env"
        set +a
    fi
}

# Log to heartbeat log
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$SCRIPT_DIR/heartbeat.log"
}

# Initialize memory
init() {
    bash "$SCRIPT_DIR/memory.sh" init
    mkdir -p "$WORKSPACE_DIR"
    echo "YASH initialized"
}

# Call LLM API
call_llm() {
    local system_prompt="$1"
    local user_message="$2"
    
    local api_key="${OPENAI_API_KEY:-}"
    local api_base="${LLM_API_BASE:-https://api.openai.com/v1}"
    local model="${LLM_MODEL:-gpt-4}"
    
    if [[ -z "$api_key" ]]; then
        echo "ERROR: OPENAI_API_KEY not set" >&2
        return 1
    fi
    
    # Build messages
    local messages_json
    messages_json=$(jq -cn \
        --arg system "$system_prompt" \
        --arg user "$user_message" \
        '[{"role": "system", "content": $system}, {"role": "user", "content": $user}]')
    
    # Call API
    local response
    response=$(curl -sS -X POST "$api_base/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $api_key" \
        -d "$(jq -cn --arg model "$model" --argjson messages "$messages_json" '{model: $model, messages: $messages}')" )
    
    # Extract response
    echo "$response" | jq -r '.choices[0].message.content'
}

# Check token count and compact if needed
check_tokens() {
    local tokens
    tokens=$(bash "$SCRIPT_DIR/memory.sh" tokens)
    
    if [[ "$tokens" -gt "$MAX_TOKENS" ]]; then
        log "Compacting memory (tokens: $tokens > $MAX_TOKENS)"
        bash "$SCRIPT_DIR/memory.sh" compact
    fi
}

# Get recent context from memory
get_recent_context() {
    bash "$SCRIPT_DIR/memory.sh" recent 20
}

# Reset session
reset_session() {
    log "Resetting session"
    bash "$SCRIPT_DIR/memory.sh" clear
    echo "Session reset. Context preserved."
}

# Main conversation loop
run() {
    load_config
    
    # Initialize if needed
    if [[ ! -f "$MEMORY_FILE" ]]; then
        init
    fi
    
    # Start heartbeat in background
    bash "$SCRIPT_DIR/heartbeat.sh" run &
    local heartbeat_pid=$!
    log "YASH started (PID: $heartbeat_pid)"
    
    # Load context
    local context
    context=$(cat "$CONTEXT_FILE")
    
    echo "YASH - Type 'reset' to clear session, 'quit' to exit"
    echo "---"
    
    while true; do
        # Get user input
        local user_input
        user_input=$(bash "$SCRIPT_DIR/tui.sh" prompt)
        
        # Handle commands
        case "$user_input" in
            quit|exit)
                echo "Goodbye!"
                kill "$heartbeat_pid" 2>/dev/null || true
                exit 0
                ;;
            reset|--reset)
                reset_session
                continue
                ;;
        esac
        
        # Skip empty
        if [[ -z "$user_input" ]]; then
            continue
        fi
        
        # Check and compact if needed
        check_tokens
        
        # Get recent messages for context
        local recent_messages
        recent_messages=$(get_recent_context)
        
        # Build full prompt with context
        local full_prompt="$context

## Recent Conversation
$recent_messages

## Task
$user_input"
        
        # Call LLM
        local response
        response=$(call_llm "" "$full_prompt") || {
            bash "$SCRIPT_DIR/tui.sh" error "Failed to get response from LLM"
            continue
        }
        
        # Show response
        bash "$SCRIPT_DIR/tui.sh" display "$response"
        
        # Store interaction
        bash "$SCRIPT_DIR/memory.sh" store "user" "$user_input"
        bash "$SCRIPT_DIR/memory.sh" store "assistant" "$response"
    done
}

# Handle command line
case "${1:-}" in
    init) init ;;
    run) run ;;
    reset|--clear) reset_session ;;
    compact) bash "$SCRIPT_DIR/memory.sh" compact ;;
    *) echo "YASH - Yet Another Shell Agent"
       echo ""
       echo "Usage: $0 {init|run|reset|compact}"
esac