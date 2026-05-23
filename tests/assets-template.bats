#!/usr/bin/env bats

@test "5 files in assets/template" {
  for f in CLAUDE.md PROMPT.md AGENTS.md IMPLEMENTATION_PLAN.md README.md; do
    [ -f "assets/template/$f" ] || { echo "missing: assets/template/$f"; return 1; }
  done
}

@test "satellite files exist" {
  [ -f "assets/template/.claude/settings.json" ]
  [ -f "assets/template/.gitignore" ]
  [ -f "assets/template/VERSION" ]
  [ -f "assets/template/specs/.gitkeep" ]
}

@test "VERSION is 3" {
  run cat assets/template/VERSION
  [ "$(echo "$output" | tr -d '[:space:]')" = "3" ]
}

@test "vision-intake skill at plugin root" {
  [ -f "skills/vision-intake/SKILL.md" ]
  [ ! -d "assets/template/.claude/skills" ]
}

@test "CLAUDE.md keeps PROJECT_NAME placeholder" {
  run grep '{{PROJECT_NAME}}' assets/template/CLAUDE.md
  [ "$status" -eq 0 ]
}
