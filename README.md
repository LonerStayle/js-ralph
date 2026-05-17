# js-ralph

ralph 하네스 공장 (v3-classic). 새 하네스를 template 에서 외부 디렉토리로 eject 한다.
이 저장소는 직접 ralph 루프를 돌리지 않는다.

> v3-classic = Geoffrey Huntley 의 오리지널 Ralph Wiggum 패턴 + Claude Code 의 CLAUDE.md 자동 로드 활용 + 대표님 호칭 톤.
> v2 framework 폐기 의사결정 전문: `HANDOFF.md`.

---

## 빠른 시작

### 1) 새 하네스 만들기

```bash
bash scripts/new-harness.sh <NAME>
```

→ `~/jinsup_ralph/<NAME>/` 로 ejected. 자체 git 저장소 (`main` 브랜치 + 초기 commit) 자동 생성.

`RALPH_HOME` 환경변수로 위치 변경 가능 (기본 `$HOME/jinsup_ralph`).

### 2) (1회 설치) ralph-loop 플러그인

```
# Claude Code 안에서 한 번:
/plugin install ralph-loop
```

### 3) ejected 하네스에서 onboarding 시작

```bash
cd ~/jinsup_ralph/<NAME>
claude
```

→ Claude Code 가 `CLAUDE.md` 를 자동 로드, `onboarded: false` 를 감지 → ralph 가 자동으로 8 질문 onboarding 인터뷰 시작.

답변 후 `CLAUDE.md` 의 "비전 / 사양" 8 항목이 자동 합성됨.
대표님이 **"확정"** 발화하면 `onboarded: true` + 타임스탬프 박힘.

### 4) AGENTS.md 검증 명령 채우고 ralph-loop 시작

```
/ralph-loop "Read PROMPT.md and follow it." --completion-promise "<promise>PROJECT_DONE</promise>" --max-iterations 300
```

자세한 흐름은 ejected 하네스의 `README.md` 참조.

---

## template 의 5 파일 (Geoffrey 정석 4 + Claude Code 자동 로드 1)

| 파일 | 무엇 |
|------|------|
| `CLAUDE.md` | 비전 + 환경 컨텍스트 + 호칭 톤 (Claude Code 자동 로드) |
| `PROMPT.md` | ralph 행동 매뉴얼 (도구 중립) |
| `AGENTS.md` | 빌드/검증 명령 (60줄 이하) |
| `IMPLEMENTATION_PLAN.md` | TODO 체크리스트 (ralph 자동) |
| `specs/*.md` | (선택) 도메인 추가 사양 — api/ui/data 등 |

→ v2 의 11 phase / 14 skill / 15 페르소나 / gate-verify framework 는 의도적으로 폐기됨.

---

## 4 원칙 (Geoffrey 정석)

| # | 원칙 | 구현 |
|---|------|------|
| 1 | 단일 prompt + 자기 재투입 루프 | ralph-loop 플러그인 Stop hook |
| 2 | 사람이 작성한 파일 spec | template/CLAUDE.md 비전 섹션 (onboarding 합성 + 동결) |
| 3 | fresh context 매 iteration | ralph-loop 기본 + CLAUDE.md 자동 로드 |
| 4 | deterministic backpressure | template/AGENTS.md lint/typecheck/tests |

---

## 기본 기술 스택 (factory 디폴트)

| 영역 | 기본 |
|------|------|
| Backend | Python + uv + FastAPI + SQLAlchemy |
| Web Frontend | React (Vite + TypeScript) |
| Mobile App | Android (Kotlin) — iOS / Flutter 의도적 포기 |
| Database | Postgres |

대표님이 onboarding 8번째 질문에서 override 가능.

---

## 사람 개입 횟수 (각 ejected 하네스마다)

| 시점 | 내용 | 횟수 |
|------|------|------|
| (1회) plugin 설치 | `/plugin install ralph-loop` | 1 |
| onboarding | 8 질문 답변 | ~8 |
| 동결 | "확정" 발화 → `onboarded: true` | 1 |
| AGENTS.md 채우기 | 대표님 또는 ralph 첫 iteration | 0~1 |
| 표지판 추가 | ralph 가 실수 반복 시 PROMPT.md `<!-- signs -->` 아래 | 0~N |
| PROJECT_DONE 검토 | 결과물 확인 | 1 |

---

## factory 디렉토리 구조

```
js-ralph/
├── CLAUDE.md              factory 메타 (유지보수자용)
├── README.md              이 파일
├── HANDOFF.md             다음 세션 인수인계 + 의사결정 기록
├── template/              모든 하네스의 원본
│   ├── CLAUDE.md  PROMPT.md  AGENTS.md  IMPLEMENTATION_PLAN.md
│   ├── specs/.gitkeep
│   ├── .claude/settings.json
│   ├── .claude/skills/onboarding/SKILL.md
│   └── VERSION            (3)
├── scripts/
│   ├── new-harness.sh             template → ejected 하네스 복제
│   └── verify-v3-template.sh      template 정적 검증
└── docs/                  v2 historical 자료 (보존)
```

ejected 하네스 위치: `~/jinsup_ralph/<NAME>/` (자체 git 저장소)

---

## factory 유지보수

template 변경 후:

```bash
bash scripts/verify-v3-template.sh
```

→ [PASS] 확인 후 commit.

자세한 작업 시 주의사항은 `CLAUDE.md`.

---

## 원격 저장소 (선택, ejected 하네스마다)

```bash
cd ~/jinsup_ralph/<NAME>
gh repo create <NAME> --private --source=. --remote=origin --push
```
