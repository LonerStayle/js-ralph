#!/usr/bin/env bash
# hooks/protect-files.sh — 합격 기준 보호 (PreToolUse hook).
#
# 비전이 동결(onboarded: true)된 뒤에는 에이전트가 스스로 합격 기준을 약하게 만들 수 없도록
# 아래 경로의 수정/삭제를 막는다. 사람이 에디터로 직접 고치는 것은 막지 않는다.
#
#   CLAUDE.md                 비전 / 사양 (사람 영역)
#   .harness/verify.sh        결정적 검증 게이트
#   .harness/bin/*            상태 CLI
#   .harness/verify.d/<기존>   추가 검증 — 새 파일 추가는 허용, 기존 파일 수정/삭제는 차단
#   .harness/run.json         실행 상태 — 항상 harness.sh 로만 변경 (동결 여부 무관)

set -uo pipefail

INPUT=$(cat)
command -v jq >/dev/null 2>&1 || exit 0

CWD=$(printf '%s' "$INPUT" | jq -r '.cwd // empty')
[ -n "$CWD" ] && cd "$CWD" 2>/dev/null
[ -d .harness ] || exit 0

TOOL=$(printf '%s' "$INPUT" | jq -r '.tool_name // empty')
LOCKED=0
grep -qE '^onboarded:[[:space:]]*true' CLAUDE.md 2>/dev/null && LOCKED=1

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse",
    permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 0
}

# 경로가 보호 대상인지 판정. $2=1 이면 "새 파일 생성" 시도.
check_path() {
  local p="$1" creating="$2"
  p="${p#"$PWD"/}"; p="${p#./}"
  case "$p" in
    .harness/run.json)
      deny "run.json 은 직접 수정하지 않습니다. bash .harness/bin/harness.sh (start/pause/resume/finish) 를 사용하십시오." ;;
  esac
  [ "$LOCKED" -eq 1 ] || return 0
  case "$p" in
    CLAUDE.md)
      deny "CLAUDE.md 는 비전 동결 이후 보호됩니다. 배운 점은 .harness/memory/ 에 기록하고, 비전 변경이 필요하면 사용자에게 요청하십시오." ;;
    .harness/verify.sh|.harness/bin/*)
      deny "$p 는 합격 기준이라 에이전트가 수정할 수 없습니다. 검증을 늘리려면 .harness/verify.d/ 에 새 .sh 파일을 추가하십시오." ;;
    .harness/verify.d/*)
      if [ "$creating" -eq 0 ] || [ -e "$p" ]; then
        deny "기존 추가 검증($p)은 수정/삭제할 수 없습니다 (검증 약화 방지). 새 파일로 추가하십시오."
      fi ;;
  esac
}

case "$TOOL" in
  Edit|MultiEdit|NotebookEdit)
    FP=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // .tool_input.notebook_path // empty')
    [ -n "$FP" ] && check_path "$FP" 0 ;;
  Write)
    FP=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
    [ -n "$FP" ] && check_path "$FP" 1 ;;
  Bash)
    CMD=$(printf '%s' "$INPUT" | jq -r '.tool_input.command // empty')
    # 셸 검사는 최선 노력(best-effort)이다: 쓰기 연산자 뒤 같은 명령 조각에 보호 경로가 나오면 차단.
    OPS='(>|(^|[[:space:];&|(])(tee|rm|mv|cp|truncate|chmod|sed[[:space:]]+-i[^[:space:]]*)[[:space:]])'
    # run.json 은 동결 여부와 무관하게 쓰기 차단
    if printf '%s' "$CMD" | grep -qE "${OPS}[^|;&]*\.harness/run\.json"; then
      deny "run.json 은 직접 수정하지 않습니다. bash .harness/bin/harness.sh 를 사용하십시오."
    fi
    if [ "$LOCKED" -eq 1 ]; then
      if printf '%s' "$CMD" | grep -qE "${OPS}[^|;&]*(\.harness/(verify\.sh|bin/|verify\.d/)|(^|[[:space:]]|\./)CLAUDE\.md)"; then
        deny "보호된 합격 기준 파일(CLAUDE.md / .harness/verify.sh / bin / verify.d)을 셸로 변경할 수 없습니다."
      fi
      if printf '%s' "$CMD" | grep -qE 'git[[:space:]]+(checkout|restore|rm|mv)[^|;&]*(\.harness/(verify\.sh|bin/|verify\.d/)|CLAUDE\.md)'; then
        deny "보호된 합격 기준 파일을 git 으로 되돌리거나 삭제할 수 없습니다."
      fi
    fi ;;
esac
exit 0
