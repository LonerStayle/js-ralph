# js-ralph

ralph loop 전용 하네스를 찍어내는 **공장(factory)**.
이 저장소는 직접 ralph 루프를 돌리지 않는다. 새 하네스를 스캐폴딩해서 외부 위치로 eject 한다.

---

## 빠른 시작

```bash
# 1) 새 하네스 만들기 — ~/jinsup_ralph/<name>/ 로 복제 + git init 자동
bash scripts/new-harness.sh my-feature
# (Claude Code 세션 안이면 /ralph-new my-feature 도 동일 동작)

# 2) 그 위치로 이동 + 새 Claude 세션 (.claude/ 가 그 디렉터리 기준으로 로드되도록)
cd ~/jinsup_ralph/my-feature
claude

# 3) 도메인 채우기
#    - CLAUDE.md "도메인" 섹션                  ← 무엇/입력/산출물/사이클·프로젝트 종료 조건
#    - .claude/config/verify-checklist.md       ← 도메인 검증 항목
#    - .claude/scripts/{deploy,smoke-test}.sh   ← 첫 사이클이 자기 손으로 채워도 무방

# 4) 자율 루프 시작 (메인 경로) — ralph-tick 을 주기 invoke
/loop 1m /ralph-tick
#   (또는 ralph-loop 플러그인 활성화돼 있으면 /ralph-loop:ralph-loop)
#   (수동으로 한 스텝씩 보고 싶으면 그냥 /ralph-tick 만 반복 호출)

# 5) SPEC 동결 시점에 사람이 한 번 통과시킴
#    agent 가 spec.md 를 작성하면 phase=IMPLEMENT_PENDING_FREEZE 에서 멈춤
#    검토 후 /ralph-spec-done 호출 → IMPLEMENT 로 진입
```

---

## 무엇을 만드는가

각 하네스는 다음을 강제로 갖춘 **자가완결 ralph 작업 환경**:

- **2층 루프** — 외부(시장조사 → 아이디어 → 기획 → 구현 → QA → 회의 → gap → 다음 사이클) + 내부(구현/검증)
- **5역할 페르소나 풀** (PM / Dev / QA / Designer / Marketer × 각 ≥3 페르소나)
- **모든 게이트마다 검증** (`gate-verify` 스킬이 페이즈 전이 직전 실행)
- **자체 git 저장소** — eject 시점에 `git init` + 초기 커밋

자세한 원칙·구조는 `CLAUDE.md` 참조.

---

## 7대 원칙 (요약)

1. 자체 검증 — 모든 게이트와 루프 종료에 LLM 채점 박힘
2. 상황별 프롬프트 — 페이즈별 스킬·슬래시 커맨드 분리
3. 플래너 패턴 — dev/* 플래너 N개 풀
4. Ralph 히스토리 — PostToolUse hook 자동 append
5. 모델 라우팅 — 각 agent `model:` + config/model-routing.md
6. 배포 선세팅 — 첫 그린 라이트 통과 전엔 사이클 진입 차단
7. 페르소나 풀 — 역할당 ≥3 페르소나, council 단계에서 자동 활성

---

## 기본 기술 스택 (factory 디폴트)

새 하네스가 다음 중 하나에 해당되면 자동으로 이 조합으로 진행 (명시적 다른 지시 없는 한):

| 영역 | 스택 |
|------|------|
| Backend | Python + uv + FastAPI + SQLAlchemy |
| Web Frontend | React |
| Mobile App | Android (Kotlin, Android Studio). **iOS / Flutter 포기.** |
| Database | Postgres |

---

## 폴더 구조

```
js-ralph/                                     # 이 저장소 (공장)
  CLAUDE.md                                   # 7원칙 + 게이트 구조 정의 (factory 메타)
  README.md                                   # 이 파일
  template/                                   # 모든 하네스의 원본 (복제 대상)
    CLAUDE.md  README.md  VERSION
    .claude/
      settings.json
      agents/{pm,dev,qa,designer,marketer}/   # 15 페르소나
      skills/                                 # 10 스킬 (gate-verify, phase-*, council, ...)
      commands/                               # 8 슬래시 커맨드
      hooks/    scripts/    state/    config/
  scripts/
    new-harness.sh                            # template/ → ~/jinsup_ralph/<name>/ eject + git init
  .claude/
    commands/
      ralph-new.md                            # /ralph-new <name>
```

Eject 결과:
```
~/jinsup_ralph/<name>/                        # 자체 git 저장소
  .git/  CLAUDE.md  README.md  .claude/...
```

`RALPH_HOME` 환경변수로 destination 변경 가능 (기본 `~/jinsup_ralph`).

---

## 슬래시 커맨드 (각 하네스 안에서)

**메인 경로 (자율 구동)**
```
/loop 1m /ralph-tick        # 메인 — ralph-tick 을 1분마다 반복. 매 tick = 1 step 전진
/ralph-tick                 # 한 번만 1 step 전진 (수동 관찰용)
/ralph-spec-done            # 사람이 SPEC 동결 인가 — 자율 진행이 여기서만 멈춤
/ralph-stop                 # 프로젝트 강제 종료
```

**수동 override (자율 일시정지하고 사람이 끼어들 때)**
```
/ralph-deploy            # 첫 그린 라이트 (smoke deploy)
/ralph-cycle-start       # 새 사이클 수동 시작 → RESEARCH
/ralph-research-done     # RESEARCH → IDEATION
/ralph-ideation-done     # IDEATION → SPEC
/ralph-start             # dev/* 플래너 호출 → 구현
/ralph-done              # QA → review-council → gap-analysis → CHECKLIST → CYCLE_DONE
/ralph-verify            # 수동 체크리스트 단독 실행
```

---

## 원격 저장소 (선택)

eject 후 GitHub 등록이 필요하면:

```bash
cd ~/jinsup_ralph/<name>
gh repo create <name> --private --source=. --remote=origin --push
```

(자동화하지 않음 — 의도치 않은 공개를 방지하기 위해 명시적 명령으로만.)
