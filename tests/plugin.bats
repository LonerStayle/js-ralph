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

@test "vision-intake: 9 질문 · 마감 질문 없음 · 품질 기준 분류 · 동결 후 세 시야 제안" {
  f="$PLUGIN_ROOT/skills/vision-intake/SKILL.md"
  grep -q "동결은 항상 마지막 Edit" "$f"
  grep -q "next-proposals" "$f"
  grep -q "\[측정\]" "$f"
  grep -q "\[판단\]" "$f"
  grep -q "전문가" "$f"
  ! grep -qE "규모·일정·비용|핵심 산출물|goal|PROMPT\.md" "$f"
}

@test "next-proposals: 세 시야 병렬 · 결과 비공유 · synthesizer · 백그라운드 대기" {
  f="$PLUGIN_ROOT/skills/next-proposals/SKILL.md"
  for w in lens-user lens-expert lens-maker synthesizer "동시에" "전달하지 않는다" "proposal wait" run_in_background "proposal open"; do
    grep -q "$w" "$f" || { echo "missing: $w"; return 1; }
  done
}

@test "feature-orchestration: 마감 후 다음 제안으로 이어짐, 판단형 품질 위반은 high" {
  f="$PLUGIN_ROOT/skills/feature-orchestration/SKILL.md"
  grep -q "next-proposals" "$f"
  grep -q "high 로 취급" "$f"
}

@test "README / CLAUDE.md 가 v2 흐름을 안내한다" {
  grep -q "/js-ralph:setup-harness" "$PLUGIN_ROOT/README.md"
  grep -q "/js-ralph:feature" "$PLUGIN_ROOT/README.md"
  grep -q "v1.2.0" "$PLUGIN_ROOT/CLAUDE.md"
}

@test "비례 원칙: planner 크기 상한 · reviewer 과잉 설계 지적 · 계획 리뷰 1라운드" {
  grep -q "5개 이하" "$PLUGIN_ROOT/agents/planner.md"
  grep -q "과잉 설계" "$PLUGIN_ROOT/agents/reviewer.md"
  grep -q "1 라운드" "$PLUGIN_ROOT/skills/feature-orchestration/SKILL.md"
  grep -q "품질 기준 문장에 적힌 것만" "$PLUGIN_ROOT/agents/planner.md"
}

@test "orchestration: 서브에이전트 포그라운드 호출 · 가드 정지 후 자가 재개 금지" {
  f="$PLUGIN_ROOT/skills/feature-orchestration/SKILL.md"
  grep -q "run_in_background: false" "$f"
  grep -q "스스로 재개하지 않는다" "$f"
  grep -q "run_in_background: false" "$PLUGIN_ROOT/skills/next-proposals/SKILL.md"
}
