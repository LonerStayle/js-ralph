---
name: onboarding
description: 대표님 첫 진입 시 인사 → 8 질문 인터뷰 → specs/vision.md 합성 → 동결 흐름. specs/vision.md 가 없거나 frozen:false 일 때만 자동 트리거.
model: sonnet
---

# onboarding

> v2 의 master-spec / manifest / chunks framework 는 폐기되었다.
> 이 skill 은 `specs/vision.md` 1 파일을 합성하는 단순 인터뷰만 담당한다.

---

## 트리거 조건

ralph 가 매 iteration 진입 시 아래 둘 중 하나면 이 skill 을 호출한다.

- `specs/vision.md` 가 존재하지 않는다.
- `specs/vision.md` 의 frontmatter `frozen: false` 이다.

`frozen: true` 면 이 skill 을 호출하지 않는다. 그냥 PROMPT.md 의 매 iteration 절차로 진입.

---

## 1단계 — 인사

```
대표님 안녕하십니까. ralph 입니다.
프로젝트를 시작하기 전에 8가지 질문을 드리겠습니다.
답변 후 specs/vision.md 초안을 만들어 검토를 받겠습니다.
```

---

## 2단계 — 8 질문 catalog

한 번에 1~2개씩 자연스러운 흐름으로 진행한다.

| # | 질문 | 기대 형식 |
|---|------|-----------|
| 1 | **비전**: 이 프로젝트 한 줄 비전은? | 1 문장 |
| 2 | **사용자**: 누가 사용합니까? | 1~2 문장 페르소나 |
| 3 | **핵심 산출물**: 반드시 만들어야 하는 것 1~3가지는? | 목록 |
| 4 | **성공 정의**: "성공"의 정의 (정량 지표 + 정성 기준)? | 측정 가능한 수치 포함 |
| 5 | **금지 / 범위 밖**: 절대 만들지 말아야 할 것은? | 명시적 제외 |
| 6 | **외부 의존**: 필요한 외부 API / 데이터 소스 / 사용자 입력은? | 목록 (없으면 "없음") |
| 7 | **규모·일정·비용 cap**: 어디까지 (cycles 수 / 기간 / 비용) 가야 합니까? | 숫자 또는 기간 |
| 8 | **기술 스택 override**: factory 디폴트 (Python+uv+FastAPI / React / Android-Kotlin / Postgres) 와 다르게 가야 합니까? | "디폴트로" 또는 구체적 override |

---

## 3단계 — 부족 응답 처리

응답이 모호하면 **항목당 최대 2 round** 보강 질문.

- round 1: "조금 더 구체적으로 말씀해 주시겠습니까? 예) [구체 예시]"
- round 2: 마지막 확인 1회
- 그래도 불명확 → 더 묻지 말고 진행. 해당 항목은 vision.md 의 "확정 필요" 섹션에 `⚠️ [항목명]` 으로 표기.

---

## 4단계 — specs/vision.md 합성

답변을 아래 schema 로 `specs/vision.md` 에 작성한다.

```markdown
---
frozen: false
frozen_at: null
created_at: <ISO 8601>
---

# vision: {{PROJECT_NAME}}

## 1. 비전
<1번 답변>

## 2. 대상 사용자
<2번 답변>

## 3. 핵심 산출물
<3번 답변 — 목록>

## 4. 성공 정의
<4번 답변 — 정량 + 정성>

## 5. 금지 / 범위 밖
<5번 답변>

## 6. 외부 의존
<6번 답변>

## 7. 규모·일정·비용 cap
<7번 답변>

## 8. 기술 스택
<8번 답변. "디폴트로" 면 factory 디폴트 명시>

---

## 확정 필요 항목
<!-- 보강 후에도 불명확한 항목. 없으면 이 섹션 삭제. -->
```

작성 후 대표님께 안내:

```
specs/vision.md 초안을 작성했습니다. 검토 부탁드립니다.
수정 사항이 있으시면 말씀해 주시고,
괜찮으시면 "확정" / "OK" / "진행해" 중 하나로 발화해 주시면 동결하고 자율 루프에 진입하겠습니다.
```

---

## 5단계 — 동결 트리거

대표님 메시지에 아래 키워드 중 하나 포함되면 즉시 동결:

- `확정`, `OK`, `ok`, `진행해`, `동결`, `frozen`

### 동결 실행 절차

1. `specs/vision.md` frontmatter Edit:
   ```yaml
   frozen: true
   frozen_at: <ISO 8601>
   ```
2. 대표님께 안내:
   ```
   specs/vision.md 가 동결되었습니다.
   이제 ralph-loop 를 시작해 주시면 자율 진행하겠습니다 ( /loop ).
   첫 iteration 에서 AGENTS.md 검증 명령이 비어 있으면 AGENTS.md 채움부터 진행합니다.
   ```

---

## 주의

- 이 skill 은 **1회성**이다. `frozen: true` 이후 다시 호출되면 "이미 동결된 vision.md 가 있습니다" 만 출력하고 종료.
- 재인터뷰가 필요하면 대표님이 `specs/vision.md` 의 frontmatter `frozen` 을 `false` 로 직접 토글 후 세션 재시작.
- v2 의 `master-spec.md` / `manifest.md` / `chunks/` / `cycles/` 는 생성하지 않는다. 디렉토리 만들지 마라.
- 추가 spec (api / ui / data 등) 이 필요하면 대표님이 동결 후 `specs/<name>.md` 를 직접 추가하거나, ralph 가 첫 iteration 에서 vision.md 기준으로 추가 spec 초안을 제안할 수 있다.
