#!/usr/bin/env bash
# hooks/subagent-track.sh start|stop — 실행 중인 서브에이전트 기록 (SubagentStart / SubagentStop hook).
#
# 오케스트레이터가 서브에이전트를 백그라운드로 띄우고 턴을 끝내면, Stop 가드는 그 사이를 "진척 없음" 으로 오판한다.
# 실행 중인 서브에이전트를 .harness/agents.active 에 적어 두고, Stop 가드는 목록이 비어 있지 않으면 정체로 세지 않는다.
# 한 줄 = "<id> <시작 epoch>". 오래된 줄(HARNESS_AGENT_STALE_MIN, 기본 90분)은 죽은 것으로 보고 무시한다.

set -uo pipefail

MODE="${1:-}"
INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null
[ -d .harness ] || exit 0

F=.harness/agents.active
ID=$(printf '%s' "$INPUT" | jq -r '.agent_id // .subagent_id // .task_id // .tool_use_id // empty')
TYPE=$(printf '%s' "$INPUT" | jq -r '.agent_type // .subagent_type // "agent"')
[ -n "$ID" ] || ID="type:$TYPE"

case "$MODE" in
  start)
    echo "$ID $(date +%s)" >> "$F" ;;
  stop)
    [ -f "$F" ] || exit 0
    # 같은 id 의 첫 줄 하나만 지운다 (id 가 없어 type 으로 기록된 경우 같은 type 하나)
    awk -v id="$ID" '!done && $1 == id { done = 1; next } { print }' "$F" > "$F.tmp" && mv "$F.tmp" "$F" ;;
esac
exit 0
