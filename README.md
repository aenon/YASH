# YASH - Yet Another Shell Agent

A minimal long-running AI agent in 4 shell scripts + 1 context file.

## Files

| File | Description |
|------|-------------|
| `agent.sh` | Main entry point, LLM loop |
| `memory.sh` | SQLite storage, compaction |
| `tui.sh` | Terminal UI |
| `heartbeat.sh` | Health check process |
| `CONTEXT.md` | Agent configuration |
| `.env` | API keys (create from `.env.example`) |

## Quick Start

```bash
# 1. Copy config
cp .env.example .env

# 2. Edit config - add your OPENAI_API_KEY
nano .env

# 3. Initialize
bash agent.sh init

# 4. Run
bash agent.sh run
```

## Commands

| Command | Description |
|---------|-------------|
| `bash agent.sh init` | Initialize memory database |
| `bash agent.sh run` | Start the agent |
| `bash agent.sh reset` | Clear session, keep config |
| `bash agent.sh compact` | Compact memory |

## Dependencies

- `bash` (4+)
- `python3` (for memory - stdlib only, no sqlite3 CLI needed)
- `curl`
- `dialog` (optional, for TUI)

Install: `sudo apt install curl dialog` (python3 usually pre-installed)

## Philosophy

YASH is a **thin agent** experiment - minimal scaffolding, maximum delegation to the LLM.

See `SPEC.md` for full design documentation.

## Security Notes

- Never commit `.env` - it's in `.gitignore`
- Command whitelist restricts execution
- All operations sandboxed to workspace