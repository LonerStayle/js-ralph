#!/usr/bin/env bash
# .harness/bin/harness.sh — 하네스 상태를 결정적으로 다루는 단일 CLI.
#
# LLM 이 TREE.md 의 체크 표시나 run.json 을 손으로 고치지 않도록, 상태 전이는 전부 이 스크립트로 한다.
# 플러그인 hook 도 같은 원본 파일을 호출하므로 판정 로직은 한 곳에만 있다.
#
# 사용:
#   harness.sh next                 다음에 착수할 노드 (READY <id> <제목...> | DONE | BLOCKED | STUCK | NONE)
#   harness.sh set <id> <state>     노드 상태 변경 (todo | doing | done | blocked)
#   harness.sh counts               "total done doing todo blocked"
#   harness.sh coverage             SPEC.md 의 AC-/E- ID 중 TREE.md 에 매핑 안 된 것 출력 (있으면 exit 1)
#   harness.sh start <slug> [max]   run 시작 (status=running)
#   harness.sh pause | resume       run 일시정지 / 재개
#   harness.sh finish [done|blocked]  run 종료 상태 기록
#   harness.sh status               사람이 읽는 요약
#   harness.sh feature-dir          활성 feature 디렉토리 경로
#   harness.sh fingerprint          진척 지문 (TREE.md + git HEAD + 커밋 전 작업) — 정체 감지용
#   harness.sh quality              품질 기준(CLAUDE.md Q-n) 강제 현황 — 측정형인데 스크립트 없으면 exit 1
#   harness.sh proposal new|open <dir>|choose <C>|wait|timeout|card [C]|done|status
#                                   다음 기능 제안 카드 선택 대기 · 기한 후 자동 진행 판단
#
# TREE.md 노드 한 줄 형식 (들여쓰기는 자유, ID 가 계층을 결정):
#   - [ ] 1.2.3 제목 — files: a.py, b.py — deps: 1.1 — covers: AC-1, E-3
#   상태: [ ] todo · [~] doing · [x] done · [!] blocked

set -euo pipefail

die() { echo "[harness] $*" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || die "jq 가 필요합니다 (brew install jq / apt install jq)."

# --- 하네스 루트 탐색 (.harness 를 가진 가장 가까운 상위 디렉토리) --------
find_root() {
  local d="${HARNESS_ROOT:-$PWD}"
  while [ "$d" != "/" ] && [ -n "$d" ]; do
    if [ -d "$d/.harness" ]; then echo "$d"; return 0; fi
    d=$(dirname "$d")
  done
  return 1
}
ROOT=$(find_root) || die ".harness/ 를 찾지 못했습니다. /setup-harness 로 먼저 하네스를 세팅하십시오."
H="$ROOT/.harness"
RUN="$H/run.json"

now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

run_get() { [ -f "$RUN" ] && jq -r "$1 // empty" "$RUN" 2>/dev/null || true; }

run_set() { # jq 필터로 run.json 갱신 (원자적 교체)
  local tmp
  tmp=$(mktemp "$H/.run.XXXXXX")
  jq "$@" "$RUN" > "$tmp" && mv "$tmp" "$RUN"
}

feature_dir() {
  local slug="${HARNESS_FEATURE:-$(run_get .feature)}"
  [ -n "$slug" ] || die "활성 feature 가 없습니다. /feature 로 시작하십시오."
  echo "$H/features/$slug"
}

tree_file() {
  local t
  t="$(feature_dir)/TREE.md"
  [ -f "$t" ] || die "TREE.md 가 없습니다: $t"
  echo "$t"
}

# --- 트리 파싱: "상태<TAB>ID<TAB>deps<TAB>나머지" 로 정규화 -----------------
parse_tree() {
  awk '
    {
      line = $0
      sub(/^[ \t]+/, "", line)
      if (substr(line, 1, 3) != "- [" || substr(line, 5, 2) != "] ") next
      st = substr(line, 4, 1)
      rest = substr(line, 7)
      split(rest, w, " ")
      id = w[1]
      if (id !~ /^[0-9]+(\.[0-9]+)*$/) next
      title = substr(rest, length(id) + 2)
      deps = ""
      p = index(title, "deps:")
      if (p > 0) {
        deps = substr(title, p + 5)
        q = index(deps, "—"); if (q > 0) deps = substr(deps, 1, q - 1)
        gsub(/[ ,]+/, " ", deps); sub(/^ /, "", deps); sub(/ $/, "", deps)
        if (deps == "-") deps = ""
      }
      print st "\t" id "\t" deps "\t" title
    }' "$1"
}

cmd_next() {
  local t; t=$(tree_file)
  parse_tree "$t" | awk -F'\t' '
    { n++; st[n]=$1; id[n]=$2; dep[n]=$3; title[n]=$4; stat[$2]=$1 }
    END {
      if (n == 0) { print "NONE"; exit }
      # 1) 진행 중 노드가 있으면 그것부터 마무리
      for (i = 1; i <= n; i++) if (st[i] == "~") { print "READY " id[i] " " title[i]; exit }
      pending = 0; blocked = 0
      for (i = 1; i <= n; i++) {
        if (st[i] == "!") blocked++
        if (st[i] != " ") continue
        pending++
        ok = 1
        # 자식 전부 done 이어야 부모 착수 (바텀업)
        pre = id[i] "."
        for (j = 1; j <= n; j++)
          if (substr(id[j], 1, length(pre)) == pre && st[j] != "x") { ok = 0; break }
        # 선행 의존 전부 done
        if (ok && dep[i] != "") {
          m = split(dep[i], d, " ")
          for (k = 1; k <= m; k++) if (stat[d[k]] != "x") { ok = 0; break }
        }
        if (ok) { print "READY " id[i] " " title[i]; exit }
      }
      if (pending == 0 && blocked == 0) print "DONE"
      else if (blocked > 0) print "BLOCKED"
      else print "STUCK"
    }'
}

cmd_set() {
  [ $# -eq 2 ] || die "사용: harness.sh set <id> <todo|doing|done|blocked>"
  local id="$1" mark
  case "$2" in
    todo) mark=" " ;; doing) mark="~" ;; done) mark="x" ;; blocked) mark="!" ;;
    *) die "알 수 없는 상태: $2" ;;
  esac
  [[ "$id" =~ ^[0-9]+(\.[0-9]+)*$ ]] || die "잘못된 노드 ID: $id"
  local t tmp; t=$(tree_file); tmp=$(mktemp "$H/.tree.XXXXXX")
  awk -v id="$id" -v mark="$mark" '
    {
      line = $0
      match(line, /^[ \t]*/)
      body = substr(line, RLENGTH + 1)
      split(substr(body, 7), w, " ")
      if (!done && substr(body, 1, 3) == "- [" && substr(body, 5, 2) == "] " && w[1] == id) {
        line = substr(line, 1, RLENGTH) "- [" mark "] " substr(body, 7)
        done = 1
      }
      print line
    }
    END { if (!done) exit 3 }' "$t" > "$tmp" || { rm -f "$tmp"; die "노드 $id 를 TREE.md 에서 찾지 못했습니다."; }
  mv "$tmp" "$t"
  [ -f "$RUN" ] && run_set --arg t "$(now)" '.updated_at = $t'
  echo "[harness] $id → $2"
}

cmd_counts() {
  local t; t=$(tree_file)
  parse_tree "$t" | awk -F'\t' '
    { n++; if ($1=="x") d++; else if ($1=="~") g++; else if ($1=="!") b++; else t++ }
    END { printf "%d %d %d %d %d\n", n, d, g, t, b }'
}

# 측정형 품질 기준 중 verify.d 스크립트가 아직 없는 ID (예: Q-1 → .harness/verify.d/q-1-*.sh 또는 q-1.sh)
quality_missing() {
  [ -f "$ROOT/CLAUDE.md" ] || return 0
  local q n
  for q in $(grep -oE '^- Q-[0-9]+ \[측정\]' "$ROOT/CLAUDE.md" | grep -oE 'Q-[0-9]+' || true); do
    n=$(echo "$q" | tr 'Q' 'q')
    local found=0 f
    for f in "$H/verify.d/$n.sh" "$H/verify.d/$n-"*.sh; do [ -f "$f" ] && found=1; done
    [ "$found" -eq 1 ] || echo "$q"
  done
}

cmd_quality() {
  [ -f "$ROOT/CLAUDE.md" ] || die "CLAUDE.md 가 없습니다."
  local lines missing
  lines=$(grep -E '^- Q-[0-9]+ \[(측정|판단)\]' "$ROOT/CLAUDE.md" || true)
  if [ -z "$lines" ]; then echo "품질 기준 없음"; return 0; fi
  missing=$(quality_missing)
  echo "$lines" | while IFS= read -r l; do
    q=$(echo "$l" | grep -oE 'Q-[0-9]+' | head -1)
    case "$l" in
      *"[측정]"*) if echo "$missing" | grep -qx "$q"; then echo "MISSING  $l"; else echo "ENFORCED $l"; fi ;;
      *) echo "REVIEW   $l" ;;
    esac
  done
  [ -z "$missing" ]
}

cmd_coverage() {
  local fd; fd=$(feature_dir)
  [ -f "$fd/SPEC.md" ] || die "SPEC.md 가 없습니다: $fd/SPEC.md"
  local ids missing=0
  # SPEC 의 수용 기준·예외 + 아직 검증 스크립트가 없는 측정형 품질 기준은 모두 노드에 매핑돼야 한다
  ids=$( { grep -owE '(AC|E)-[0-9]+' "$fd/SPEC.md" || true; quality_missing; } | sort -u)
  for x in $ids; do
    if ! grep -E 'covers:' "$fd/TREE.md" | grep -qE "(^|[^0-9A-Za-z-])$x([^0-9]|$)"; then
      echo "uncovered: $x"; missing=1
    fi
  done
  [ "$missing" -eq 0 ] && echo "coverage ok ($(echo "$ids" | grep -c . || true) ids)"
  return "$missing"
}

# --- 다음 기능 제안 (proposal) ---------------------------------------------
PROP="$H/proposal.json"
CONFIG="$H/config.json"
cfg() { jq -r "$1 // empty" "$CONFIG" 2>/dev/null || true; }
prop_get() { [ -f "$PROP" ] && jq -r "$1 // empty" "$PROP" 2>/dev/null || true; }
prop_set() { local tmp; tmp=$(mktemp "$H/.prop.XXXXXX"); jq "$@" "$PROP" > "$tmp" && mv "$tmp" "$PROP"; }

# CARDS.md 의 카드 헤더: "## C<n> [시야] 제목"
card_line() { grep -E "^## $1 \[" "$2/CARDS.md" | head -1; }

cmd_proposal() {
  local sub="${1:-status}"; shift || true
  case "$sub" in
    new) # 새 제안 디렉토리 생성 후 경로 출력
      local d="$H/proposals/$(date -u +%Y%m%d-%H%M%S)"
      mkdir -p "$d"; echo "$d" ;;
    open) # open <dir> — CARDS.md 가 준비된 제안을 사용자 선택 대기 상태로
      [ $# -eq 1 ] || die "사용: harness.sh proposal open <dir>"
      local d="$1" wait chain
      [ -f "$d/CARDS.md" ] || die "CARDS.md 가 없습니다: $d"
      grep -qE '^## C[0-9]+ \[' "$d/CARDS.md" || die "CARDS.md 에 카드 헤더(## C<n> [시야] 제목)가 없습니다."
      wait=$(cfg .proposal_wait_minutes); wait=${wait:-30}
      chain=$(prop_get .auto_chain); chain=${chain:-0}
      jq -n --arg d "$d" --argjson now "$(date +%s)" --argjson w "$wait" --argjson c "$chain" '{
        status: "pending", dir: $d, opened_at: $now, deadline: ($now + $w * 60),
        card: "", auto_chain: $c }' > "$PROP"
      echo "[harness] 제안 대기 시작 (${wait}분 후 자동 진행 판단): $d" ;;
    choose) # choose <C번호> — 사람의 선택. 자동 진행 연쇄 카운터 초기화
      [ $# -eq 1 ] || die "사용: harness.sh proposal choose <C번호>"
      [ "$(prop_get .status)" = "pending" ] || die "대기 중인 제안이 없습니다."
      card_line "$1" "$(prop_get .dir)" >/dev/null || die "카드 $1 이 없습니다."
      prop_set --arg c "$1" '.status = "chosen" | .card = $c | .auto_chain = 0'
      echo "[harness] 선택: $(card_line "$1" "$(prop_get .dir)")" ;;
    wait) # 기한까지 대기 → 선택되면 CHOSEN, 기한 지나면 자동 판단 (AUTO / WAIT_USER / NO_AUTO_CARD)
      while [ "$(prop_get .status)" = "pending" ] && [ "$(date +%s)" -lt "$(prop_get .deadline)" ]; do
        sleep "${HARNESS_POLL_SECONDS:-20}"
      done
      cmd_proposal timeout ;;
    timeout) # 기한 경과 시 자동 진행 판단 (SessionStart 에서도 호출)
      local st; st=$(prop_get .status)
      case "$st" in
        "") echo "NONE"; return 0 ;;
        chosen) echo "CHOSEN $(prop_get .card)"; return 0 ;;
        auto) echo "AUTO $(prop_get .card)"; return 0 ;;
      esac
      if [ "$(date +%s)" -lt "$(prop_get .deadline)" ]; then echo "PENDING"; return 0; fi
      local max chain card
      max=$(cfg .max_auto_chain); max=${max:-3}
      chain=$(prop_get .auto_chain); chain=${chain:-0}
      if [ "$chain" -ge "$max" ]; then
        echo "WAIT_USER (자동 진행 연속 ${chain}/${max} — 사용자 확인 필요)"; return 0
      fi
      # 자동 진행은 "만드는 사람" 단독 카드만 — 사용자 눈에 보이는 방향은 사람만 바꾼다
      card=$(grep -oE '^## C[0-9]+ \[만드는 사람\]' "$(prop_get .dir)/CARDS.md" | head -1 | grep -oE 'C[0-9]+' || true)
      if [ -z "$card" ]; then echo "NO_AUTO_CARD"; return 0; fi
      prop_set --arg c "$card" '.status = "auto" | .card = $c | .auto_chain += 1'
      echo "AUTO $card" ;;
    card) # card [C번호] — 카드 본문 출력 (기본: 선택/자동 진행된 카드)
      local c="${1:-$(prop_get .card)}" d; d=$(prop_get .dir)
      [ -n "$c" ] && [ -n "$d" ] || die "출력할 카드가 없습니다."
      awk -v c="$c" '$0 ~ "^## " c " \\[" {p=1; print; next} /^## /{p=0} p' "$d/CARDS.md" ;;
    done) # 선택/자동 카드를 feature 로 넘긴 뒤 제안 종료
      [ -f "$PROP" ] && prop_set '.status = "consumed"'; echo "[harness] 제안 종료" ;;
    status)
      if [ ! -f "$PROP" ]; then echo "제안 없음"; return 0; fi
      local now dl; now=$(date +%s); dl=$(prop_get .deadline)
      echo "proposal: $(prop_get .status)  card: $(prop_get .card)  auto_chain: $(prop_get .auto_chain)/$(cfg .max_auto_chain)"
      echo "dir:      $(prop_get .dir)"
      [ "$(prop_get .status)" = "pending" ] && echo "남은 대기: $(( (dl - now) / 60 ))분"
      true ;;
    *) die "알 수 없는 proposal 명령: $sub" ;;
  esac
}

cmd_start() {
  [ $# -ge 1 ] || die "사용: harness.sh start <slug> [max_continuations]"
  local slug="$1" max="${2:-300}"
  [[ "$slug" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "slug 는 소문자/숫자/하이픈만: $slug"
  [[ "$max" =~ ^[0-9]+$ ]] || die "max_continuations 는 정수여야 합니다: $max"
  [ -f "$H/features/$slug/TREE.md" ] || die "TREE.md 가 없습니다. 계획(Phase A) 을 먼저 완료하십시오."
  if [ -f "$RUN" ] && [ "$(run_get .status)" = "running" ] && [ "$(run_get .feature)" != "$slug" ]; then
    die "다른 feature($(run_get .feature)) 가 running 입니다. /pause 또는 완료 후 시작하십시오."
  fi
  local base
  base=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo "")
  jq -n --arg f "$slug" --arg t "$(now)" --argjson m "$max" --arg b "$base" '{
    feature: $f, status: "running", session_id: "", started_at: $t, updated_at: $t,
    base_commit: $b, continuations: 0, max_continuations: $m, stall_count: 0, last_fingerprint: ""
  }' > "$RUN"
  echo "[harness] run 시작: $slug (max_continuations=$max)"
}

cmd_pause() {
  [ -f "$RUN" ] || die "run.json 이 없습니다."
  run_set --arg t "$(now)" '.status = "paused" | .updated_at = $t'
  echo "[harness] paused: $(run_get .feature)"
}

cmd_resume() {
  [ -f "$RUN" ] || die "run.json 이 없습니다."
  # 세션 소유권을 풀어서 이 명령을 실행한 세션이 다음 Stop 에서 소유권을 가져가게 한다.
  run_set --arg t "$(now)" '.status = "running" | .session_id = "" | .continuations = 0
    | .stall_count = 0 | .last_fingerprint = "" | .updated_at = $t'
  echo "[harness] resumed: $(run_get .feature)"
}

cmd_finish() {
  [ -f "$RUN" ] || die "run.json 이 없습니다."
  local s="${1:-done}"
  case "$s" in done|blocked) ;; *) die "finish 는 done|blocked 만" ;; esac
  run_set --arg s "$s" --arg t "$(now)" '.status = $s | .updated_at = $t'
  echo "[harness] run $s: $(run_get .feature)"
}

cmd_status() {
  if [ ! -f "$RUN" ]; then echo "활성 run 없음"; return 0; fi
  local f s c
  f=$(run_get .feature); s=$(run_get .status)
  echo "feature: $f"
  echo "status:  $s  (continuations $(run_get .continuations)/$(run_get .max_continuations))"
  if [ -f "$H/features/$f/TREE.md" ]; then
    read -r total d g t b <<<"$(cmd_counts)"
    echo "nodes:   done $d / $total  (doing $g, todo $t, blocked $b)"
    echo "next:    $(cmd_next)"
  fi
}

cmd_fingerprint() {
  # 진척 지문 — 트리 상태 + 커밋 + 아직 커밋 안 된 작업(수정 · 새 파일). 서브에이전트가 파일을 고치는 중이면 진척으로 본다.
  local t head
  t=$(tree_file)
  head=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo nogit)
  { cat "$t"; echo "$head"
    git -C "$ROOT" status --porcelain 2>/dev/null
    git -C "$ROOT" diff 2>/dev/null
    git -C "$ROOT" ls-files -z --others --exclude-standard 2>/dev/null \
      | (cd "$ROOT" && xargs -0 -r cksum 2>/dev/null)
  } | cksum | awk '{print $1}'
}

sub="${1:-status}"; shift || true
case "$sub" in
  next) cmd_next ;;
  set) cmd_set "$@" ;;
  counts) cmd_counts ;;
  coverage) cmd_coverage ;;
  start) cmd_start "$@" ;;
  pause) cmd_pause ;;
  resume) cmd_resume ;;
  finish) cmd_finish "$@" ;;
  status) cmd_status ;;
  feature-dir) feature_dir ;;
  fingerprint) cmd_fingerprint ;;
  quality) cmd_quality ;;
  proposal) cmd_proposal "$@" ;;
  -h|--help|help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) die "알 수 없는 명령: $sub (help 참고)" ;;
esac
