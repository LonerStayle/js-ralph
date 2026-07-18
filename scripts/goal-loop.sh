#!/usr/bin/env bash
# scripts/goal-loop.sh
#
# Claude Code 플러그인 js-ralph 의 /goal 슬래시 명령이 호출하는 본체.
# 현재 세션에 goal 루프(자기 재투입)용 상태 파일을 만든다.
# 외부 ralph-loop 플러그인 의존을 없애고, 동일 메커니즘을 js-ralph 안으로 내재화한 것.
#
# 사용:
#   bash scripts/goal-loop.sh "Read PROMPT.md and follow it." --completion-promise "PROJECT_DONE" --max-iterations 150
#
# 상태 파일: .claude/goal-loop.local.md  (hooks/goal-stop-hook.sh 가 읽음)

set -euo pipefail

# --- 인자 파싱 -----------------------------------------------------------
PROMPT_PARTS=()
MAX_ITERATIONS=0
COMPLETION_PROMISE="null"

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
/goal — 현재 세션 goal 루프 (자기 재투입 개발 루프)

사용:
  /goal [GOAL...] [옵션]

인자:
  GOAL...    루프를 시작할 프롬프트 (따옴표 없이 여러 단어 가능)

옵션:
  --max-iterations <n>           자동 정지 전 최대 iteration (기본: 무제한)
  --completion-promise '<text>'  완료 신호 문구 (여러 단어면 따옴표 필수)
  -h, --help                     이 도움말

설명:
  현재 세션에 goal 루프를 켠다. Stop hook 이 종료를 가로채 SAME PROMPT 를
  다음 iteration 으로 재투입한다. 완료를 알리려면 다음을 정확히 출력:
    <promise>YOUR_PHRASE</promise>

예:
  /goal Build a todo API --completion-promise 'DONE' --max-iterations 20
  /goal "Read PROMPT.md and follow it." --completion-promise 'PROJECT_DONE' --max-iterations 150

정지:
  --max-iterations 도달 또는 --completion-promise 감지. 수동 중단은 /cancel-goal.

모니터링:
  grep '^iteration:' .claude/goal-loop.local.md
HELP_EOF
      exit 0
      ;;
    --max-iterations)
      if [[ -z "${2:-}" ]]; then
        echo "❌ 오류: --max-iterations 는 숫자 인자가 필요합니다 (예: --max-iterations 150, 0 은 무제한)" >&2
        exit 1
      fi
      if ! [[ "$2" =~ ^[0-9]+$ ]]; then
        echo "❌ 오류: --max-iterations 는 0 이상의 정수여야 합니다 (받은 값: $2)" >&2
        exit 1
      fi
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      if [[ -z "${2:-}" ]]; then
        echo "❌ 오류: --completion-promise 는 텍스트 인자가 필요합니다 (여러 단어면 따옴표로 감싸십시오)" >&2
        exit 1
      fi
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    *)
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

# 프롬프트 부분들을 공백으로 join
PROMPT="${PROMPT_PARTS[*]:-}"

if [[ -z "$PROMPT" ]]; then
  echo "❌ 오류: goal 프롬프트가 없습니다." >&2
  echo "   예) /goal \"Read PROMPT.md and follow it.\" --completion-promise \"PROJECT_DONE\" --max-iterations 150" >&2
  echo "   전체 옵션: /goal --help" >&2
  exit 1
fi

# --- 상태 파일 생성 (markdown + YAML frontmatter) ------------------------
mkdir -p .claude

if [[ -n "$COMPLETION_PROMISE" ]] && [[ "$COMPLETION_PROMISE" != "null" ]]; then
  COMPLETION_PROMISE_YAML="\"$COMPLETION_PROMISE\""
else
  COMPLETION_PROMISE_YAML="null"
fi

cat > .claude/goal-loop.local.md <<EOF
---
active: true
iteration: 1
session_id: ${CLAUDE_CODE_SESSION_ID:-}
max_iterations: $MAX_ITERATIONS
completion_promise: $COMPLETION_PROMISE_YAML
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
---

$PROMPT
EOF

# --- 활성화 안내 ---------------------------------------------------------
cat <<EOF
🎯 Goal set: $PROMPT

  iteration          : 1
  max-iterations     : $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "무제한"; fi)
  completion-promise : $(if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "${COMPLETION_PROMISE//\"/} (참일 때만 출력 — 탈출용 거짓 출력 금지)"; else echo "없음 (무한 반복)"; fi)

Stop hook 이 활성화되었습니다. 종료를 시도하면 동일 프롬프트가 fresh context 로
재투입됩니다. 이전 작업은 파일과 git 히스토리에 남아 있어 반복적으로 개선됩니다.

  모니터링: head -10 .claude/goal-loop.local.md
  수동 중단: /cancel-goal
EOF

if [[ "$MAX_ITERATIONS" -eq 0 ]] && [[ "$COMPLETION_PROMISE" == "null" ]]; then
  echo
  echo "⚠️  주의: --max-iterations / --completion-promise 없이 시작해 무한 반복합니다. /cancel-goal 로만 멈출 수 있습니다."
fi

# 초기 프롬프트 재출력
echo
echo "$PROMPT"

# completion promise 요구사항 안내
if [[ "$COMPLETION_PROMISE" != "null" ]]; then
  echo
  echo "═══════════════════════════════════════════════════════════"
  echo "완료 신호 (Goal Completion Promise)"
  echo "═══════════════════════════════════════════════════════════"
  echo
  echo "이 루프를 끝내려면 다음을 정확히 출력하십시오:"
  echo "  <promise>$COMPLETION_PROMISE</promise>"
  echo
  echo "엄격 규칙:"
  echo "  ✓ <promise> 태그를 위와 정확히 동일하게 사용"
  echo "  ✓ 진술이 완전하고 명백하게 참일 때만 출력"
  echo "  ✓ 루프를 탈출하려고 거짓 진술을 출력하지 마십시오"
  echo "  ✓ 막혔다고 느껴도 거짓 promise 로 루프를 우회하지 마십시오"
  echo "═══════════════════════════════════════════════════════════"
fi
