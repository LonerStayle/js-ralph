#!/usr/bin/env bash
# hooks/stop-guard.sh — 롱러닝 실행 가드 (Stop hook).
#
# .harness/run.json 이 running 이고 트리에 남은 노드가 있으면 세션 종료를 막고
# "다음 노드" 를 알려 작업을 이어가게 한다. 같은 프롬프트를 재투입하지 않는다 —
# 트리 상태에서 계산한 다음 할 일을 넘긴다.
#
# 종료를 허용하는 경우:
#   - 하네스 없음 / run 없음 / status != running
#   - 다른 세션이 소유한 run
#   - 트리 완료 (DONE)             → status=done
#   - 남은 노드가 전부 blocked      → status=blocked (사람 판단 필요)
#   - 의존 순환 (STUCK)             → status=blocked
#   - max_continuations 도달        → status=paused
#   - 연속 STALL_LIMIT 회 진척 없음  → status=blocked (헛돌기 방지)
#   - 서브에이전트 실행 중           → 정체로 세지 않고 그냥 허용 (완료 알림이 세션을 깨움)

set -uo pipefail

STALL_LIMIT="${HARNESS_STALL_LIMIT:-3}"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HARNESS="$PLUGIN_ROOT/assets/template/.harness/bin/harness.sh"

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null
[ -f .harness/run.json ] || exit 0

RUN=.harness/run.json
STATUS=$(jq -r '.status // empty' "$RUN" 2>/dev/null || true)
[ "$STATUS" = "running" ] || exit 0

h() { HARNESS_ROOT="$PWD" bash "$HARNESS" "$@"; }
upd() { local tmp; tmp=$(mktemp .harness/.run.XXXXXX); jq "$@" "$RUN" > "$tmp" && mv "$tmp" "$RUN"; }
allow() { echo "$1" >&2; exit 0; }

# 세션 소유권: 비어 있으면 이 세션이 가져간다. 다른 세션 소유면 간섭하지 않는다.
SID=$(printf '%s' "$INPUT" | jq -r '.session_id // empty')
OWNER=$(jq -r '.session_id // empty' "$RUN")
if [ -z "$OWNER" ] && [ -n "$SID" ]; then
  upd --arg s "$SID" '.session_id = $s'
elif [ -n "$OWNER" ] && [ -n "$SID" ] && [ "$OWNER" != "$SID" ]; then
  exit 0
fi

# 서브에이전트가 돌고 있으면 기다리는 중이다 — 정체로 세지 않고 종료를 허용한다 (완료 알림이 세션을 다시 깨운다)
STALE_MIN="${HARNESS_AGENT_STALE_MIN:-90}"
if [ -f .harness/agents.active ]; then
  ACTIVE=$(awk -v now="$(date +%s)" -v lim="$((STALE_MIN * 60))" 'NF >= 2 && now - $2 < lim' .harness/agents.active | wc -l | tr -d ' ')
  [ "$ACTIVE" -gt 0 ] && exit 0
fi

NEXT=$(h next 2>/dev/null) || allow "[harness] 트리를 읽지 못해 가드를 해제합니다 (run.json / TREE.md 확인 필요)."
FEATURE=$(jq -r '.feature' "$RUN")

case "$NEXT" in
  DONE)
    h finish done >/dev/null
    allow "[harness] $FEATURE: 트리 전체 완료. Phase C(마감) 보고가 끝났는지 확인하십시오." ;;
  BLOCKED)
    h finish blocked >/dev/null
    allow "[harness] $FEATURE: 남은 노드가 모두 blocked 입니다. 사람 판단이 필요합니다 (TREE.md 의 [!] 사유 참고)." ;;
  STUCK|NONE)
    h finish blocked >/dev/null
    allow "[harness] $FEATURE: 착수 가능한 노드가 없습니다 (의존 순환 또는 빈 트리: $NEXT). TREE.md 를 점검하십시오." ;;
esac

CONT=$(jq -r '.continuations // 0' "$RUN")
MAX=$(jq -r '.max_continuations // 300' "$RUN")
if [ "$MAX" -gt 0 ] && [ "$CONT" -ge "$MAX" ]; then
  h pause >/dev/null
  allow "[harness] $FEATURE: max_continuations($MAX) 도달로 일시정지합니다. /resume 으로 재개할 수 있습니다."
fi

# 정체 감지: 트리도 git HEAD 도 안 바뀐 채 연속으로 멈추려 하면 blocked 처리.
FP=$(h fingerprint 2>/dev/null || echo "")
LAST=$(jq -r '.last_fingerprint // empty' "$RUN")
STALL=$(jq -r '.stall_count // 0' "$RUN")
if [ -n "$FP" ] && [ "$FP" = "$LAST" ]; then STALL=$((STALL+1)); else STALL=0; fi
if [ "$STALL" -ge "$STALL_LIMIT" ]; then
  upd --arg f "$FP" --argjson n "$STALL" '.last_fingerprint = $f | .stall_count = $n'
  h finish blocked >/dev/null
  allow "[harness] $FEATURE: ${STALL}회 연속 진척이 없어 정지했습니다. 현재 노드: ${NEXT#READY }"
fi

upd --arg f "$FP" --argjson n "$STALL" --argjson c "$((CONT+1))" \
  '.last_fingerprint = $f | .stall_count = $n | .continuations = $c'

read -r TOTAL DONE_N _ _ BLOCKED_N <<<"$(h counts)"
REASON="[harness] $FEATURE 진행 중 — 완료 $DONE_N/$TOTAL, blocked $BLOCKED_N. 다음 노드: ${NEXT#READY }.
feature-orchestration 스킬의 Phase B 절차대로 이 노드를 이어서 진행하십시오. 멈추려면 사용자가 /pause 를 실행해야 합니다."
[ "$STALL" -gt 0 ] && REASON="$REASON
(주의: 직전 턴에 트리/커밋 변화가 없었습니다 — ${STALL}/${STALL_LIMIT}. 같은 방법을 반복하지 말고 노드를 쪼개거나 blocked 처리하십시오.)"

jq -n --arg r "$REASON" '{decision: "block", reason: $r}'
exit 0
