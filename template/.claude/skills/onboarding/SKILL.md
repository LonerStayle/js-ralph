---
name: onboarding
description: 대표님 첫 진입 시 인사 → 8 질문 인터뷰 → master-spec 합성 → 동결 흐름을 담당한다. NOT_STARTED phase 에서 master-spec.md 가 없거나 frozen:false 일 때 ralph-tick 이 호출한다.
model: sonnet
---

# onboarding

## 트리거 조건

ralph-tick 이 `NOT_STARTED` phase 를 감지하고 아래 중 하나 이상 해당 시 이 스킬을 호출한다.

- `.claude/state/intake/master-spec.md` 가 존재하지 않는다.
- `.claude/state/intake/master-spec.md` 의 frontmatter `frozen: false` 이다.

동결 완료(`frozen: true`) 상태이면 이 스킬을 호출하지 않는다 — ralph-tick 은 INTAKE phase 로 직접 전이한다.

---

## 흐름 개요

```
인사 → 8 질문 인터뷰 → (부족 응답 시 보강 round ≤2) → master-spec 합성 → 대표님 review → 동결
```

---

## 1단계 — 인사

세션 시작 시 대표님께 다음 형식으로 인사한다.

```
안녕하세요, 대표님. ralph 입니다.
프로젝트를 시작하기 전에 몇 가지 여쭤봐야 합니다.
8가지 질문에 답해 주시면 master-spec 초안을 만들어 검토받겠습니다.
준비되시면 시작하겠습니다.
```

---

## 2단계 — 8 질문 catalog

아래 질문을 순서대로 진행한다. 한 번에 전부 나열하지 않고 자연스러운 대화 흐름으로 진행한다 (한 번에 1~2 질문씩).

| # | 질문 | 기대 답변 형식 |
|---|------|---------------|
| 1 | **비전**: 이 프로젝트 한 줄 비전은? | 1문장 |
| 2 | **사용자**: 누가 사용하나요? | 1-2문장 페르소나 |
| 3 | **핵심 산출물**: 반드시 만들어야 하는 것 1-3가지는? | 목록 |
| 4 | **성공 정의**: "성공"의 정의는? (정량 지표 + 정성 기준 모두) | 측정 가능한 수치 포함 |
| 5 | **금지 / 범위 밖**: 절대 만들지 말아야 할 것이 있다면? | 명시적 제외 사항 |
| 6 | **외부 의존**: 필요한 외부 API / 데이터 소스 / 사용자 입력은? | 목록 (없으면 없음) |
| 7 | **규모 / 일정 / 비용 cap**: cycles 몇 개 이하로 끝내길 원하시나요? | 숫자 또는 기간 |
| 8 | **Telegram chat_id**: 진척 보고를 받으실 Telegram chat_id 는? | 숫자 ID. 발급 안 됐으면 `/telegram:configure` 실행 안내 |

---

## 3단계 — 부족 응답 처리

각 질문 응답이 모호하거나 정보가 부족하면 **1-2 round 보강 질문**을 진행한다.

- round 1: "조금 더 구체적으로 말씀해 주시겠어요? 예를 들어 [구체 예시]"
- round 2: 여전히 불명확 시 마지막 확인 1회
- round 2 후에도 모호하면 **추가 질문 없이 진행**. 해당 항목은 master-spec 에 `⚠️ 확정 필요: [항목명]` 으로 표기한다.

**무한 루프 금지**: 보강 질문은 항목당 최대 2 round. 초과하지 않는다.

---

## 4단계 — master-spec 합성

인터뷰가 끝나면 답변을 아래 6 섹션 schema 로 매핑하여 `.claude/state/intake/master-spec.md` 를 작성한다.

```markdown
---
frozen: false
frozen_at: null
created_at: <ISO 8601>
---

# master-spec: {{PROJECT_NAME}}

## 1. 비전
<1번 질문 답변>

## 2. 대상 사용자
<2번 질문 답변>

## 3. 핵심 산출물
<3번 질문 답변 — 목록>

## 4. 성공 정의
<4번 질문 답변 — 정량 + 정성>

## 5. 금지 / 범위 밖
<5번 질문 답변>

## 6. 외부 의존
<6번 질문 답변>

---

## 운영 파라미터
- cycles_cap: <7번 답변>
- telegram_chat_id: <8번 답변>

---

## 확정 필요 항목
<!-- 보강 질문 후에도 불명확한 항목을 여기 나열. 없으면 이 섹션 삭제 -->
```

작성 후 대표님께 다음을 안내한다.

```
master-spec 초안을 작성했습니다. 위 내용을 검토해 주세요.
수정이 필요하시면 말씀해 주시고,
괜찮으시면 "확정" / "OK" / "진행해" 중 하나로 말씀해 주시면 동결하고 진행하겠습니다.
또는 /ralph-spec-confirm 슬래시 커맨드로 명시적으로 동결하실 수 있습니다.
```

---

## 5단계 — 동결 트리거 (D-6)

아래 두 경로 중 하나가 발생하면 즉시 동결을 실행한다.

### 경로 A — 키워드 감지
대표님 메시지에 다음 키워드 중 하나 이상이 포함되면:

- `확정`, `OK`, `ok`, `진행해`, `동결`, `frozen`

### 경로 B — 슬래시 커맨드
`/ralph-spec-confirm` 이 호출되면

### 동결 실행

두 경로 모두 아래를 수행한다.

1. `.claude/state/intake/master-spec.md` 의 frontmatter 를 Edit 도구로 갱신:
   ```yaml
   frozen: true
   frozen_at: <현재 ISO 8601 타임스탬프>
   ```
2. `.claude/state/ralph-history.md` 에 append:
   ```
   [onboarding] master-spec frozen at <ISO 8601>
   ```
3. `.claude/state/ralph-status.md` 의 phase 를 `INTAKE` 로 갱신.
4. `.claude/config/notify.md` 의 `telegram_chat_id` 필드를 8번 질문 답변으로 채움 (미발급 시 빈 값 유지).
5. 대표님께 안내:
   ```
   master-spec 이 동결되었습니다. ralph 가 INTAKE phase 로 진입하여 chunk 분해를 시작합니다.
   이후 진척은 Telegram 으로 보고됩니다.
   ```

---

## 상태 파일 경로 요약

| 파일 | 역할 |
|------|------|
| `.claude/state/intake/master-spec.md` | 인터뷰 결과 + 동결 상태 |
| `.claude/state/ralph-status.md` | phase 갱신 (`NOT_STARTED` → `INTAKE`) |
| `.claude/state/ralph-history.md` | `[onboarding]` 항목 append |
| `.claude/config/notify.md` | `telegram_chat_id` 기록 |

---

## 주의

- 이 스킬은 **1회성**이다. master-spec 이 동결된 이후 다시 호출되면 "이미 동결된 master-spec 이 있습니다" 안내만 출력하고 종료한다.
- `/ralph-respec` 으로 재인터뷰를 트리거할 수 있다 — 이 경우 `frozen: false` 로 초기화 후 이 스킬 재시작.
- Telegram chat_id 가 발급되지 않았을 때는 `/telegram:configure` 실행 방법을 안내하고, 나머지 인터뷰는 계속 진행한다. chat_id 없이도 동결은 가능하다.
