#!/usr/bin/env bats

@test "manifest exists" {
  [ -f ".claude-plugin/plugin.json" ]
}

@test "manifest name is js-ralph" {
  run jq -r .name .claude-plugin/plugin.json
  [ "$status" -eq 0 ]
  [ "$output" = "js-ralph" ]
}

@test "manifest version is semver" {
  run jq -r .version .claude-plugin/plugin.json
  [ "$status" -eq 0 ]
  [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}
