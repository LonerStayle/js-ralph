#!/usr/bin/env bats

@test "FR-7 gate phrase exists" {
  run grep 'goal 루프를 지금 자동 시작할까요' skills/vision-intake/SKILL.md
  [ "$status" -eq 0 ]
}

@test "R-4 fixed prompt arg" {
  run grep 'Read PROMPT.md and follow it.' skills/vision-intake/SKILL.md
  [ "$status" -eq 0 ]
}

@test "completion-promise PROJECT_DONE" {
  run grep 'completion-promise.*PROJECT_DONE' skills/vision-intake/SKILL.md
  [ "$status" -eq 0 ]
}

@test "internal goal-loop.sh precheck path" {
  run grep 'js-ralph/\*/scripts/goal-loop.sh' skills/vision-intake/SKILL.md
  [ "$status" -eq 0 ]
}

@test "no external ralph-loop invocation" {
  run grep -E 'setup-ralph-loop|/ralph-loop:' skills/vision-intake/SKILL.md
  [ "$status" -ne 0 ]
}

@test "D-5 max-iterations extract logic" {
  run grep -E 'max-iterations.*(150|cap|추출)|MAX_ITER' skills/vision-intake/SKILL.md
  [ "$status" -eq 0 ]
}
