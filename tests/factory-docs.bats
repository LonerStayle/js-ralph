#!/usr/bin/env bats

@test "CLAUDE.md mentions plugin dev/release repo" {
  run grep "개발/배포 저장소" CLAUDE.md
  [ "$status" -eq 0 ]
}

@test "CLAUDE.md mentions pre-plugin branch" {
  run grep "pre-plugin" CLAUDE.md
  [ "$status" -eq 0 ]
}

@test "CLAUDE.md no longer claims harness factory" {
  run grep "ralph 하네스 공장" CLAUDE.md
  [ "$status" -ne 0 ]
}

@test "README.md has /plugin install + /setup-ralph quickstart" {
  run grep "/plugin install js-ralph" README.md
  [ "$status" -eq 0 ]
  run grep "/setup-ralph" README.md
  [ "$status" -eq 0 ]
}

@test "README.md does not reference old new-harness.sh except in pre-plugin context" {
  if grep -q "new-harness.sh" README.md; then
    grep -B2 -A2 "new-harness.sh" README.md | grep -q "pre-plugin"
  fi
}
