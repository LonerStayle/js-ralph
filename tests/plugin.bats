#!/usr/bin/env bats

load helpers

@test "정적 검증 verify-plugin.sh PASS" {
  run bash "$PLUGIN_ROOT/scripts/verify-plugin.sh"
  [ "$status" -eq 0 ]
}

@test "hooks.json 의 모든 command 가 실제 파일을 가리킨다" {
  for p in $(jq -r '.. | .command? // empty' "$PLUGIN_ROOT/hooks/hooks.json" | grep -oE 'hooks/[a-z-]+\.sh'); do
    [ -x "$PLUGIN_ROOT/$p" ] || { echo "missing: $p"; return 1; }
  done
}

@test "feature-orchestration 은 네 에이전트와 harness.sh 를 모두 사용한다" {
  f="$PLUGIN_ROOT/skills/feature-orchestration/SKILL.md"
  for w in planner builder reviewer curator "harness.sh next" "harness.sh start" "harness.sh finish" "verify.sh" coverage; do
    grep -q "$w" "$f" || { echo "missing: $w"; return 1; }
  done
}

@test "vision-intake: 동결은 마지막 Edit, 첫 기획 게이트는 /js-ralph:feature" {
  f="$PLUGIN_ROOT/skills/vision-intake/SKILL.md"
  grep -q "동결은 항상 마지막 Edit" "$f"
  grep -q "/js-ralph:feature" "$f"
  ! grep -qE "goal|PROMPT\.md" "$f"
}

@test "README / CLAUDE.md 가 v2 흐름을 안내한다" {
  grep -q "/js-ralph:setup-harness" "$PLUGIN_ROOT/README.md"
  grep -q "/js-ralph:feature" "$PLUGIN_ROOT/README.md"
  grep -q "v1.2.0" "$PLUGIN_ROOT/CLAUDE.md"
}
