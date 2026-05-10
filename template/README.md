# {{PROJECT_NAME}}

ralph 하네스. js-ralph factory 에서 eject 됨. 6원칙을 따른다.

---

## 빠른 시작

### 1단계 — 새 Claude 세션 시작

```bash
cd ~/jinsup_ralph/{{PROJECT_NAME}}
claude    # 새 세션
```

ralph 가 즉시 인사를 드립니다:
**"대표님 안녕하십니까. 이 프로젝트의 비전과 지시사항을 주십시오."**

### 2단계 — onboarding 8 질문 답변 (이게 사람이 하는 거의 전부)

| 질문 | 내용 |
|------|------|
| 1. 비전 | 이 프로젝트 한 줄 비전 |
| 2. 사용자 | 누가 사용? (1-2 문장 페르소나) |
| 3. 핵심 산출물 | 반드시 만들어야 하는 것 1-3가지 |
| 4. 성공 정의 | "성공"의 정의 (정량 + 정성) |
| 5. 금지 / 범위 밖 | 절대 만들지 말 것 |
| 6. 외부 의존 | 필요한 외부 API / 데이터 소스 |
| 7. 규모 / 일정 / 비용 cap | cycles ≤ N |
| 8. **Telegram chat_id** | 진척 보고를 받을 채널 ID (아래 "chat_id 발급" 참조) |

답변 후 ralph 가 `.claude/state/intake/master-spec.md` 를 합성합니다.
초안 검토 후 **"확정"** 이라고 발화하시면 동결됩니다.

### 3단계 — 첫 그린 라이트 (`/ralph-deploy`)

```
/ralph-deploy
```

이 단계가 통과해야 사이클 진입이 풀립니다 (원칙 5: 배포 선세팅).
도메인 `deploy.sh` / `smoke-test.sh` 가 1회 동작 + `state/ralph-history.md` 에 `[deploy] PASS` 기록.

### 4단계 — 자율 루프 시작

```
/ralph-run
```

이후 ralph 가 100% 자율로 진행합니다:
- INTAKE → chunk 분해 → 사이클 반복 (CHUNK_DETAIL → SPEC → IMPLEMENT → QA → ... → CYCLE_DONE)
- CYCLE_DONE 마다 Telegram 진척 보고
- 모든 chunk 완료 시 PROJECT_DONE → Telegram 완료 보고

### 5단계 — PROJECT_DONE 검토 (마지막 1회)

Telegram 완료 보고를 받으신 후 결과물을 직접 확인하시면 됩니다.

---

## Telegram chat_id 발급

Telegram 진척 보고를 받으려면 chat_id 가 필요합니다.

1. Claude Code 에서 `/telegram:configure` 실행해 봇 토큰 설정
2. Telegram 에서 봇에게 메시지를 보내 채널 연결
3. onboarding 8번째 질문에서 chat_id 를 답변 → ralph 가 자동으로 `.claude/config/notify.md` 에 기록

chat_id 없이 진행해도 ralph 는 동작합니다. 알림은 `.claude/state/notifications.log` 에 fallback 기록됩니다.

---

## 사람 개입 횟수

| 시점 | 내용 | 횟수 |
|------|------|------|
| onboarding 인터뷰 | 8 질문 답변 | ~8회 |
| master-spec 동결 | "확정" 발화 | 1회 |
| STUCK 응답 (선택) | Telegram reply | 0~N회 (응답 안 해도 ralph 진행) |
| PROJECT_DONE 검토 | 결과물 확인 | 1회 |

---

## 구조

자세한 6원칙 매핑은 `CLAUDE.md` 참조.

```
.claude/
  state/
    intake/
      master-spec.md    # 대표님 비전 문서 (onboarding 후 ralph 가 합성 + 동결)
      manifest.md       # chunk 진행 표
      chunks/           # 01.md, 02.md, ... (LLM 자동 분해)
    cycles/<N>/         # 사이클별 산출물 (spec, runtime-evidence, qa-findings, ...)
    ralph-status.md     # 현재 cycle + phase
    ralph-history.md    # append-only 이벤트 로그
  config/
    notify.md           # Telegram chat_id + 메시지 schema
    verify-checklist.md # CHECKLIST 통과 기준
    model-routing.md    # 원칙 4 모델 선택 근거
```

## 6대 원칙 매핑

| 원칙 | 이 하네스에서 구현 |
|------|-------------------|
| 1. 자체 검증 | `gate-verify` + `verify-loop-output` 스킬 + Stop hook + runtime-evidence 필수 |
| 2. 프롬프트 라우팅 | `phase-*` 스킬 + 슬래시 커맨드 분리 |
| 3. Ralph 히스토리 | `append-history.sh` PostToolUse hook → `state/ralph-history.md` |
| 4. 모델 라우팅 | 각 agent `model:` + `config/model-routing.md` |
| 5. 배포 선세팅 | `scripts/deploy.sh` + `smoke-test.sh` + `/ralph-deploy` |
| 6. 페르소나 풀 (직원) | 15 페르소나, 대표님 호칭 + 보고체 톤, council 에서 ≥2 동시 발화 |
