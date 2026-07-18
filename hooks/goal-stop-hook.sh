#!/bin/bash

# js-ralph Goal Loop — Stop Hook
# .claude/goal-loop.local.md 가 있으면 세션 종료를 가로채 동일 프롬프트를 재투입.
# 외부 ralph-loop 플러그인의 stop-hook 을 js-ralph 안으로 내재화 + 리브랜딩한 것.

set -euo pipefail

# advanced stop hook API — stdin 으로 hook 입력 수신
HOOK_INPUT=$(cat)

# goal 루프 활성 여부
GOAL_STATE_FILE=".claude/goal-loop.local.md"

if [[ ! -f "$GOAL_STATE_FILE" ]]; then
  # 활성 루프 없음 — 정상 종료 허용
  exit 0
fi

# frontmatter(--- 사이 YAML) 파싱
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$GOAL_STATE_FILE")
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')

# 세션 격리: 상태 파일은 프로젝트 범위지만 Stop hook 은 그 프로젝트의 모든 세션에서
# 발화한다. 다른 세션이 루프를 시작했다면 이 세션은 블록하지 않는다(파일도 안 건드림).
# session_id 없는 레거시 파일은 통과 (기존 동작 보존).
STATE_SESSION=$(echo "$FRONTMATTER" | grep '^session_id:' | sed 's/session_id: *//' || true)
HOOK_SESSION=$(echo "$HOOK_INPUT" | jq -r '.session_id // ""')
if [[ -n "$STATE_SESSION" ]] && [[ "$STATE_SESSION" != "$HOOK_SESSION" ]]; then
  exit 0
fi

# 숫자 필드 검증
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Goal 루프: 상태 파일 손상 ('iteration' 이 숫자 아님: '$ITERATION'). 루프를 정지합니다. 다시 /goal 로 시작하십시오." >&2
  rm "$GOAL_STATE_FILE"
  exit 0
fi

if [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "⚠️  Goal 루프: 상태 파일 손상 ('max_iterations' 이 숫자 아님: '$MAX_ITERATIONS'). 루프를 정지합니다." >&2
  rm "$GOAL_STATE_FILE"
  exit 0
fi

# 최대 iteration 도달 검사
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "🛑 Goal 루프: 최대 iteration ($MAX_ITERATIONS) 도달. 루프를 종료합니다."
  rm "$GOAL_STATE_FILE"
  exit 0
fi

# transcript 경로
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  echo "⚠️  Goal 루프: transcript 파일을 찾지 못했습니다 ($TRANSCRIPT_PATH). 루프를 정지합니다." >&2
  rm "$GOAL_STATE_FILE"
  exit 0
fi

# transcript 에서 마지막 assistant 텍스트 블록 추출 (JSONL)
if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
  echo "⚠️  Goal 루프: transcript 에 assistant 메시지가 없습니다. 루프를 정지합니다." >&2
  rm "$GOAL_STATE_FILE"
  exit 0
fi

LAST_LINES=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -n 100)
if [[ -z "$LAST_LINES" ]]; then
  echo "⚠️  Goal 루프: assistant 메시지 추출 실패. 루프를 정지합니다." >&2
  rm "$GOAL_STATE_FILE"
  exit 0
fi

# 최근 라인들을 slurp 해 마지막 text 블록만 추출.
# `last // ""` — text 블록이 없으면 빈 문자열 (전부 tool 호출인 턴). 그러면 promise 없음 → 루프 계속.
set +e
LAST_OUTPUT=$(echo "$LAST_LINES" | jq -rs '
  map(.message.content[]? | select(.type == "text") | .text) | last // ""
' 2>&1)
JQ_EXIT=$?
set -e

if [[ $JQ_EXIT -ne 0 ]]; then
  echo "⚠️  Goal 루프: assistant 메시지 JSON 파싱 실패 ($LAST_OUTPUT). 루프를 정지합니다." >&2
  rm "$GOAL_STATE_FILE"
  exit 0
fi

# 완료 promise 검사 (설정된 경우만)
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")

  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    echo "✅ Goal 루프: <promise>$COMPLETION_PROMISE</promise> 감지. 루프를 종료합니다."
    rm "$GOAL_STATE_FILE"
    exit 0
  fi
fi

# 미완료 — SAME PROMPT 로 루프 계속
NEXT_ITERATION=$((ITERATION + 1))

# 프롬프트 추출 (닫는 --- 이후 전부)
PROMPT_TEXT=$(awk '/^---$/{i++; next} i>=2' "$GOAL_STATE_FILE")

if [[ -z "$PROMPT_TEXT" ]]; then
  echo "⚠️  Goal 루프: 상태 파일 손상 (프롬프트 텍스트 없음). 루프를 정지합니다. 다시 /goal 로 시작하십시오." >&2
  rm "$GOAL_STATE_FILE"
  exit 0
fi

# frontmatter 의 iteration 갱신 (macOS/Linux 호환, atomic replace)
TEMP_FILE="${GOAL_STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$GOAL_STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$GOAL_STATE_FILE"

# 시스템 메시지
if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
  SYSTEM_MSG="🎯 Goal iteration $NEXT_ITERATION | 종료하려면: <promise>$COMPLETION_PROMISE</promise> 출력 (진술이 참일 때만 — 탈출용 거짓 출력 금지!)"
else
  SYSTEM_MSG="🎯 Goal iteration $NEXT_ITERATION | completion promise 없음 — 무한 반복"
fi

# stop 을 블록하고 프롬프트를 재투입하는 JSON 출력
jq -n \
  --arg prompt "$PROMPT_TEXT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
