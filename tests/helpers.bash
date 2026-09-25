# 공통 헬퍼 — 임시 디렉토리에 하네스를 설치하고 샘플 feature 를 만든다.

PLUGIN_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
export CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT"
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

make_tmp() {
  WORK=$(mktemp -d)
  cd "$WORK"
}

cleanup_tmp() {
  cd /
  rm -rf "$WORK"
}

install_harness() {
  bash "$PLUGIN_ROOT/scripts/setup-harness.sh" >/dev/null
}

freeze_vision() { # 동결 상태로 전환 (사람이 한 것처럼 직접 수정)
  sed 's/^onboarded: false/onboarded: true/' CLAUDE.md > CLAUDE.md.tmp && mv CLAUDE.md.tmp CLAUDE.md
}

sample_feature() { # sample_feature <slug>
  local d=".harness/features/$1"
  mkdir -p "$d"
  cat > "$d/SPEC.md" <<'EOF'
# SPEC
- AC-1 로그인 성공
- AC-2 토큰 만료
- E-1 잘못된 비밀번호
- SE-1 기존 세션 무효화
EOF
  cat > "$d/TREE.md" <<'EOF'
# TREE
- [ ] 1 로그인 — covers: AC-1
  - [ ] 1.1 사용자 모델 — files: a.py — deps: - — covers: E-1
    > 계약: 예외 E-1 처리
  - [ ] 1.2 토큰 — deps: 1.3 — covers: AC-2
  - [ ] 1.3 설정
- [ ] 2 문서
EOF
}

harness() { bash .harness/bin/harness.sh "$@"; }

hook_input() { # hook_input <session_id> [extra jq]
  jq -n --arg s "$1" --arg c "$PWD" '{session_id: $s, cwd: $c, transcript_path: "/dev/null"}'
}
