#!/usr/bin/env python3
# memory.sh - SQLite-backed memory for YASH (Python implementation)
# Works without sqlite3 CLI, uses Python stdlib

import sys
import os
import sqlite3
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
MEMORY_DB = os.environ.get('MEMORY_DB', os.path.join(SCRIPT_DIR, 'memory.db'))

def get_conn():
    return sqlite3.connect(MEMORY_DB)

def init():
    conn = get_conn()
    conn.execute('''CREATE TABLE IF NOT EXISTS messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )''')
    conn.execute('''CREATE TABLE IF NOT EXISTS memory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT UNIQUE NOT NULL,
        value TEXT NOT NULL,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )''')
    conn.commit()
    conn.close()
    print(f"Memory initialized at {MEMORY_DB}")

def store(role, content):
    # Escape single quotes
    content = content.replace("'", "''")
    conn = get_conn()
    conn.execute("INSERT INTO messages (role, content) VALUES (?, ?)", (role, content))
    conn.commit()
    conn.close()

def recent(limit=10):
    conn = get_conn()
    conn.row_factory = sqlite3.Row
    cur = conn.execute(
        "SELECT role, content FROM messages ORDER BY id DESC LIMIT ?", (limit,)
    )
    rows = cur.fetchall()
    conn.close()
    # Return in reverse order (oldest first)
    return '\n'.join(f"{r['role']}: {r['content']}" for r in reversed(rows))

def count():
    conn = get_conn()
    cur = conn.execute("SELECT COUNT(*) FROM messages")
    c = cur.fetchone()[0]
    conn.close()
    return c

def clear():
    conn = get_conn()
    conn.execute("DELETE FROM messages")
    conn.commit()
    conn.close()
    print("Session reset - all messages cleared")

def get_memory(key):
    conn = get_conn()
    cur = conn.execute("SELECT value FROM memory WHERE key=?", (key,))
    row = cur.fetchone()
    conn.close()
    return row[0] if row else ''

def set_memory(key, value):
    conn = get_conn()
    conn.execute(
        "INSERT OR REPLACE INTO memory (key, value, updated_at) VALUES (?, ?, datetime('now'))",
        (key, value)
    )
    conn.commit()
    conn.close()

def compact(count=20):
    conn = get_conn()
    conn.row_factory = sqlite3.Row
    
    # Get oldest N messages
    cur = conn.execute(
        "SELECT id, content FROM messages ORDER BY id ASC LIMIT ?", (count,)
    )
    rows = cur.fetchall()
    
    if not rows:
        print("No messages to compact")
        conn.close()
        return
    
    # Get max_id (oldest in the result set after ordering ASC)
    max_id = rows[-1]['id']
    
    # Extract contents
    contents = '\n'.join(r['content'] for r in rows)
    
    # Write to summary
    summary_file = os.path.join(SCRIPT_DIR, 'memory', 'summaries.md')
    os.makedirs(os.path.dirname(summary_file), exist_ok=True)
    with open(summary_file, 'a') as f:
        f.write(f"\n### Compaction {datetime.now()}\n{contents}\n")
    
    # Delete messages with id < max_id
    conn.execute("DELETE FROM messages WHERE id < ?", (max_id,))
    conn.commit()
    conn.close()
    
    print(f"Compacted messages up to ID {max_id} to {summary_file}")

def tokens():
    conn = get_conn()
    cur = conn.execute("SELECT GROUP_CONCAT(content, '') FROM messages")
    text = cur.fetchone()[0] or ''
    conn.close()
    return len(text) // 4

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else ''
    
    if cmd == 'init':
        init()
    elif cmd == 'store':
        store(sys.argv[2], sys.argv[3])
    elif cmd == 'recent':
        print(recent(int(sys.argv[2]) if len(sys.argv) > 2 else 10))
    elif cmd == 'count':
        print(count())
    elif cmd in ('clear', '--clear'):
        clear()
    elif cmd == 'get':
        print(get_memory(sys.argv[2]))
    elif cmd == 'set':
        set_memory(sys.argv[2], sys.argv[3])
    elif cmd == 'compact':
        compact(int(sys.argv[2]) if len(sys.argv) > 2 else 20)
    elif cmd == 'tokens':
        print(tokens())
    else:
        print(f"Usage: {sys.argv[0]} {{init|store <role> <content>|recent [limit]|count|clear|get <key>|set <key> <value>|compact|tokens}}")

if __name__ == '__main__':
    main()