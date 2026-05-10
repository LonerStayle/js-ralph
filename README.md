# js-ralph

ralph loop 전용 하네스를 찍어내는 **공장(factory)**.
이 저장소는 직접 ralph 루프를 돌리지 않는다. 새 하네스를 스캐폴딩해서 외부 위치로 eject 한다.

---

## 사전 준비

이 하네스는 [`ralph-loop` 플러그인](https://github.com/anthropics/claude-plugins-official) 위에서 동작합니다. Claude Code 에서 미리 활성화되어 있어야 합니다.

```bash
# 활성화 확인 — 출력에 'ralph-loop' 가 보이면 OK
ls ~/.claude/plugins/cache/claude-plugins-official/ralph-loop/ 2>/dev/null
```

---

## 빠른 시작

### 1단계 — 새 하네스 만들기

```bash
# template/ 을 ~/jinsup_ralph/<name>/ 로 복제 + git init 자동 + 초기 커밋
bash scripts/new-harness.sh my-project
```

(Claude Code 세션 안이면 `/ralph-new my-project` 도 동일 동작)

### 2단계 — 그 위치로 이동, 새 Claude 세션 시작

```bash
cd ~/jinsup_ralph/my-project
claude    # 새 세션 — .claude/ 가 이 디렉터리 기준으로 로드됨
```

ralph 가 즉시 대표님께 인사를 드립니다: **"대표님 안녕하십니까. 이 프로젝트의 비전과 지시사항을 주십시오."**

### 3단계 — onboarding 자동 진행 (이게 사람이 하는 거의 전부)

ralph 가 8가지 질문을 드립니다. 답변해 주시면 `master-spec.md` 를 자동으로 합성합니다.

| 질문 | 내용 |
|------|------|
| 1. 비전 | 이 프로젝트 한 줄 비전 |
| 2. 사용자 | 누가 사용? (1-2 문장 페르소나) |
| 3. 핵심 산출물 | 반드시 만들어야 하는 것 1-3가지 |
| 4. 성공 정의 | "성공"의 정의 (정량 + 정성) |
| 5. 금지 / 범위 밖 | 절대 만들지 말 것 |
| 6. 외부 의존 | 필요한 외부 API / 데이터 소스 |
| 7. 규모 / 일정 / 비용 cap | cycles ≤ N |
| 8. Telegram chat_id | 진척 보고를 받을 채널 ID |

초안 확인 후 **"확정"** 이라고 발화하시면 master-spec 이 동결됩니다.

### 4단계 — 자율 루프 시작 (한 단어)

```
/ralph-run
```

이후 ralph 가 100% 자율로 진행합니다:
1. INTAKE: master-spec → chunk N개 자동 분해 → manifest.md 생성
2. 각 chunk 에 대해 사이클 자동 진행: CHUNK_DETAIL → SPEC → IMPLEMENT → QA → COUNCIL → GAP → CHECKLIST → CYCLE_DONE
3. CYCLE_DONE 마다 Telegram 으로 진척 보고 (비기술 언어, 대표님 톤)
4. 모든 chunk 완료 시 PROJECT_DONE → Telegram 완료 보고

### 5단계 — PROJECT_DONE 검토 (대표님의 마지막 1회)

Telegram 완료 보고를 받으신 후, 직접 결과물을 확인하시고 사인하시면 됩니다.

```bash
docker compose up    # 또는 도메인별 실행 명령
```

BLOCKED 된 chunk 가 있다면 Telegram 보고서에 포함되어 있습니다. 필요 시 master-spec 을 갱신하고 `/ralph-respec` 으로 재시작하실 수 있습니다.

---

## 사람 개입 횟수

| 시점 | 내용 | 횟수 |
|------|------|------|
| onboarding 인터뷰 | 8 질문 답변 | ~8회 |
| master-spec 동결 | "확정" 발화 | 1회 |
| STUCK 응답 (선택) | Telegram reply | 0~N회 (응답 안 해도 ralph 진행) |
| PROJECT_DONE 검토 | 결과물 확인 + 사인 | 1회 |
| **총** | | **최소 10회** |

---

## 무엇을 만드는가

각 하네스는 다음을 강제로 갖춘 **자가완결 ralph 작업 환경**:

- **외부 master-spec** — 대표님의 비전이 source-of-truth. 모든 chunk 가 여기서 도출됨
- **LLM 자동 chunk 분해** — prose 비전 → 1 cycle 분량 chunk N개 자동 생성
- **5역할 페르소나 풀 (직원)** — PM / Dev / QA / Designer / Marketer × 각 ≥3 페르소나
- **모든 게이트마다 검증** — `gate-verify` 스킬이 페이즈 전이 직전 실행, runtime-evidence 필수
- **Telegram 알림** — CYCLE_DONE / STUCK / PROJECT_DONE 3 시점에 대표님 톤 보고
- **자체 git 저장소** — eject 시점에 `git init` + 초기 커밋

자세한 원칙·구조는 `CLAUDE.md` 참조.

---

## 6대 원칙 (요약)

1. 자체 검증 — 모든 게이트와 루프 종료에 LLM 채점 박힘, runtime-evidence 필수
2. 상황별 프롬프트 — 페이즈별 스킬·슬래시 커맨드 분리
3. Ralph 히스토리 — PostToolUse hook 자동 append
4. 모델 라우팅 — 각 agent `model:` + config/model-routing.md
5. 배포 선세팅 — 첫 그린 라이트 통과 전엔 사이클 진입 차단
6. 페르소나 풀 (직원) — 역할당 ≥3 페르소나, 대표님 호칭 + 보고체 톤

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
  CLAUDE.md                                   # 6원칙 + 게이트 구조 정의 (factory 메타)
  README.md                                   # 이 파일
  template/                                   # 모든 하네스의 원본 (복제 대상)
    CLAUDE.md  README.md  VERSION
    .claude/
      settings.json
      agents/{pm,dev,qa,designer,marketer}/   # 15 페르소나 (대표님 호칭 + 보고체 톤)
      skills/                                 # 14 스킬
        onboarding/ phase-intake/ chunk-detail/ notify-sender/  # 신규 4개
        gate-verify/ phase-spec/ phase-implement/ review-council/
        gap-analysis/ project-stop-check/ ralph-tick/
        verify-loop-output/ phase-qa-review/ phase-debug/
      commands/                               # 8 슬래시 커맨드 (+ deprecated 4개 stub)
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
  .claude/state/intake/master-spec.md         # 대표님이 채울 비전 문서
```

`RALPH_HOME` 환경변수로 destination 변경 가능 (기본 `~/jinsup_ralph`).

---

## 슬래시 커맨드 (각 하네스 안에서)

**메인 경로 (자율 구동)**
```
/ralph-run               # 메인 — 자율 루프 시작 (onboarding 자동 진입 → INTAKE → 사이클)
/ralph-tick              # 한 번만 1 step 전진 (수동 관찰용)
/ralph-respec            # master-spec 갱신 후 INTAKE 재실행 (BLOCKED chunk 해제용)
/ralph-stop              # 프로젝트 강제 종료
```

**수동 override (자율 일시정지하고 사람이 끼어들 때)**
```
/ralph-deploy            # 첫 그린 라이트 (smoke deploy)
/ralph-start             # dev/* 페르소나 → 구현
/ralph-done              # QA → review-council → gap-analysis → CHECKLIST → CYCLE_DONE
/ralph-verify            # 수동 체크리스트 단독 실행
```

**[deprecated] 폐기된 v1 커맨드 — 호출 시 안내만 출력**
```
/ralph-research-done / /ralph-ideation-done / /ralph-spec-done / /ralph-cycle-start
```

---

## Telegram chat_id 발급

Telegram 진척 보고를 받으려면 chat_id 가 필요합니다.

1. `telegram:access` 스킬로 Telegram MCP 채널 설정 (`/telegram:configure`)
2. Telegram 에서 봇에게 메시지를 보내 채널 연결
3. onboarding 8번째 질문에서 chat_id 를 답변하시면 ralph 가 자동으로 `notify.md` 에 기록

chat_id 없이 진행해도 ralph 는 동작합니다. 알림은 `.claude/state/notifications.log` 에 fallback 기록됩니다.

---

## 원격 저장소 (선택)

eject 후 GitHub 등록이 필요하면:

```bash
cd ~/jinsup_ralph/<name>
gh repo create <name> --private --source=. --remote=origin --push
```

(자동화하지 않음 — 의도치 않은 공개를 방지하기 위해 명시적 명령으로만.)
