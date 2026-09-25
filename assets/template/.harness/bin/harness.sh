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
#   harness.sh fingerprint          진척 지문 (TREE.md + git HEAD) — 정체 감지용
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

cmd_coverage() {
  local fd; fd=$(feature_dir)
  [ -f "$fd/SPEC.md" ] || die "SPEC.md 가 없습니다: $fd/SPEC.md"
  local ids missing=0
  ids=$(grep -owE '(AC|E)-[0-9]+' "$fd/SPEC.md" | sort -u || true)
  for x in $ids; do
    if ! grep -E 'covers:' "$fd/TREE.md" | grep -qE "(^|[^0-9A-Za-z-])$x([^0-9]|$)"; then
      echo "uncovered: $x"; missing=1
    fi
  done
  [ "$missing" -eq 0 ] && echo "coverage ok ($(echo "$ids" | grep -c . || true) ids)"
  return "$missing"
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
  local t head
  t=$(tree_file)
  head=$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || echo nogit)
  { cat "$t"; echo "$head"; } | cksum | awk '{print $1}'
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
  -h|--help|help) sed -n '2,24p' "$0" | sed 's/^# \{0,1\}//' ;;
  *) die "알 수 없는 명령: $sub (help 참고)" ;;
esac
