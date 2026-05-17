# CLAUDE.md — js-ralph factory

이 프로젝트(`js-ralph`)는 **ralph 하네스 공장**이다. 직접 ralph 실행 환경을 운영하지 않고 template + eject 스크립트만 보유한다.

새 하네스는 `template/` 을 복제하여 외부 디렉토리 `${RALPH_HOME:-$HOME/jinsup_ralph}/<name>/` 로 eject 된다. eject 된 순간 자체 git 저장소 (`git init -b main` 자동, 초기 commit 자동).

→ factory 안에는 실제 하네스 인스턴스가 살지 않는다. `harness-ralph/` 폴더는 **사용하지 않는다** (의도적으로 비어 있음).

---

## 핵심 디자인 (v3-classic, 2026-05-17 회귀)

Geoffrey Huntley 의 오리지널 Ralph Wiggum 패턴 + 대표님 호칭 톤.
**Claude Code 의 ralph-loop 플러그인 + CLAUDE.md 자동 로드** 메커니즘 활용.

> v3-classic 은 v2 framework (11 phase + 14 skill + 15 페르소나 + gate-verify) 를 의도적으로 폐기한 결과다. 회귀 의사결정 전문은 `HANDOFF.md`.

---

## template 의 5 파일 (Geoffrey 정석 4 + Claude Code 자동 로드 1)

| 파일 | 무엇 | 누가 |
|------|------|------|
| `CLAUDE.md` | 비전 + 환경 컨텍스트 + 호칭 톤 (Claude Code 자동 로드) | onboarding 자동 합성 |
| `PROMPT.md` | ralph 행동 매뉴얼 (도구 중립) | factory 박음 + 표지판 누적 |
| `AGENTS.md` | 빌드/검증 명령 (60줄 이하) | 대표님 또는 ralph 첫 iteration |
| `IMPLEMENTATION_PLAN.md` | TODO 체크리스트 | ralph 99% 자동 |
| `specs/*.md` | (선택) 도메인 추가 사양 — api/ui/data 등 | 대표님 또는 ralph 첫 iteration |

---

## 4 원칙 (Geoffrey 정석)

| # | 원칙 | factory 가 박는 강제 메커니즘 |
|---|------|--------------------------------|
| 1 | 단일 prompt + 자기 재투입 루프 | ralph-loop 플러그인 Stop hook (사용자 설치) |
| 2 | 사람이 작성한 파일 spec | template/CLAUDE.md 의 비전 섹션 (onboarding 합성 후 동결, `onboarded: true`) |
| 3 | fresh context 매 iteration | ralph-loop 기본 동작 + CLAUDE.md 자동 로드 |
| 4 | deterministic backpressure | template/AGENTS.md 의 lint/typecheck/tests |

→ LLM 채점 (gate-verify 같은 것) **없음**. 페르소나 framework **없음**.

---

## 사용자 호칭

`template/CLAUDE.md` 가 "사용자 = 대표님" 으로 자동 치환한다. `PROMPT.md` 는 도구 중립이라 "사용자" 라고만 표기.

→ 호칭/톤 변경은 `template/CLAUDE.md` 의 "공통 — 사용자 호칭 / 톤" 섹션에서만 한다. PROMPT.md / AGENTS.md / IMPLEMENTATION_PLAN.md 에 "대표님" 박지 마라 (verify-v3-template.sh 의 [5] 검증).

---

## 기본 기술 스택 (factory 디폴트)

명시적 다른 지시 없으면 이 조합으로 진행한다. eject 후 onboarding 8번째 질문에서 override 가능.

| 영역 | 기본 |
|------|------|
| Backend | Python + uv + FastAPI + SQLAlchemy |
| Web Frontend | React (Vite + TypeScript) |
| Mobile App | Android (Kotlin, Android Studio). iOS / Flutter 의도적 포기 |
| Database | Postgres |
| 그 외 (인프라/CI/캐시) | 합리적 기본값 |

`template/CLAUDE.md` 의 "공통 — 기본 기술 스택" 섹션에도 같은 표가 박혀 있다 (자가완결).

---

## factory 디렉토리 구조

```
js-ralph/
  CLAUDE.md                      이 파일 (factory 메타)
  README.md                      사람용 사용 가이드
  HANDOFF.md                     다음 세션 인수인계 (의사결정 기록)
  template/                      모든 하네스의 원본 (v3-classic)
    CLAUDE.md  PROMPT.md  AGENTS.md  IMPLEMENTATION_PLAN.md
    specs/.gitkeep
    .claude/
      settings.json
      skills/onboarding/SKILL.md
    VERSION                      (현재 3)
  scripts/
    new-harness.sh               template → ejected 하네스 복제 + git init
    verify-v3-template.sh        template 정적 검증
  docs/                          v2 historical + 의사결정 기록 (보존)
  harness-ralph/                 사용 안 함 (비어 있음, vestigial)
```

---

## eject 결과 위치 (실제 하네스가 사는 곳)

```
~/jinsup_ralph/<project>/        RALPH_HOME 환경변수로 변경 가능
  .git/                          자체 git 저장소 (main 브랜치, 초기 commit)
  CLAUDE.md  PROMPT.md  AGENTS.md  IMPLEMENTATION_PLAN.md
  specs/  .claude/  README.md  VERSION
```

→ ejected 하네스는 독립. factory 갱신은 차후 eject 부터 적용. 이미 ejected 된 하네스 동기화는 사용자가 직접 (template diff 보고 반영).

---

## 작업 시 주의 (factory 유지보수자용)

1. **`template/CLAUDE.md` 는 자가완결** — eject 후 부모 (js-ralph) 참조 불가. 5 파일 디자인 / 4 원칙 / 호칭 변경 시 template/CLAUDE.md 도 같이 갱신.
2. **호칭/톤은 template/CLAUDE.md 에만** — PROMPT/AGENTS/PLAN/specs 는 도구 중립. verify-v3-template.sh 의 [5] 가 강제.
3. **scripts/new-harness.sh 의 eject 안내** 가 template 모델과 일치해야 한다 (실제 동작과 안내 메시지 sync).
4. **template 변경 후 `bash scripts/verify-v3-template.sh`** 로 정적 검증. [PASS] 전엔 commit 금지.
5. **v2 → v3-classic 회귀 의사결정 전문은 `HANDOFF.md`** 에 보존됨. 새 큰 변경 시 HANDOFF.md 도 같이 갱신.
6. **`docs/`** 안의 v2 시절 자료 (PRD, tech-design, v2-rollout-guide 등) 는 historical 로 의도적 보존. 갈아엎지 마라.

---

## 신규 하네스 생성 시 체크리스트 (factory 운영자)

- [ ] `bash scripts/verify-v3-template.sh` → [PASS]
- [ ] `bash scripts/new-harness.sh <NAME>` → eject 성공
- [ ] eject 안내 메시지가 v3-classic 흐름과 일치하는지 확인
- [ ] (선택) ejected 하네스에서 onboarding 1회 돌려서 sanity 확인
