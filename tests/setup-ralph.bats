#!/usr/bin/env bats

setup() {
  TMPDIR=$(mktemp -d)
  cd "$TMPDIR"
  export PLUGIN_ROOT="${BATS_TEST_DIRNAME}/.."
}

teardown() {
  cd /
  rm -rf "$TMPDIR"
}

@test "clean mode empty dir scaffolds 5 files (AC-1)" {
  run bash "$PLUGIN_ROOT/scripts/setup-ralph.sh"
  [ "$status" -eq 0 ]
  for f in CLAUDE.md PROMPT.md AGENTS.md IMPLEMENTATION_PLAN.md README.md; do
    [ -f "$f" ] || { echo "missing: $f"; return 1; }
  done
  [ -f ".claude/settings.json" ]
  [ -f ".gitignore" ]
  [ "$(cat VERSION | tr -d '[:space:]')" = "3" ]
  [ -d ".git" ]
}

@test "PROJECT_NAME substitution safe escape (R-2)" {
  bash "$PLUGIN_ROOT/scripts/setup-ralph.sh"
  ! grep -q '{{PROJECT_NAME}}' CLAUDE.md
  ! grep -q '{{PROJECT_NAME}}' README.md
}

@test "clean mode conflict aborts (AC-3)" {
  echo "existing" > PROMPT.md
  run bash "$PLUGIN_ROOT/scripts/setup-ralph.sh"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "--overlay" ]]
  [ "$(cat PROMPT.md)" = "existing" ]
  [ ! -f "CLAUDE.md" ]
}

@test "overlay mode backs up conflicts to .v2.bak (AC-4)" {
  echo "old-claude" > CLAUDE.md
  echo "old-prompt" > PROMPT.md
  run bash "$PLUGIN_ROOT/scripts/setup-ralph.sh" --overlay
  [ "$status" -eq 0 ]
  [ -f "CLAUDE.md.v2.bak" ]
  [ "$(cat CLAUDE.md.v2.bak)" = "old-claude" ]
  [ -f "PROMPT.md.v2.bak" ]
  ! grep -q '{{PROJECT_NAME}}' CLAUDE.md
}

@test "overlay vision protection — onboarded true aborts without --force (AC-5)" {
  echo "onboarded: true" > CLAUDE.md
  run bash "$PLUGIN_ROOT/scripts/setup-ralph.sh" --overlay
  [ "$status" -ne 0 ]
  [[ "$output" =~ "--force" ]]
  [ ! -f "CLAUDE.md.v2.bak" ]
  [ ! -f "PROMPT.md" ]
}

@test "overlay --force bypasses onboarded guard (D-3)" {
  echo "onboarded: true" > CLAUDE.md
  run bash "$PLUGIN_ROOT/scripts/setup-ralph.sh" --overlay --force
  [ "$status" -eq 0 ]
  [ -f "CLAUDE.md.v2.bak" ]
}

@test "second backup uses timestamp when .v2.bak exists (D-4)" {
  echo "v1" > CLAUDE.md
  echo "v2-old" > CLAUDE.md.v2.bak
  echo "p1" > PROMPT.md
  bash "$PLUGIN_ROOT/scripts/setup-ralph.sh" --overlay
  [ "$(cat CLAUDE.md.v2.bak)" = "v2-old" ]
  ls CLAUDE.md.bak.* 2>/dev/null | grep -E '\.bak\.[0-9]{8}T[0-9]{6}' || return 1
}

@test "git init skipped when .git exists (R-5)" {
  git init -b main -q
  bash "$PLUGIN_ROOT/scripts/setup-ralph.sh"
  [ -d ".git" ]
  # no commits — setup-ralph.sh did not create one
  ! git log --oneline 2>/dev/null | grep -q .
}

@test "HOME guard (R-9)" {
  cd "$HOME"
  run bash "$PLUGIN_ROOT/scripts/setup-ralph.sh"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "전용 디렉토리" ]]
}

@test "unknown arg aborts" {
  run bash "$PLUGIN_ROOT/scripts/setup-ralph.sh" --unknown
  [ "$status" -ne 0 ]
}
