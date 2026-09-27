---
name: feature-orchestration
description: 하네스 프로젝트(.harness/ 존재)에서 기획 한 건을 계획 → 바텀업 구현 → 마감까지 무인으로 끝까지 진행하는 오케스트레이터 절차. /feature · /resume 에서 호출되고, run.json 이 running 인 세션이 재개·압축된 뒤에도 이 절차로 이어간다.
user-invocable: false
---

# feature-orchestration

너는 오케스트레이터다. **직접 구현하지 않는다** — 계획은 planner, 구현은 builder, 검토는 reviewer, 교훈은 curator
서브에이전트에게 맡기고(플러그인 에이전트라 `js-ralph:planner` 처럼 보일 수 있다), 너는 상태를 전이시키고 결과를 확인한다.
이렇게 해야 네 컨텍스트가 작게 유지되어 수 시간짜리 실행을 버틴다.

**서브에이전트는 포그라운드로 호출한다** (Agent 도구의 `run_in_background: false`). 결과가 올 때까지 턴을 끝내지 않는다.
백그라운드로 띄우고 턴을 끝내면 Stop 가드가 "진척 없음" 으로 세어 실행을 멈춘다. 서로 독립인 호출(병렬 builder 등)은 한 메시지에 여러 개를 포그라운드로 넣는다.

**가드가 멈춘 실행(blocked · paused)을 스스로 재개하지 않는다.** `harness.sh resume` 은 사용자가 `/resume` 을 실행했을 때만 쓴다.
멈췄으면 이유를 짧게 보고하고 턴을 끝낸다.

**상태의 단일 출처는 파일이다**: `SPEC.md` · `TREE.md` · `.harness/run.json` · git 로그.
기억에 의존하지 말고, 헷갈리면 `bash .harness/bin/harness.sh status` 를 본다.
노드/실행 상태는 반드시 `harness.sh` 로만 바꾼다 (run.json 직접 수정은 hook 이 막는다).

---

## Phase A — 계획 (기획이 새로 들어왔을 때만)

1. **slug 결정**: 기획을 요약한 영문 kebab-case (`email-verification`). `.harness/features/<slug>/` 가 이미 있으면 뒤에 `-2` 등.
2. `mkdir -p .harness/features/<slug>` 후 **planner** 호출 — 기획 원문 전체, 디렉토리 경로, **크기**(카드의 `크기:` — 없으면 planner 가 추정)를 넘긴다.
3. **reviewer (mode: plan)** 호출. **high 발견만** planner 에게 넘겨 반영한다. **1 라운드**로 끝낸다 (계획 검토가 계획을 부풀리지 않게).
4. 게이트 — 둘 다 통과해야 착수 (coverage 는 SPEC 의 AC-/E- 에 더해, **아직 검증 스크립트가 없는 측정형 품질 기준 Q-** 도 노드 매핑을 요구한다):
   ```bash
   HARNESS_FEATURE=<slug> bash .harness/bin/harness.sh coverage   # uncovered 0
   HARNESS_FEATURE=<slug> bash .harness/bin/harness.sh next        # READY … 이어야 함
   ```
5. 커밋: `git add .harness/features/<slug> && git commit -m "plan(<slug>): SPEC + TREE (<노드 수> nodes)"`
6. 실행 시작: `bash .harness/bin/harness.sh start <slug>` — 이 순간부터 Stop hook 이 중간 종료를 막는다.
7. 사용자에게 계획 요약을 짧게 보고한다 (노드 수, 핵심 사이드이펙트, 내린 가정). **승인을 기다리지 않고** Phase B 로 간다.

---

## Phase B — 바텀업 구현 루프

반복한다:

```bash
bash .harness/bin/harness.sh next
```

- `READY <id> …` → 아래 **노드 처리**
- `DONE` → Phase C
- `BLOCKED` / `STUCK` → Phase C 의 부분 마감 (차단 사유 보고)

### 노드 처리

1. `bash .harness/bin/harness.sh set <id> doing`
2. **builder** 호출 — 노드 ID, feature 경로, (재시도면) 직전 실패 요약.
3. builder 보고를 믿지 말고 **직접 검증한다**: `bash .harness/verify.sh` 가 exit 0 인지, `git log -1` 에 노드 커밋이 있는지 확인.
4. **reviewer (mode: node)** 호출 — 노드 ID 와 커밋 범위. 발견 처리:
   - high → 같은 노드를 builder 로 다시 돌려 고친다 (재시도 1회로 셈).
   - medium → 이 feature 의 AC/E 와 직접 관련 있을 때만 SPEC.md 에 새 `E-` 로 추가하고 이 노드의 부모 아래 **새 노드**로 매핑한다.
     관련 없으면 REPORT 의 `후속 후보` 로 보낸다. 트리 전체 노드 수가 **계획 시점의 1.5배**를 넘으면 더 키우지 않고 후속 후보로 보낸다.
   - low → REPORT 후보로만 적어둔다.
   - `[판단]` 품질 기준(Q-) 위반은 심각도와 무관하게 **high 로 취급**한다 — 품질 기준은 모든 노드가 지킨다.
5. 검증 PASS + high 발견 없음 → `bash .harness/bin/harness.sh set <id> done`
6. 실패 처리 (builder FAIL 또는 high 재시도 후에도 실패):
   - 이 노드의 누적 시도가 **3회 미만** → 실패 요약을 붙여 builder 재호출.
   - **3회 도달** → planner 를 재계획 모드로 호출해 노드를 더 작은 자식으로 쪼갠다 (노드는 `todo` 로 되돌림). 노드당 재계획은 1번.
   - 재계획 후에도 실패 → `harness.sh set <id> blocked` 하고 TREE.md 의 해당 줄 아래에 `> 차단 사유: …` 를 적는다. 다른 독립 노드로 계속.
7. **curator** 호출 조건: 재시도가 있었던 노드, reviewer high 발견이 나온 노드, builder 가 `learned:` 를 보고한 노드. 그 외에는 부르지 않는다 (비용 절약).

### 병렬화 (선택)

`next` 가 주는 노드와 **같은 부모의 다른 READY 형제**가 있고 `files:` 가 전혀 겹치지 않으면, builder 를
`isolation: worktree` 로 최대 3개 동시에 돌려도 된다. 끝나면 하나씩 현재 브랜치로 merge 하고 매 merge 뒤 verify.sh 를 돌린다.
충돌이 나면 병렬을 멈추고 순차로 돌아간다. 확신이 없으면 순차로 한다.

### 되돌릴 수 없는 작업

데이터 삭제 · 운영 DB 마이그레이션 실행 · 결제 · 외부로 실제 발송 · 권한/보안 정책 완화 · `git push` 는
실행하지 않는다. 해당 노드는 코드와 테스트까지만 만들고 실제 실행 단계는 `blocked` 로 남겨 사용자 판단을 받는다.

---

## Phase C — 마감

1. `bash .harness/verify.sh` 전체 PASS 확인.
2. **reviewer (mode: feature)** — `run.json` 의 `base_commit` 부터 HEAD 까지. SPEC 의 SE- 목록이 전부 대응됐는지 대조.
   high 발견이 있으면 새 노드로 트리에 추가하고 Phase B 로 돌아간다 (Stop hook 이 계속 진행시킨다).
3. **curator (feature-close)** — 이번 feature 전체 회고.
4. `REPORT.md` 작성 (feature 디렉토리):
   ```markdown
   # REPORT — <feature>
   ## 결과        완료 노드 N/M, 커밋 범위, 검증 결과
   ## 수용 기준     AC 별 충족 여부와 증거(테스트 이름)
   ## 품질 기준     Q 별 — [측정] 스크립트 결과 / [판단] 리뷰 점검 결과
   ## 사이드이펙트   SE 별 대응과 검증
   ## 내린 가정     A- 목록 — 사용자가 뒤집고 싶을 수 있는 것
   ## 차단 / 남은 일  blocked 노드와 필요한 결정
   ## 자가 개선     추가된 교훈 · 스킬
   ```
5. 커밋 후 `bash .harness/bin/harness.sh finish done` (차단이 남았으면 `finish blocked`).
6. 사용자에게 보고 — CLAUDE.md 의 호칭/톤 규칙을 따른다. 3~5줄 + REPORT.md 경로.
7. `finish done` 이었으면 **`next-proposals` 스킬로 이어서** 다음 기능 후보를 제안한다 (프로젝트에는 마감이 없다).
   `finish blocked` 이면 제안하지 않고 차단 해소를 기다린다.

---

## 컨텍스트 관리 (롱러닝)

- 서브에이전트 결과는 요약만 받는다. 큰 파일을 오케스트레이터 컨텍스트로 읽지 않는다.
- 압축이 일어나면 SessionStart hook 이 현재 상태를 다시 넣어 준다. 그때는 `harness.sh status` 부터 확인하고 이어간다.
- Stop hook 이 "다음 노드" 를 알려주며 계속시키면, 그 노드부터 노드 처리를 재개한다.
- 사용자가 중간에 질문하면 짧게 답하고 루프로 돌아간다. 멈추길 원하면 `/pause` 를 안내한다.
