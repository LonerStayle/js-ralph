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

@test "AC-1 clean empty dir scaffolds 5 files + satellites + git" {
  bash "$PLUGIN_ROOT/scripts/setup-ralph.sh"
  for f in CLAUDE.md PROMPT.md AGENTS.md IMPLEMENTATION_PLAN.md README.md \
           .claude/settings.json .gitignore VERSION specs/.gitkeep; do
    [ -e "$f" ] || { echo "missing: $f"; return 1; }
  done
  [ -d ".git" ]
  run git -C . log --oneline
  [ -n "$output" ]
  ! grep -q '{{PROJECT_NAME}}' CLAUDE.md
}

@test "AC-3 clean conflict aborts" {
  echo "x" > PROMPT.md
  run bash "$PLUGIN_ROOT/scripts/setup-ralph.sh"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "--overlay" ]]
  [ ! -f "CLAUDE.md" ]
}

@test "AC-4 overlay backs up to .v2.bak and applies v3" {
  for f in CLAUDE.md PROMPT.md; do echo "old-$f" > "$f"; done
  mkdir -p .claude && echo "{}" > .claude/settings.json
  bash "$PLUGIN_ROOT/scripts/setup-ralph.sh" --overlay
  [ -f "CLAUDE.md.v2.bak" ]
  [ -f "PROMPT.md.v2.bak" ]
  [ -d ".claude.v2.bak" ]
  ! grep -q '{{PROJECT_NAME}}' CLAUDE.md
}

@test "AC-5 onboarded true overlay aborts without --force" {
  echo "onboarded: true" > CLAUDE.md
  run bash "$PLUGIN_ROOT/scripts/setup-ralph.sh" --overlay
  [ "$status" -ne 0 ]
  [[ "$output" =~ "--force" ]]
  [ ! -f "CLAUDE.md.v2.bak" ]
  [ ! -f "PROMPT.md" ]
}

@test "AC-6 factory single source — old vestiges absent + pre-plugin branch preserves them" {
  cd "$PLUGIN_ROOT"
  [ ! -d "template" ]
  [ ! -f "scripts/new-harness.sh" ]
  [ ! -f "scripts/verify-v3-template.sh" ]
  run git show pre-plugin:template/CLAUDE.md
  [ "$status" -eq 0 ]
  [[ "$output" =~ "{{PROJECT_NAME}}" ]]
}
