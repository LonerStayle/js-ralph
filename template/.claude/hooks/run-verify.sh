#!/usr/bin/env bash
# 원칙 1: Stop hook. 루프 종료 시 verify-loop-output 스킬을 호출하라는 신호를 남긴다.
# 실제 채점은 다음 turn 에 메인 에이전트가 수행 (Skill: verify-loop-output).

set -euo pipefail

STATE_DIR=".claude/state"
HISTORY="$STATE_DIR/ralph-history.md"
PENDING="$STATE_DIR/verify-pending.flag"

mkdir -p "$STATE_DIR"
touch "$HISTORY" "$PENDING"

TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "- $TIMESTAMP [stop] verify-pending" >> "$HISTORY"

# Claude Code 에 추가 instruction 을 주입 (Stop hook 의 stdout 은 다음 사용자 메시지처럼 취급되지 않음 →
#  대신 플래그 파일을 두고, 메인 에이전트가 시작 시 이 플래그를 보면 verify-loop-output 스킬을 invoke 하도록
#  CLAUDE.md / 슬래시 커맨드에 규약화).
echo "verify-pending=$TIMESTAMP" > "$PENDING"
