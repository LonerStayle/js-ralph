#!/usr/bin/env bats

@test "bats sanity" {
  run echo "ok"
  [ "$status" -eq 0 ]
  [ "$output" = "ok" ]
}
