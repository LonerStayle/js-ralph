#!/usr/bin/env bats

load helpers

setup() { make_tmp; install_harness; }
teardown() { cleanup_tmp; }

add_quality() {
  printf -- '- Q-1 [측정] 커버리지 80%%\n- Q-2 [판단] 에러 메시지는 다음 행동을 알려준다\n- Q-10 [측정] 번들 200KB 이하\n' >> CLAUDE.md
}

make_cards() { # make_cards <dir> <header...>
  local d="$1"; shift
  : > "$d/CARDS.md"
  for h in "$@"; do printf '## %s\n- 기획: %s 의 기획 문장\n\n' "$h" "$h" >> "$d/CARDS.md"; done
}

expire() { jq '.deadline = 0' .harness/proposal.json > p.tmp && mv p.tmp .harness/proposal.json; }

# ---------------- 품질 기준 ----------------

@test "quality: 기준 없으면 통과" {
  run harness quality
  [ "$status" -eq 0 ]
  [[ "$output" =~ "품질 기준 없음" ]]
}

@test "quality: [측정] 은 verify.d/q-<n> 스크립트가 있어야 ENFORCED, [판단] 은 REVIEW" {
  add_quality
  run harness quality
  [ "$status" -eq 1 ]
  [[ "$output" =~ "MISSING  - Q-1" ]]
  [[ "$output" =~ "REVIEW   - Q-2" ]]
  echo 'exit 0' > .harness/verify.d/q-1-coverage.sh
  echo 'exit 0' > .harness/verify.d/q-10.sh
  run harness quality
  [ "$status" -eq 0 ]
  [[ "$output" =~ "ENFORCED - Q-1" ]]
  [[ "$output" =~ "ENFORCED - Q-10" ]]
}

@test "quality: q-1 스크립트가 Q-10 을 충족한 것으로 착각하지 않음" {
  add_quality
  echo 'exit 0' > .harness/verify.d/q-1-coverage.sh
  run harness quality
  [[ "$output" =~ "MISSING  - Q-10" ]]
}

@test "coverage: 스크립트 없는 측정형 Q 는 트리 매핑 필수, 스크립트 생기면 면제" {
  add_quality; sample_feature login; harness start login
  run harness coverage
  [ "$status" -eq 1 ]
  [[ "$output" =~ "uncovered: Q-1" ]]
  [[ "$output" =~ "uncovered: Q-10" ]]
  [[ ! "$output" =~ "Q-2" ]]
  echo '- [ ] 3 Q 스크립트 — covers: Q-1, Q-10' >> .harness/features/login/TREE.md
  run harness coverage
  [ "$status" -eq 0 ]
}

# ---------------- 다음 기능 제안 ----------------

@test "proposal: open → pending, 기본 30분 기한" {
  d=$(harness proposal new)
  make_cards "$d" "C1 [사용자] 알림" "C2 [만드는 사람] 알림 모듈"
  harness proposal open "$d"
  [ "$(jq -r .status .harness/proposal.json)" = "pending" ]
  [ $(( $(jq -r .deadline .harness/proposal.json) - $(jq -r .opened_at .harness/proposal.json) )) -eq 1800 ]
  run harness proposal timeout
  [ "$output" = "PENDING" ]
}

@test "proposal: CARDS.md 없거나 헤더 형식이 틀리면 open 거부" {
  d=$(harness proposal new)
  run harness proposal open "$d"; [ "$status" -ne 0 ]
  echo "# 아무 카드 없음" > "$d/CARDS.md"
  run harness proposal open "$d"; [ "$status" -ne 0 ]
}

@test "proposal: 기한 경과 → 만드는 사람 카드만 자동 진행" {
  d=$(harness proposal new)
  make_cards "$d" "C1 [사용자] 알림" "C2 [전문가] 환불 규정" "C3 [만드는 사람] 알림 모듈 공통화"
  harness proposal open "$d"; expire
  run harness proposal timeout
  [ "$output" = "AUTO C3" ]
  [ "$(jq -r .auto_chain .harness/proposal.json)" = "1" ]
  run harness proposal card
  [[ "$output" =~ "## C3 [만드는 사람] 알림 모듈 공통화" ]]
  [[ ! "$output" =~ "C1" ]]
}

@test "proposal: 만드는 사람 카드가 없으면 자동 진행 안 함" {
  d=$(harness proposal new)
  make_cards "$d" "C1 [사용자] 알림" "C2 [전문가] 환불 규정"
  harness proposal open "$d"; expire
  run harness proposal timeout
  [ "$output" = "NO_AUTO_CARD" ]
  [ "$(jq -r .status .harness/proposal.json)" = "pending" ]
}

@test "proposal: 자동 진행은 연속 3회까지, 그 뒤엔 사용자 대기" {
  for i in 1 2 3; do
    d=$(harness proposal new); make_cards "$d" "C1 [만드는 사람] 정리 $i"
    harness proposal open "$d"; expire
    run harness proposal timeout; [ "$output" = "AUTO C1" ]
    harness proposal done >/dev/null
    sleep 1
  done
  d=$(harness proposal new); make_cards "$d" "C1 [만드는 사람] 정리 4"
  harness proposal open "$d"; expire
  run harness proposal timeout
  [[ "$output" == "WAIT_USER"* ]]
  [ "$(jq -r .status .harness/proposal.json)" = "pending" ]
}

@test "proposal: 사람이 고르면 연속 카운터 초기화, 이후 timeout 은 CHOSEN" {
  d=$(harness proposal new); make_cards "$d" "C1 [만드는 사람] a"
  harness proposal open "$d"; expire; harness proposal timeout >/dev/null; harness proposal done >/dev/null
  sleep 1
  d=$(harness proposal new); make_cards "$d" "C1 [사용자] b" "C2 [만드는 사람] c"
  harness proposal open "$d"
  [ "$(jq -r .auto_chain .harness/proposal.json)" = "1" ]
  harness proposal choose C1
  [ "$(jq -r .auto_chain .harness/proposal.json)" = "0" ]
  expire
  run harness proposal timeout
  [ "$output" = "CHOSEN C1" ]
}

@test "proposal: 없는 카드 / 대기 없음 상태에서 choose 거부" {
  run harness proposal choose C1; [ "$status" -ne 0 ]
  d=$(harness proposal new); make_cards "$d" "C1 [사용자] a"
  harness proposal open "$d"
  run harness proposal choose C9; [ "$status" -ne 0 ]
}

@test "proposal: wait 는 선택되면 즉시 CHOSEN 으로 끝난다" {
  d=$(harness proposal new); make_cards "$d" "C1 [사용자] a" "C2 [만드는 사람] b"
  harness proposal open "$d"
  ( sleep 1; bash .harness/bin/harness.sh proposal choose C1 >/dev/null ) &
  HARNESS_POLL_SECONDS=1 run timeout 20 bash .harness/bin/harness.sh proposal wait
  [ "$output" = "CHOSEN C1" ]
}

@test "proposal: config.json 대기 시간을 따른다" {
  jq '.proposal_wait_minutes = 5' .harness/config.json > c.tmp && mv c.tmp .harness/config.json
  d=$(harness proposal new); make_cards "$d" "C1 [사용자] a"
  harness proposal open "$d"
  [ $(( $(jq -r .deadline .harness/proposal.json) - $(jq -r .opened_at .harness/proposal.json) )) -eq 300 ]
}
