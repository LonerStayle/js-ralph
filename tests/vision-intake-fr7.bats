#!/usr/bin/env bats

@test "FR-7 gate phrase exists" {
  run grep 'ralph-loop 를 지금 자동 시작할까요' skills/vision-intake/SKILL.md
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

@test "D-6 ralph-loop path precheck guide" {
  run grep '플러그인 미설치' skills/vision-intake/SKILL.md
  [ "$status" -eq 0 ]
}

@test "D-5 max-iterations extract logic" {
  run grep -E 'max-iterations.*(150|cap|추출)' skills/vision-intake/SKILL.md
  [ "$status" -eq 0 ]
}
