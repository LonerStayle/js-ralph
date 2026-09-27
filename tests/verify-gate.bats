#!/usr/bin/env bats

load helpers

setup() { make_tmp; install_harness; }
teardown() { cleanup_tmp; }

@test "verify: 스택 미탐지 + verify.d 비어 있음 → 실패 (검증 없는 통과 금지)" {
  run bash .harness/verify.sh
  [ "$status" -ne 0 ]
  [[ "$output" =~ "스택을 찾지 못했습니다" ]]
}

@test "verify: verify.d 추가 검증만 있어도 실행, 하나라도 실패하면 실패" {
  echo 'exit 0' > .harness/verify.d/a.sh
  run bash .harness/verify.sh
  [ "$status" -eq 0 ]
  echo 'exit 1' > .harness/verify.d/b.sh
  run bash .harness/verify.sh
  [ "$status" -ne 0 ]
}

@test "verify: node — 하위 디렉토리 package.json 의 lint/test 자동 탐지" {
  mkdir web
  echo '{"scripts":{"lint":"node -e \"process.exit(0)\"","test":"node -e \"process.exit(0)\""}}' > web/package.json
  run bash .harness/verify.sh
  [ "$status" -eq 0 ]
  [[ "$output" =~ "node lint" ]]
  [[ "$output" =~ "node tests" ]]
}

@test "verify: node — 테스트 실패 전파" {
  echo '{"scripts":{"test":"node -e \"process.exit(3)\""}}' > package.json
  run bash .harness/verify.sh
  [ "$status" -ne 0 ]
}

@test "verify: node — test 스크립트가 없으면 실패" {
  echo '{"scripts":{"lint":"true"}}' > package.json
  run bash .harness/verify.sh
  [ "$status" -ne 0 ]
  [[ "$output" =~ "test 스크립트가 없습니다" ]]
}

@test "verify: node_modules 같은 디렉토리는 탐지에서 제외" {
  mkdir -p node_modules/x
  echo '{"scripts":{"test":"node -e \"process.exit(1)\""}}' > node_modules/package.json
  run bash .harness/verify.sh
  [[ ! "$output" =~ "node_modules" ]]
}
