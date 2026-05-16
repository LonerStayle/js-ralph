# {{PROJECT_NAME}} — ralph harness (v3-classic)

이 하네스는 js-ralph factory 의 template 에서 eject 되었다.
이 파일은 **자가완결**이다 — 부모 저장소를 참조하지 않는다.

---

## 한 줄

Geoffrey Huntley 의 오리지널 Ralph Wiggum 패턴 (`while :; do cat PROMPT.md | claude ; done` 의 정신)을 Claude Code 의 ralph-loop 플러그인 위에 그대로 얹은 ralph 하네스. 사람 개입 = onboarding 1 회 + PROJECT_DONE 검토 1 회.

---

## 4 파일 (전부)

| 파일 | 무엇 | 누가 만드나 |
|------|------|------------|
| `PROMPT.md` | ralph 의 행동 매뉴얼 (매 iteration 의 입력) | factory 가 박아둠. 대표님은 "표지판" 한 줄만 누적 추가 |
| `specs/*.md` | 무엇을 만들지 (비전 + 사양). 도메인별 다파일 가능 | **대표님** (onboarding 인터뷰로 `specs/vision.md` 자동 합성). 이후 직접 수정 OK |
| `AGENTS.md` | 어떻게 빌드·검증 (명령만, 60줄 이하) | 대표님 또는 첫 ralph iteration 이 채움 |
| `IMPLEMENTATION_PLAN.md` | 현재 TODO 체크리스트 | **ralph 가 99% 작성**. 사람은 빈 파일만 시작 |

> 이 외 어떤 파일도 ralph 의 동작에 본질적이지 않다. v2 의 11 phase / 15 페르소나 / 14 skill / gate-verify framework 는 **의도적으로 제거**됨.

---

## 4 원칙 (Geoffrey 정석)

| # | 원칙 | 이 하네스에서 구현 |
|---|------|--------------------|
| 1 | **단일 prompt + 자기 재투입 루프** | ralph-loop 플러그인의 Stop hook 이 매 iteration 동일 prompt (= 이 디렉토리의 `PROMPT.md`) 를 fresh context 로 재투입 |
| 2 | **사람이 작성한 파일 spec** | `specs/*.md` — LLM 이 환각으로 만들지 않음. onboarding 으로 `vision.md` 합성 후 동결 |
| 3 | **fresh context 매 iteration** | ralph 는 앞 iteration 을 기억하지 못한다. 상태는 git + 위 4 파일에만 존재 |
| 4 | **deterministic backpressure** | `AGENTS.md` 의 검증 명령 (lint/typecheck/tests). LLM 채점 (gate-verify 같은 것) 없음. exit 0 일 때만 commit |

---

## 사용자 동기 — 유일하게 유지된 v2 컨셉

이 하네스의 운전자는 **대표님 (방향 결정자)** 이다.
ralph 는 모든 응답·커밋 메시지·보고를 **"대표님"** 호칭 + **보고체** (경어, 격식) 로 작성한다.

대표님은 두 시점에만 개입한다:
1. **시작**: onboarding 8 질문 답변 → `specs/vision.md` 자동 합성 → "확정" 발화로 동결 (1 회)
2. **끝**: ralph 가 `<promise>PROJECT_DONE</promise>` 를 출력하고 종료하면, 결과물 검토 (1 회)

> v2 의 5 역할 × 3 페르소나 = 15 직원 페르소나 framework 는 **폐기**되었다.
> council / dispatch cap / gap-analysis / gate-verify 같은 phase framework 도 **폐기**되었다.
> 남은 것: 호칭과 톤뿐.

---

## 기본 기술 스택 (factory 디폴트)

명시적 다른 지시 없으면 이 조합으로 진행한다.

| 영역 | 기본 스택 |
|------|-----------|
| Backend | Python + uv + FastAPI + SQLAlchemy |
| Web Frontend | React |
| Mobile App | Android (Kotlin, Android Studio). iOS / Flutter 의도적 포기 |
| Database | Postgres |
| 그 외 (인프라/CI/캐시) | 합리적 기본값 |

---

## 매 iteration 흐름 (PROMPT.md 가 강제)

```
git status → specs/ 읽기 → AGENTS.md 읽기 → IMPLEMENTATION_PLAN.md 읽기
  → 첫 [ ] task 선택 (없으면 specs 기반 plan 보강)
  → 구현
  → AGENTS.md 의 검증 명령 모두 실행
  → PASS 면 commit + [ ]→[x]
  → 종료 (ralph-loop 가 재투입)
```

종료 조건:
- 모든 specs 항목이 plan 에 반영되고 전부 `[x]` → `<promise>PROJECT_DONE</promise>` 출력 후 종료
- `--max-iterations 300` 도달
- 대표님 명시 정지

---

## onboarding (NOT_STARTED 첫 진입)

eject 직후 `claude` 세션을 열면 ralph 가 즉시 대표님께 인사를 드리고 **8 질문 인터뷰**를 진행한다.

| # | 질문 |
|---|------|
| 1 | 비전 — 이 프로젝트 한 줄 비전 |
| 2 | 사용자 — 누가 사용하나 (1~2 문장 페르소나) |
| 3 | 핵심 산출물 — 반드시 만들어야 할 것 1~3가지 |
| 4 | 성공 정의 — 정량 + 정성 |
| 5 | 금지 / 범위 밖 |
| 6 | 외부 의존 — API / 데이터 소스 / 사용자 입력 |
| 7 | 규모·일정·비용 cap |
| 8 | 기술 스택 override — 위 디폴트와 다르게 갈지 (없으면 디폴트) |

응답을 바탕으로 `specs/vision.md` 초안을 합성한다.
대표님이 **"확정" / "OK" / "진행해"** 중 하나로 발화하면 frontmatter `frozen: true` 박고 ralph 가 자율 루프에 진입한다.

> v2 의 `master-spec` / `manifest.md` / `chunks/` / `cycles/` 는 **없다**. `specs/vision.md` 한 파일이 출발. 필요하면 ralph 또는 대표님이 `specs/api.md`, `specs/ui.md`, `specs/data.md` 등을 추가한다.

---

## 신규 시작 체크리스트

- [ ] `claude` 세션 열고 onboarding 인터뷰 완료 → `specs/vision.md` 동결 ("확정" 발화)
- [ ] `AGENTS.md` 의 검증 명령 (`lint` / `typecheck` / `tests`) 도메인 명령으로 채움
- [ ] `AGENTS.md` 의 검증 명령을 로컬에서 직접 1회 돌려서 exit 0 확인
- [ ] ralph-loop 플러그인 활성 (`/loop` 또는 ralph-loop CLI). PROMPT.md 가 입력으로 박혀 있는지 확인
- [ ] 첫 iteration 끝나고 `IMPLEMENTATION_PLAN.md` 에 `[ ]` 가 누적되는지 확인

---

## 표지판 추가 방법

ralph 가 같은 실수 반복 시 `PROMPT.md` 의 `<!-- signs -->` 섹션 아래에 한 줄 추가.
**`specs/` 나 `AGENTS.md` 에는 행동 교정 문구를 박지 마라** — 그건 PROMPT.md 의 일이다.
