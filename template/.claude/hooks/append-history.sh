#!/usr/bin/env bash
# 원칙 4: 매 도구 사용 후 ralph-history.md 에 append.
# Claude Code PostToolUse hook 으로 등록됨 (.claude/settings.json).

set -euo pipefail

HISTORY_FILE="memo/ralph-history.md"
mkdir -p "$(dirname "$HISTORY_FILE")"
[ -f "$HISTORY_FILE" ] || touch "$HISTORY_FILE"

# stdin 으로 hook payload (JSON) 가 들어옴.
PAYLOAD="$(cat || true)"

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
TOOL_NAME="$(echo "$PAYLOAD" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("tool_name",""))' 2>/dev/null || echo "")"

# 너무 verbose 해지지 않도록 tool_name 만 기록.
echo "- $TIMESTAMP [$TOOL_NAME]" >> "$HISTORY_FILE"
