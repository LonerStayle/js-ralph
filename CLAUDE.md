# CLAUDE.md — js-ralph (Claude Code 플러그인)

이 저장소(`js-ralph`)는 **Claude Code 플러그인 `js-ralph` 의 개발/배포 저장소** 다. 직접 ralph 실행 환경을 운영하지 않는다.

새 ralph 하네스를 만들려면 Claude Code 에서 `/setup-ralph` 슬래시를 한 번 실행하면 된다 — 플러그인이 동봉한 5파일이 현재 디렉토리에 박히고 vision-intake 비전 인터뷰가 즉시 시작된다.

> 옛 factory 모델 (`template/` 폴더 + `bash scripts/new-harness.sh`) 은 `pre-plugin` 브랜치 (`b8fb626`) 에 통째 보존되어 있다. 필요 시 `git checkout pre-plugin` 으로 fallback 가능.

---

## 핵심 디자인 (v3-classic, 2026-05-17 회귀)

Geoffrey Huntley 의 오리지널 Ralph Wiggum 패턴 + 대표님 호칭 톤.
**js-ralph 내재화 goal 루프 (Stop hook) + CLAUDE.md 자동 로드** 메커니즘 활용.

> v1.2.0 부터 자기 재투입 루프를 js-ralph 플러그인 안에 내재화했다 (`/goal` 커맨드 + `hooks/goal-stop-hook.sh`). 옛 외부 `ralph-loop` 플러그인 의존은 제거됨.

> v3-classic 은 v2 framework (11 phase + 14 skill + 15 페르소나 + gate-verify) 를 의도적으로 폐기한 결과다. 회귀 의사결정 전문은 `HANDOFF.md`.

---

## template 의 5 파일 (Geoffrey 정석 4 + Claude Code 자동 로드 1)

| 파일 | 무엇 | 누가 |
|------|------|------|
| `CLAUDE.md` | 비전 + 환경 컨텍스트 + 호칭 톤 (Claude Code 자동 로드) | vision-intake skill 자동 합성 |
| `PROMPT.md` | ralph 행동 매뉴얼 (도구 중립) | factory 박음 + 표지판 누적 |
| `AGENTS.md` | 빌드/검증 명령 (60줄 이하) | 대표님 또는 ralph 첫 iteration |
| `IMPLEMENTATION_PLAN.md` | TODO 체크리스트 | ralph 99% 자동 |
| `specs/*.md` | (선택) 도메인 추가 사양 — api/ui/data 등 | 대표님 또는 ralph 첫 iteration |

---

## 4 원칙 (Geoffrey 정석)

| # | 원칙 | factory 가 박는 강제 메커니즘 |
|---|------|--------------------------------|
| 1 | 단일 prompt + 자기 재투입 루프 | js-ralph 내재화 goal 루프 Stop hook (`hooks/goal-stop-hook.sh`, `/goal` 으로 시작) |
| 2 | 사람이 작성한 파일 spec | template/CLAUDE.md 의 비전 섹션 (vision-intake skill 합성 후 동결, `onboarded: true`) |
| 3 | fresh context 매 iteration | goal 루프 기본 동작 + CLAUDE.md 자동 로드 |
| 4 | deterministic backpressure | template/AGENTS.md 의 lint/typecheck/tests |

→ LLM 채점 (gate-verify 같은 것) **없음**. 페르소나 framework **없음**.

---

## 사용자 호칭

`template/CLAUDE.md` 가 "사용자 = 대표님" 으로 자동 치환한다. `PROMPT.md` 는 도구 중립이라 "사용자" 라고만 표기.

→ 호칭/톤 변경은 `template/CLAUDE.md` 의 "공통 — 사용자 호칭 / 톤" 섹션에서만 한다. PROMPT.md / AGENTS.md / IMPLEMENTATION_PLAN.md 에 "대표님" 박지 마라 (verify-v3-template.sh 의 [5] 검증).

---

## 기본 기술 스택 (factory 디폴트)

명시적 다른 지시 없으면 이 조합으로 진행한다. eject 후 vision-intake 8번째 질문에서 override 가능.

| 영역 | 기본 |
|------|------|
| Backend | Python + uv + FastAPI + SQLAlchemy |
| Web Frontend | React (Vite + TypeScript) |
| Mobile App | Android (Kotlin, Android Studio). iOS / Flutter 의도적 포기 |
| Database | Postgres |
| 그 외 (인프라/CI/캐시) | 합리적 기본값 |

`template/CLAUDE.md` 의 "공통 — 기본 기술 스택" 섹션에도 같은 표가 박혀 있다 (자가완결).

---

## 저장소 디렉토리 구조 (js-ralph 플러그인)

```
js-ralph/
  .claude-plugin/plugin.json     플러그인 manifest (name=js-ralph)
  commands/
    setup-ralph.md               /setup-ralph 슬래시 entry (하네스 박기)
    goal.md                      /goal — goal 루프(자기 재투입) 시작
    cancel-goal.md               /cancel-goal — 활성 goal 루프 취소
    expand-plan.md               /expand-plan — IMPLEMENTATION_PLAN.md TODO 보강
  hooks/
    hooks.json                   Stop hook 등록 (컨벤션 자동 로드)
    goal-stop-hook.sh            goal 루프 재투입 본체 (.claude/goal-loop.local.md 감지)
  scripts/
    setup-ralph.sh               하네스 박는 본체 bash
    goal-loop.sh                 goal 루프 상태파일 생성 (/goal 이 호출)
    verify-plugin.sh             플러그인 정적 검증
  assets/template/               5파일 + 부속 (현재 디렉토리에 cp 될 원본)
    CLAUDE.md  PROMPT.md  AGENTS.md  IMPLEMENTATION_PLAN.md  README.md
    .claude/settings.json
    .gitignore  VERSION (=3)  specs/.gitkeep
  skills/vision-intake/SKILL.md  비전 인터뷰 8 질문 + FR-7 자동 시작 게이트
  tests/                         bats 단위/통합 테스트
  docs/                          v2 historical + 의사결정 기록 (보존)
  HANDOFF.md                     다음 세션 인수인계
  CLAUDE.md  README.md           이 두 파일 (저장소 메타)
```

옛 `template/` / `scripts/new-harness.sh` / `scripts/verify-v3-template.sh` 는 `pre-plugin` 브랜치에 보존.

---

## ejected 하네스 위치 (사용자가 정함)

`/setup-ralph` 슬래시는 **현재 디렉토리** 에 5파일을 박는다. 옛 모델의 `~/jinsup_ralph/<NAME>/` 강제 위치는 폐기됨 — 어디서든 빈 디렉토리에 가서 `claude` + `/setup-ralph` 한 번이면 됨.

이미 ejected 된 8 하네스 (Nova / TtokTtok / PlanB / shortdub / chuljeun-nyang / king_of_law / ai_news_scraping / autoproducts-feature-dev) 는 자체 git 저장소로 독립. 본 플러그인화 갱신은 신규 하네스에만 적용 — 기존 8 하네스 마이그 안 함.

---

## 작업 시 주의 (factory 유지보수자용)

1. **`template/CLAUDE.md` 는 자가완결** — eject 후 부모 (js-ralph) 참조 불가. 5 파일 디자인 / 4 원칙 / 호칭 변경 시 template/CLAUDE.md 도 같이 갱신.
2. **호칭/톤은 template/CLAUDE.md 에만** — PROMPT/AGENTS/PLAN/specs 는 도구 중립. verify-v3-template.sh 의 [5] 가 강제.
3. **scripts/new-harness.sh 의 eject 안내** 가 template 모델과 일치해야 한다 (실제 동작과 안내 메시지 sync).
4. **template 변경 후 `bash scripts/verify-v3-template.sh`** 로 정적 검증. [PASS] 전엔 commit 금지.
5. **v2 → v3-classic 회귀 의사결정 전문은 `HANDOFF.md`** 에 보존됨. 새 큰 변경 시 HANDOFF.md 도 같이 갱신.
6. **`docs/`** 안의 v2 시절 자료 (PRD, tech-design, v2-rollout-guide 등) 는 historical 로 의도적 보존. 갈아엎지 마라.

---

## 버전업 / 배포 워크플로 (factory 유지보수자용)

> **⚠️ 절대 규칙** — 본 플러그인 코드를 변경하고 버전을 올렸으면, **반드시 대표님께 아래 갱신 시퀀스를 안내해야 한다**. 마켓플레이스 갱신 마찰은 대표님이 모르고 지나가면 새 버전이 ejected 하네스에 안 깔리므로, 안내 누락 = 사실상 배포 실패.

### 1) 한 commit 으로 묶기

버전 올릴 때 다음 두 파일을 **같은 commit** 에 묶는다:
- `.claude-plugin/plugin.json` 의 `version`
- `.claude-plugin/marketplace.json` 의 `plugins[].source.ref` + `plugins[].version`

그 다음 tag → push 순서:

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json <기타 변경 파일>
git commit -m "feat(...): vX.Y.Z — ..."
git tag -a vX.Y.Z -m "..."
git push origin main
git push origin vX.Y.Z
```

→ tag 가 marketplace 갱신까지 포함한 commit 을 가리켜야 ref 와 실제 코드가 sync 된다. (분리 commit + 뒤늦은 tag 는 tag 시점 ref 가 옛날 marketplace.json 을 가리켜 옵셋이 생긴다.)

### 2) push 직후 대표님께 **반드시** 안내 (의무)

push 가 끝나면 대표님께 아래 시퀀스를 **반드시 보고/안내한다. 생략 금지**:

```
대표님께:

vX.Y.Z 배포 완료. 다른 ejected 하네스에서 적용하시려면:

  /plugin marketplace update js-ralph    # 카탈로그 다시 fetch
  /plugin update js-ralph                # 플러그인 코드 갱신
  /reload-plugins                        # 즉시 적용

확인: `/` 메뉴에 새 슬래시가 보이면 성공.
```

### 3) 왜 두 명령 다 필요한가
- `/plugin marketplace update <marketplace-name>` — marketplace.json 캐시 갱신 (어떤 ref 가 최신인지 클라이언트가 인식)
- `/plugin update <plugin-name>` — 그 ref 기준으로 plugin 코드 fetch
- 둘 중 하나만 하면 옛날 카탈로그 또는 옛날 코드가 남아 새 슬래시가 안 잡힌다.

---

## 신규 하네스 생성 시 체크리스트 (factory 운영자)

- [ ] `bash scripts/verify-v3-template.sh` → [PASS]
- [ ] `bash scripts/new-harness.sh <NAME>` → eject 성공
- [ ] eject 안내 메시지가 v3-classic 흐름과 일치하는지 확인
- [ ] (선택) ejected 하네스에서 vision-intake skill 1회 돌려서 sanity 확인
