# js-ralph

**Claude Code 플러그인** — `/setup-ralph` 슬래시 한 번에 v3-classic ralph 하네스를 현재 디렉토리에 박고 vision-intake 비전 인터뷰를 즉시 시작합니다.

> v3-classic = Geoffrey Huntley 의 오리지널 Ralph Wiggum 패턴 + Claude Code 의 CLAUDE.md 자동 로드 활용 + 대표님 호칭 톤.
> 옛 factory 모델 (`template/` + `bash scripts/new-harness.sh`) 은 `pre-plugin` 브랜치에 통째 보존됨. 필요 시 `git checkout pre-plugin`.

---

## 빠른 시작

### 1) (1회) 플러그인 설치

```
# Claude Code 안에서 한 번:
/plugin install js-ralph
```

> goal 루프(`/goal` + 자기 재투입 Stop hook)는 js-ralph 에 내재화돼 있어 별도 `ralph-loop` 플러그인 설치가 필요 없습니다 (v1.2.0+).

### 2) 새 ralph 프로젝트 시작

```bash
mkdir ~/my-new-project && cd ~/my-new-project
claude
```

### 3) Claude Code 안에서

```
/setup-ralph
```

→ 5파일 (CLAUDE.md / PROMPT.md / AGENTS.md / IMPLEMENTATION_PLAN.md / README.md) + 부속 파일이 박히고, vision-intake 비전 인터뷰 (8 질문) 가 즉시 시작됩니다.

대표님 답변 → "확정" 발화 → `onboarded: true` 동결 → FR-7 자동 시작 게이트 ("goal 루프 자동 시작?" yes/no) → yes 면 goal 루프 즉시 활성.

### 옵션: 기존 코드 위에 overlay 모드

```
/setup-ralph --overlay         # 기존 5파일 충돌은 .v2.bak 으로 백업
/setup-ralph --overlay --force # onboarded:true CLAUDE.md 도 덮어쓰기 (위험)
```

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
| 1 | 단일 prompt + 자기 재투입 루프 | js-ralph 의 goal 루프 Stop hook (`/goal` 으로 시작) |
| 2 | 사람이 작성한 파일 spec | template/CLAUDE.md 비전 섹션 (vision-intake skill 합성 + 동결) |
| 3 | fresh context 매 iteration | goal 루프 기본 + CLAUDE.md 자동 로드 |
| 4 | deterministic backpressure | template/AGENTS.md lint/typecheck/tests |

---

## 기본 기술 스택 (factory 디폴트)

| 영역 | 기본 |
|------|------|
| Backend | Python + uv + FastAPI + SQLAlchemy |
| Web Frontend | React (Vite + TypeScript) |
| Mobile App | Android (Kotlin) — iOS / Flutter 의도적 포기 |
| Database | Postgres |

대표님이 vision-intake 8번째 질문에서 override 가능.

---

## 사람 개입 횟수 (각 ejected 하네스마다)

| 시점 | 내용 | 횟수 |
|------|------|------|
| (1회) plugin 설치 | `/plugin install js-ralph` | 1 |
| vision-intake (비전 인터뷰) | 8 질문 답변 | ~8 |
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
│   ├── .claude/skills/vision-intake/SKILL.md   (built-in onboarding 충돌 회피)
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
