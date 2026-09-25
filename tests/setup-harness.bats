#!/usr/bin/env bats

load helpers

setup() { make_tmp; }
teardown() { cleanup_tmp; }

@test "clean: 빈 디렉토리에 하네스 설치 + git 초기 커밋" {
  run bash "$PLUGIN_ROOT/scripts/setup-harness.sh"
  [ "$status" -eq 0 ]
  for f in CLAUDE.md README.md .harness/verify.sh .harness/bin/harness.sh .harness/memory/MEMORY.md \
           .claude/settings.json .claude/skills/.gitkeep .gitignore VERSION; do
    [ -e "$f" ] || { echo "missing: $f"; return 1; }
  done
  [ -x .harness/verify.sh ]
  [ -x .harness/bin/harness.sh ]
  [ "$(tr -d '[:space:]' < VERSION)" = "4" ]
  [ -n "$(git log --oneline)" ]
}

@test "clean: 프로젝트 이름 치환 (특수문자 안전)" {
  mkdir "a|b&c" && cd "a|b&c"
  bash "$PLUGIN_ROOT/scripts/setup-harness.sh" >/dev/null
  ! grep -q '{{PROJECT_NAME}}' CLAUDE.md README.md
  grep -qF 'a|b&c' CLAUDE.md
}

@test "clean: 충돌 파일이 있으면 중단하고 --overlay 안내" {
  echo keep > CLAUDE.md
  run bash "$PLUGIN_ROOT/scripts/setup-harness.sh"
  [ "$status" -ne 0 ]
  [[ "$output" =~ "--overlay" ]]
  [ "$(cat CLAUDE.md)" = "keep" ]
  [ ! -d .harness ]
}

@test "overlay: 기존 CLAUDE.md/settings 백업, README 보존, .gitignore 병합" {
  git init -q -b main
  echo "# 기존 규칙" > CLAUDE.md
  echo "# my app" > README.md
  mkdir -p .claude && echo '{"x":1}' > .claude/settings.json
  printf 'node_modules/\ncustom/\n' > .gitignore
  run bash "$PLUGIN_ROOT/scripts/setup-harness.sh" --overlay
  [ "$status" -eq 0 ]
  [ "$(cat CLAUDE.md.pre-harness)" = "# 기존 규칙" ]
  [ "$(cat .claude/settings.json.pre-harness)" = '{"x":1}' ]
  [ "$(cat README.md)" = "# my app" ]
  grep -qx 'custom/' .gitignore
  grep -qx '.harness/run.json' .gitignore
  [ "$(grep -cx 'node_modules/' .gitignore)" = "1" ]
  grep -q '^onboarded: false' CLAUDE.md
}

@test "overlay: 동결된 비전은 --force 없이 보호" {
  install_harness; freeze_vision
  run bash "$PLUGIN_ROOT/scripts/setup-harness.sh" --overlay
  [ "$status" -ne 0 ]
  grep -q '^onboarded: true' CLAUDE.md
  run bash "$PLUGIN_ROOT/scripts/setup-harness.sh" --overlay --force
  [ "$status" -eq 0 ]
  grep -q '^onboarded: false' CLAUDE.md
  [ -d .harness.pre-harness ]
}

@test "HOME 에서 실행 거부" {
  cd "$HOME"
  run bash "$PLUGIN_ROOT/scripts/setup-harness.sh"
  [ "$status" -eq 2 ]
}

@test "알 수 없는 인자 거부" {
  run bash "$PLUGIN_ROOT/scripts/setup-harness.sh" --bogus
  [ "$status" -eq 2 ]
}
