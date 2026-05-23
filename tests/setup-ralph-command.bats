#!/usr/bin/env bats

@test "command file exists" {
  [ -f "commands/setup-ralph.md" ]
}

@test "frontmatter description" {
  run grep '^description:' commands/setup-ralph.md
  [ "$status" -eq 0 ]
}

@test "frontmatter argument-hint" {
  run grep '^argument-hint:' commands/setup-ralph.md
  [ "$status" -eq 0 ]
}

@test "allowed-tools includes setup-ralph.sh" {
  run grep 'CLAUDE_PLUGIN_ROOT.*scripts/setup-ralph.sh' commands/setup-ralph.md
  [ "$status" -eq 0 ]
}

@test "body invokes vision-intake (D-2)" {
  run grep 'vision-intake' commands/setup-ralph.md
  [ "$status" -eq 0 ]
}

@test "bash exec block present" {
  run grep -c '^```!' commands/setup-ralph.md
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}
