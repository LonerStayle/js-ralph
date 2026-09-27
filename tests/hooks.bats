#!/usr/bin/env bats

load helpers

setup() { make_tmp; }
teardown() { cleanup_tmp; }

stop_hook() { hook_input "$1" | bash "$PLUGIN_ROOT/hooks/stop-guard.sh"; }
session_hook() { jq -n --arg c "$PWD" --arg s "${1:-startup}" '{cwd: $c, source: $s}' | bash "$PLUGIN_ROOT/hooks/session-context.sh"; }
pre_hook() { # pre_hook <tool> <json tool_input>
  jq -n --arg c "$PWD" --arg t "$1" --argjson i "$2" '{cwd: $c, tool_name: $t, tool_input: $i}' \
    | bash "$PLUGIN_ROOT/hooks/protect-files.sh"
}
decision() { # 빈 출력 = 허용
  if [ -z "$1" ]; then echo allow; else printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecision // "allow"'; fi
}

# ---------------- Stop guard ----------------

@test "stop: 하네스 없는 디렉토리는 no-op" {
  run stop_hook s1
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "stop: running + 남은 노드 → block, 다음 노드 안내, 세션 소유권 획득" {
  install_harness; sample_feature login; harness start login
  run stop_hook s1
  [ "$status" -eq 0 ]
  [ "$(printf '%s' "$output" | jq -r .decision)" = "block" ]
  [[ "$(printf '%s' "$output" | jq -r .reason)" =~ "1.1" ]]
  [ "$(jq -r .session_id .harness/run.json)" = "s1" ]
  [ "$(jq -r .continuations .harness/run.json)" = "1" ]
}

@test "stop: 다른 세션 소유 run 에는 간섭하지 않음" {
  install_harness; sample_feature login; harness start login
  stop_hook s1 >/dev/null
  run stop_hook s2
  [ -z "$output" ]
  [ "$(jq -r .continuations .harness/run.json)" = "1" ]
}

@test "stop: paused 면 통과" {
  install_harness; sample_feature login; harness start login; harness pause
  run stop_hook s1
  [ -z "$output" ]
}

@test "stop: 트리 완료 → 통과 + status done" {
  install_harness; sample_feature login; harness start login
  for id in 1.1 1.2 1.3 1 2; do harness set $id done >/dev/null; done
  run stop_hook s1
  [ "$(printf '%s' "$output" | jq -r '.decision // empty' 2>/dev/null)" != "block" ]
  [ "$(jq -r .status .harness/run.json)" = "done" ]
}

@test "stop: 남은 게 blocked 뿐이면 통과 + status blocked" {
  install_harness; sample_feature login; harness start login
  for id in 1.1 1.2 1.3 1; do harness set $id done >/dev/null; done
  harness set 2 blocked
  run stop_hook s1
  [ "$(jq -r .status .harness/run.json)" = "blocked" ]
}

@test "stop: 진척 없이 3회 연속 → blocked 로 정지 (헛돌기 방지)" {
  install_harness; sample_feature login; harness start login
  git add -A && git commit -qm plan
  run stop_hook s1; [ "$(printf '%s' "$output" | jq -r .decision)" = "block" ]   # 지문 최초 기록
  run stop_hook s1; [[ "$(printf '%s' "$output" | jq -r .reason)" =~ "1/3" ]]
  run stop_hook s1; [[ "$(printf '%s' "$output" | jq -r .reason)" =~ "2/3" ]]
  run stop_hook s1
  [ "$(jq -r .status .harness/run.json)" = "blocked" ]
}

@test "stop: 진척이 있으면 정체 카운터 리셋" {
  install_harness; sample_feature login; harness start login
  stop_hook s1 >/dev/null; stop_hook s1 >/dev/null
  [ "$(jq -r .stall_count .harness/run.json)" = "1" ]
  harness set 1.1 done
  stop_hook s1 >/dev/null
  [ "$(jq -r .stall_count .harness/run.json)" = "0" ]
}

@test "stop: max_continuations 도달 → paused" {
  install_harness; sample_feature login; harness start login 2
  harness set 1.1 doing; stop_hook s1 >/dev/null
  harness set 1.1 done;  stop_hook s1 >/dev/null
  run stop_hook s1
  [ "$(jq -r .status .harness/run.json)" = "paused" ]
}

# ---------------- SessionStart ----------------

@test "session: 하네스 없으면 no-op" {
  run session_hook
  [ -z "$output" ]
}

@test "session: 미동결이면 vision-intake 안내" {
  install_harness
  run session_hook
  [[ "$(printf '%s' "$output" | jq -r .hookSpecificOutput.additionalContext)" =~ "vision-intake" ]]
}

@test "session: running 이면 압축 뒤 상태·다음 노드 주입" {
  install_harness; freeze_vision; sample_feature login; harness start login
  run session_hook compact
  ctx=$(printf '%s' "$output" | jq -r .hookSpecificOutput.additionalContext)
  [[ "$ctx" =~ "feature-orchestration" ]]
  [[ "$ctx" =~ "READY 1.1" ]]
  [[ "$ctx" =~ "compact" ]]
}

@test "session: paused 면 자동 재개 금지 안내" {
  install_harness; freeze_vision; sample_feature login; harness start login; harness pause
  run session_hook
  [[ "$(printf '%s' "$output" | jq -r .hookSpecificOutput.additionalContext)" =~ "/resume" ]]
}

# ---------------- PreToolUse 보호 ----------------

@test "protect: 하네스 없으면 전부 허용" {
  run pre_hook Edit '{"file_path":"CLAUDE.md"}'
  [ -z "$output" ]
}

@test "protect: 동결 전에는 CLAUDE.md 수정 허용 (vision-intake 합성)" {
  install_harness
  run pre_hook Edit "{\"file_path\":\"$PWD/CLAUDE.md\"}"
  [ "$(decision "$output")" = "allow" ]
}

@test "protect: run.json 은 동결 전에도 직접 수정 차단" {
  install_harness
  run pre_hook Write "{\"file_path\":\"$PWD/.harness/run.json\"}"
  [ "$(decision "$output")" = "deny" ]
  run pre_hook Bash '{"command":"echo {} > .harness/run.json"}'
  [ "$(decision "$output")" = "deny" ]
}

@test "protect: 동결 후 CLAUDE.md / verify.sh / bin 수정 차단" {
  install_harness; freeze_vision
  for p in CLAUDE.md .harness/verify.sh .harness/bin/harness.sh; do
    run pre_hook Edit "{\"file_path\":\"$PWD/$p\"}"
    [ "$(decision "$output")" = "deny" ] || { echo "not denied: $p"; return 1; }
  done
}

@test "protect: verify.d — 진행 중 feature 가 만든 스크립트는 그 feature 동안 수정 가능, 끝나면 잠김" {
  install_harness; freeze_vision; sample_feature login
  git add -A && git commit -qm plan
  harness start login
  echo 'exit 0' > .harness/verify.d/q-1-cov.sh
  git add -A && git commit -qm "q-1 script"
  run pre_hook Edit "{\"file_path\":\"$PWD/.harness/verify.d/q-1-cov.sh\"}"
  [ "$(decision "$output")" = "allow" ]
  harness finish done
  run pre_hook Edit "{\"file_path\":\"$PWD/.harness/verify.d/q-1-cov.sh\"}"
  [ "$(decision "$output")" = "deny" ]
  # 다음 feature 에서는 이전 feature 가 만든 스크립트가 base_commit 에 있으므로 잠김
  sample_feature signup; git add -A && git commit -qm plan2
  harness start signup
  run pre_hook Edit "{\"file_path\":\"$PWD/.harness/verify.d/q-1-cov.sh\"}"
  [ "$(decision "$output")" = "deny" ]
}

@test "protect: verify.d — 새 파일 추가 허용, 기존 파일 수정/덮어쓰기 차단" {
  install_harness; freeze_vision
  run pre_hook Write "{\"file_path\":\"$PWD/.harness/verify.d/10-e2e.sh\"}"
  [ "$(decision "$output")" = "allow" ]
  echo 'exit 0' > .harness/verify.d/10-e2e.sh
  run pre_hook Write "{\"file_path\":\"$PWD/.harness/verify.d/10-e2e.sh\"}"
  [ "$(decision "$output")" = "deny" ]
  run pre_hook Edit "{\"file_path\":\"$PWD/.harness/verify.d/10-e2e.sh\"}"
  [ "$(decision "$output")" = "deny" ]
}

@test "protect: 일반 소스 · TREE.md · 메모리 · 스킬은 허용" {
  install_harness; freeze_vision
  for p in src/app.py .harness/features/x/TREE.md .harness/memory/MEMORY.md .claude/skills/a/SKILL.md; do
    run pre_hook Edit "{\"file_path\":\"$PWD/$p\"}"
    [ "$(decision "$output")" = "allow" ] || { echo "denied: $p"; return 1; }
  done
}

@test "protect: 셸 우회 차단 — rm/sed -i/리다이렉트/git checkout" {
  install_harness; freeze_vision
  for c in "rm .harness/verify.sh" "sed -i 's/x/y/' .harness/verify.sh" "echo exit 0 > .harness/verify.sh" \
           "cp /tmp/x .harness/bin/harness.sh" "git checkout HEAD~1 -- .harness/verify.sh" "rm .harness/verify.d/10.sh" \
           "echo x >> CLAUDE.md"; do
    run pre_hook Bash "$(jq -n --arg c "$c" '{command: $c}')"
    [ "$(decision "$output")" = "deny" ] || { echo "not denied: $c"; return 1; }
  done
}

@test "protect: 셸 — 검증 실행 · 읽기는 허용" {
  install_harness; freeze_vision
  for c in "bash .harness/verify.sh" "bash .harness/verify.sh > /tmp/log 2>&1" "cat CLAUDE.md" \
           "grep -rn term CLAUDE.md" "bash .harness/bin/harness.sh set 1.1 done"; do
    run pre_hook Bash "$(jq -n --arg c "$c" '{command: $c}')"
    [ "$(decision "$output")" = "allow" ] || { echo "denied: $c"; return 1; }
  done
}

# ---------------- 제안 · 설정 보호 ----------------

@test "protect: proposal.json 직접 수정 차단, config.json 은 동결 후 차단" {
  install_harness
  run pre_hook Write "{\"file_path\":\"$PWD/.harness/proposal.json\"}"
  [ "$(decision "$output")" = "deny" ]
  run pre_hook Edit "{\"file_path\":\"$PWD/.harness/config.json\"}"
  [ "$(decision "$output")" = "allow" ]
  freeze_vision
  run pre_hook Edit "{\"file_path\":\"$PWD/.harness/config.json\"}"
  [ "$(decision "$output")" = "deny" ]
  run pre_hook Bash '{"command":"echo {} > .harness/config.json"}'
  [ "$(decision "$output")" = "deny" ]
  run pre_hook Edit "{\"file_path\":\"$PWD/.harness/FOCUS.md\"}"
  [ "$(decision "$output")" = "allow" ]
}

@test "session: 제안 대기 중이면 카드 재안내 + 타이머 재시작 지시" {
  install_harness; freeze_vision
  d=$(harness proposal new); printf '## C1 [사용자] a\n' > "$d/CARDS.md"; harness proposal open "$d"
  run session_hook resume
  ctx=$(printf '%s' "$output" | jq -r .hookSpecificOutput.additionalContext)
  [[ "$ctx" =~ "proposal wait" ]]
}

@test "session: 세션이 끊긴 사이 기한이 지났으면 timeout 처리 지시" {
  install_harness; freeze_vision
  d=$(harness proposal new); printf '## C1 [만드는 사람] a\n' > "$d/CARDS.md"; harness proposal open "$d"
  jq '.deadline = 0' .harness/proposal.json > p.tmp && mv p.tmp .harness/proposal.json
  run session_hook startup
  [[ "$(printf '%s' "$output" | jq -r .hookSpecificOutput.additionalContext)" =~ "proposal timeout" ]]
}

@test "stop: 커밋 전 작업 중인 파일 변경도 진척으로 본다 (서브에이전트 작업 중 오판 방지)" {
  install_harness; sample_feature login; harness start login
  git add -A && git commit -qm plan
  stop_hook s1 >/dev/null; stop_hook s1 >/dev/null
  [ "$(jq -r .stall_count .harness/run.json)" = "1" ]
  echo "work in progress" > wip.js
  stop_hook s1 >/dev/null
  [ "$(jq -r .stall_count .harness/run.json)" = "0" ]
  echo "more" >> wip.js
  stop_hook s1 >/dev/null
  [ "$(jq -r .stall_count .harness/run.json)" = "0" ]
}

# ---------------- 서브에이전트 추적 ----------------

track() { jq -n --arg c "$PWD" --arg id "$2" '{cwd: $c, agent_id: $id, agent_type: "js-ralph:builder"}' | bash "$PLUGIN_ROOT/hooks/subagent-track.sh" "$1"; }

@test "subagent: 실행 중이면 Stop 가드가 정체로 세지 않고 조용히 허용, 끝나면 다시 가드" {
  install_harness; sample_feature login; harness start login
  git add -A && git commit -qm plan
  stop_hook s1 >/dev/null
  track start a1
  for i in 1 2 3 4; do run stop_hook s1; [ -z "$output" ]; done
  [ "$(jq -r .stall_count .harness/run.json)" = "0" ]
  [ "$(jq -r .status .harness/run.json)" = "running" ]
  track stop a1
  run stop_hook s1
  [ "$(printf '%s' "$output" | jq -r .decision)" = "block" ]
}

@test "subagent: 같은 id 는 하나만 지우고, 오래된 기록은 무시" {
  install_harness; sample_feature login; harness start login
  track start a1; track start a2; track stop a1
  [ "$(wc -l < .harness/agents.active | tr -d ' ')" = "1" ]
  track stop a2
  echo "old $(( $(date +%s) - 6000 ))" > .harness/agents.active
  run stop_hook s1
  [ "$(printf '%s' "$output" | jq -r .decision)" = "block" ]
}

@test "subagent: 하네스 없으면 no-op" {
  run track start a1
  [ ! -e .harness/agents.active ]
}
