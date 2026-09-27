#!/usr/bin/env bash
# hooks/session-context.sh — 세션 시작 / 재개 / 컨텍스트 압축 직후 방향 복원 (SessionStart hook).
#
# 롱러닝 세션은 컨텍스트 압축(compaction)을 여러 번 겪는다. 압축 직후에 "지금 무슨 feature 의
# 어느 노드를 하고 있었는지" 를 파일 상태에서 다시 계산해 주입한다.

set -uo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
HARNESS="$PLUGIN_ROOT/assets/template/.harness/bin/harness.sh"

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null
[ -d .harness ] || exit 0

SOURCE=$(printf '%s' "$INPUT" | jq -r '.source // "startup"')
CTX=""

if ! grep -qE '^onboarded:[[:space:]]*true' CLAUDE.md 2>/dev/null; then
  CTX="[harness] 비전 인터뷰가 아직 끝나지 않았습니다 (CLAUDE.md onboarded: false). 첫 응답은 vision-intake 스킬로 시작하십시오."
elif [ -f .harness/run.json ]; then
  STATUS=$(jq -r '.status // empty' .harness/run.json)
  SUMMARY=$(HARNESS_ROOT="$PWD" bash "$HARNESS" status 2>/dev/null || true)
  case "$STATUS" in
    running)
      CTX="[harness] 진행 중인 feature 가 있습니다 (source: $SOURCE).
$SUMMARY
feature-orchestration 스킬을 불러 Phase B 를 이어서 진행하십시오. SPEC.md / TREE.md 는 \$(bash .harness/bin/harness.sh feature-dir) 에 있습니다." ;;
    paused|blocked)
      CTX="[harness] 일시정지/차단된 feature 가 있습니다.
$SUMMARY
사용자가 /resume 을 실행하기 전에는 자동으로 재개하지 마십시오." ;;
  esac
fi

# 다음 기능 제안 대기 상태 — 세션이 끊긴 사이 기한이 지났을 수 있다
if [ -z "$CTX" ] && [ -f .harness/proposal.json ] && [ "$(jq -r '.status // empty' .harness/proposal.json)" = "pending" ]; then
  DEADLINE=$(jq -r '.deadline // 0' .harness/proposal.json)
  if [ "$(date +%s)" -ge "$DEADLINE" ]; then
    CTX="[harness] 다음 기능 제안의 선택 기한이 지났습니다. next-proposals 스킬 3번 표대로 \`bash .harness/bin/harness.sh proposal timeout\` 을 실행해 처리하십시오."
  else
    CTX="[harness] 다음 기능 제안 카드가 선택을 기다리고 있습니다 ($(jq -r '.dir' .harness/proposal.json)/CARDS.md, 남은 $(( (DEADLINE - $(date +%s)) / 60 ))분).
카드를 다시 보여드리고 next-proposals 스킬 3번대로 \`bash .harness/bin/harness.sh proposal wait\` 를 백그라운드로 다시 실행하십시오."
  fi
fi

[ -n "$CTX" ] || exit 0
jq -n --arg c "$CTX" '{hookSpecificOutput: {hookEventName: "SessionStart", additionalContext: $c}}'
exit 0
