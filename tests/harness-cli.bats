#!/usr/bin/env bats

load helpers

setup() { make_tmp; install_harness; sample_feature login; }
teardown() { cleanup_tmp; }

@test "start: run.json 생성 (running, base_commit)" {
  run harness start login
  [ "$status" -eq 0 ]
  [ "$(jq -r .status .harness/run.json)" = "running" ]
  [ "$(jq -r .feature .harness/run.json)" = "login" ]
  [ "$(jq -r .base_commit .harness/run.json)" = "$(git rev-parse HEAD)" ]
}

@test "start: TREE.md 없는 feature 거부 / 잘못된 slug 거부" {
  run harness start nothing
  [ "$status" -ne 0 ]
  run harness start "Bad Slug"
  [ "$status" -ne 0 ]
}

@test "next: 바텀업 — 자식 먼저, 부모는 자식 완료 후" {
  harness start login
  run harness next
  [[ "$output" == "READY 1.1 "* ]]
  harness set 1.1 done
  run harness next
  [[ "$output" == "READY 1.3 "* ]]   # 1.2 는 deps 1.3 대기
  harness set 1.3 done
  run harness next
  [[ "$output" == "READY 1.2 "* ]]
  harness set 1.2 done
  run harness next
  [[ "$output" == "READY 1 "* ]]
}

@test "next: doing 노드가 있으면 그것부터 재개" {
  harness start login
  harness set 1.3 doing
  run harness next
  [[ "$output" == "READY 1.3 "* ]]
}

@test "next: DONE / BLOCKED / STUCK 판정" {
  harness start login
  for id in 1.1 1.2 1.3 1 2; do harness set $id done >/dev/null; done
  run harness next; [ "$output" = "DONE" ]
  harness set 2 blocked
  run harness next; [ "$output" = "BLOCKED" ]
  cat > .harness/features/login/TREE.md <<'EOF'
- [ ] 1 a — deps: 2
- [ ] 2 b — deps: 1
EOF
  run harness next; [ "$output" = "STUCK" ]
}

@test "set: 없는 노드 / 잘못된 상태 거부, 들여쓰기·계약 줄 보존" {
  harness start login
  run harness set 9.9 done; [ "$status" -ne 0 ]
  run harness set 1.1 finished; [ "$status" -ne 0 ]
  harness set 1.1 done
  grep -q '^  - \[x\] 1.1 사용자 모델' .harness/features/login/TREE.md
  grep -q '^    > 계약: 예외 E-1 처리' .harness/features/login/TREE.md
}

@test "counts" {
  harness start login
  harness set 1.1 done; harness set 1.2 doing; harness set 2 blocked
  run harness counts
  [ "$output" = "5 1 1 2 1" ]
}

@test "coverage: AC-/E- 전부 매핑되면 통과, SE- 는 강제하지 않음" {
  harness start login
  run harness coverage
  [ "$status" -eq 0 ]
  echo "- E-7 동시 로그인" >> .harness/features/login/SPEC.md
  run harness coverage
  [ "$status" -eq 1 ]
  [[ "$output" =~ "uncovered: E-7" ]]
}

@test "coverage: E-1 이 E-10 에 부분 일치로 통과하지 않음" {
  harness start login
  echo "- E-10 추가" >> .harness/features/login/SPEC.md
  sed 's/covers: E-1$/covers: E-10/' .harness/features/login/TREE.md > t && mv t .harness/features/login/TREE.md
  run harness coverage
  [ "$status" -eq 1 ]
  [[ "$output" =~ "uncovered: E-1"$'\n' ]] || [[ "$output" =~ "uncovered: E-1" ]]
  [[ ! "$output" =~ "uncovered: E-10" ]]
}

@test "pause / resume / finish 상태 전이, resume 은 세션 소유권·카운터 초기화" {
  harness start login
  harness pause;  [ "$(jq -r .status .harness/run.json)" = "paused" ]
  jq '.session_id="s1" | .continuations=7 | .stall_count=2' .harness/run.json > r && mv r .harness/run.json
  harness resume
  [ "$(jq -r .status .harness/run.json)" = "running" ]
  [ "$(jq -r .session_id .harness/run.json)" = "" ]
  [ "$(jq -r .continuations .harness/run.json)" = "0" ]
  [ "$(jq -r .stall_count .harness/run.json)" = "0" ]
  harness finish blocked; [ "$(jq -r .status .harness/run.json)" = "blocked" ]
}

@test "다른 feature 가 running 이면 start 거부" {
  harness start login
  sample_feature signup
  run harness start signup
  [ "$status" -ne 0 ]
}

@test "하위 디렉토리에서도 하네스 루트를 찾는다" {
  harness start login
  mkdir -p src/deep && cd src/deep
  run bash ../../.harness/bin/harness.sh next
  [[ "$output" == "READY 1.1 "* ]]
}
