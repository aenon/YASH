# YASH - Yet Another Small Harness

A minimal long-running AI agent written in pure shell scripts with markdown-based configuration.

## Requirements

### Core Features

1. **LLM Connectivity**
   - Connect to any OpenAI-compatible LLM endpoint via HTTP
   - Support custom API keys and base URLs
   - Configurable model selection

2. **Memory System**
   - SQLite-backed conversation history storage
   - Long-term memory (MEMORY.md style facts)
   - Context compaction when approaching token limits
   - Session persistence across restarts

3. **Heartbeat/Cron**
   - Periodic health checks with timestamp logging
   - Optional systemd watchdog integration
   - Configurable heartbeat interval

4. **Local TUI**
   - Terminal-based user interface via `dialog`
   - Interactive prompt input
   - Response display with markdown rendering

5. **Manual Session Reset**
   - User-triggered session clear
   - Reset memory while preserving system config

### System Context File

All configuration consolidated into `CONTEXT.md`:

```markdown
# CONTEXT.md - Agent Configuration

## IDENTITY (SOUL)
You are YASH, a minimal AI agent running on Linux shell.
You help users with tasks, research, and automation.

## USER
[User context - name, preferences, important facts]

## AGENTS
[Agent rules and operational guidelines]

## TOOLS
You have access to these tools. Execute them to interact with the system.

### 1. File Read
Read any file in the workspace directory.
```bash
cat /workspace/TOOL/file_path
```
Returns the full contents of the file.

### 2. File Write
Write content to a file in the workspace. Creates or overwrites.
```bash
echo "content here" > /workspace/TOOL/file_path
```
Constrained to workspace directory only.

### 3. Command Execution
Run whitelisted commands only. No destructive operations.
```bash
COMMAND_WHITELIST="ls cat grep sed jq curl awk"
# Must match whitelist before execution
```

### 4. File-based Memory

```bash
bash memory.sh recent 10    # read recent
bash memory.sh store user "hello"  # write
bash memory.sh count      # count messages
bash memory.sh clear     # clear session
```

## HEARTBEAT
[Heartbeat schedule and health checks]
```

## Architecture

### File Structure

| File | Purpose |
|------|---------|
| `agent.sh` | Main entry point, LLM loop, orchestration |
| `memory.sh` | SQLite storage, compaction logic |
| `tui.sh` | Terminal UI |
| `CONTEXT.md` | Consolidated context (SOUL+AGENTS+USER+TOOL+HEARTBEAT) |
| `config.env` | API keys, settings |

### Components

1. **agent.sh**
   - Loads CONTEXT.md into system prompt
   - Manages heartbeat process
   - Handles user input via TUI
   - Calls LLM API
   - Stores to memory
   - Implements context compaction

2. **memory.sh**
   - SQLite initialization
   - Conversation storage/retrieval
   - Context window management
   - Compaction logic (summarization)

3. **tui.sh**
   - Dialog-based input
   - Markdown rendering
   - Session controls

### Context Compaction

When token count exceeds threshold:
1. Retrieve oldest N messages
2. Generate summary via LLM
3. Replace original messages with summarized version
4. Externalize to `memory/summaries.md`

## Configuration

### config.env

```bash
# LLM Settings
OPENAI_API_KEY=sk-xxx
LLM_API_BASE=https://api.openai.com/v1
LLM_MODEL=gpt-4

# Memory
MAX_TOKENS=4000
MEMORY_DB=./memory.db

# Heartbeat
HEARTBEAT_INTERVAL=30
```

## Usage

```bash
# Install dependencies
sudo apt install curl awk jq dialog

# Initialize
bash memory.sh init

# Run
bash agent.sh

# Reset session
bash agent.sh reset

# Compact memory
bash memory.sh compact
```

## Comparison to OpenClaw
| Feature | OpenClaw | YASH |
|---------|----------|------|
| Files | 18 repos | 5 files |
| Language | TypeScript | Bash |
| Skills | 5,700+ | Minimal |
| Channels | 8+ | Terminal |
| Memory | SQLite + embeddings | SQLite |
| Compaction | Automatic | Automatic |
| Context | Multi-file | Single file |

## Philosophy: Thin Agent Experiment
YASH explores **minimal scaffolding**: how thin can an AI agent be when the model is strong?
### Hypothesis
Modern LLMs (GPT-4, Claude 3, Gemini) are capable reasoners. They can sequence actions, follow instructions, and self-correct without hardcoded ReAct loops, explicit tool schemas, or deterministic state machines.
### Approach
| Traditional Agent | YASH |
|----------------|------|
| Build logic into code | Write instructions in CONTEXT.md |
| Explicit error handling | "Don't break things" |
| Tool schemas in JSON | Tool docs in markdown |
| State machines | Model figures it out |
### What This Tests
1. At what point does the model break without scaffolding?
2. When does it need explicit schemas vs. natural language?
3. How thin can you go before reliability suffers?
4. How much complexity can be offloaded to clear instructions?
### References
- Anthropic: "The model is the computer"
- Andrej Karpathy: "LLMs are the runtime"
- This repo: "CONTEXT.md IS the agent"