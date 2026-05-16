# {{PROJECT_NAME}}

ralph 하네스 (v3-classic). js-ralph factory 에서 eject 됨.
Geoffrey Huntley 의 오리지널 Ralph Wiggum 패턴 + 대표님 호칭 톤.

---

## 5 단계 빠른 시작

### 1) 새 Claude 세션

```bash
cd ~/jinsup_ralph/{{PROJECT_NAME}}
claude
```

ralph 가 즉시 인사를 드립니다:
**"대표님 안녕하십니까. 이 프로젝트의 비전과 지시사항을 주십시오."**

### 2) onboarding 8 질문 답변 → `specs/vision.md` 합성

| 질문 | 내용 |
|------|------|
| 1. 비전 | 한 줄 비전 |
| 2. 사용자 | 1~2 문장 페르소나 |
| 3. 핵심 산출물 | 1~3 가지 |
| 4. 성공 정의 | 정량 + 정성 |
| 5. 금지 / 범위 밖 | |
| 6. 외부 의존 | API / 데이터 / 입력 |
| 7. 규모·일정·비용 cap | cycles ≤ N 등 |
| 8. 기술 스택 override | 디폴트와 다르게 갈지 |

답변 후 ralph 가 `specs/vision.md` 초안 작성 → 대표님 검토 → **"확정"** 발화로 동결.

### 3) `AGENTS.md` 의 검증 명령 채우기

`AGENTS.md` 에 lint / typecheck / tests 명령을 도메인에 맞게 채웁니다.
직접 1회 돌려서 모두 exit 0 인지 확인하세요. 이게 ralph 의 backpressure 입니다.

### 4) ralph-loop 시작

```
/loop
```

또는 ralph-loop 플러그인 활성. PROMPT.md 를 입력으로 박은 self-referential 루프가 시작됩니다.
이후 ralph 가 자율 진행:
- specs/ 읽음 → IMPLEMENTATION_PLAN.md 갱신/소화 → 구현 → 검증 → commit
- 매 iteration fresh context

### 5) PROJECT_DONE 검토 (마지막 1회)

ralph 가 `<promise>PROJECT_DONE</promise>` 를 출력하고 종료하면 결과물을 직접 검토.

---

## 4 파일

| 파일 | 누가 | 무엇 |
|------|------|------|
| `PROMPT.md` | factory 박음 + 대표님 표지판 추가 | ralph 행동 매뉴얼 |
| `specs/*.md` | 대표님 (onboarding 자동 합성 + 직접 수정) | 무엇을 만들지 |
| `AGENTS.md` | 대표님 또는 ralph 첫 iteration | 빌드/검증 명령 |
| `IMPLEMENTATION_PLAN.md` | ralph 99% 자동 | TODO 체크리스트 |

---

## 사람 개입 횟수

| 시점 | 내용 | 횟수 |
|------|------|------|
| onboarding | 8 질문 답변 | ~8 회 |
| 동결 | "확정" 발화 | 1 회 |
| AGENTS.md 검증 명령 채우기 | (선택) ralph 가 채워도 됨 | 0~1 회 |
| 표지판 추가 | ralph 가 실수 반복 시 PROMPT.md 끝줄 | 0~N 회 |
| PROJECT_DONE 검토 | 결과물 확인 | 1 회 |

---

## 4 원칙 매핑

자세한 설명은 `CLAUDE.md`.

| 원칙 | 구현 |
|------|------|
| 1. 단일 prompt 자기 재투입 | ralph-loop 플러그인 (Stop hook) |
| 2. 사람이 작성한 spec | `specs/*.md` (onboarding 합성 + 직접 수정) |
| 3. fresh context 매 iteration | ralph-loop 기본 동작 |
| 4. deterministic backpressure | `AGENTS.md` 의 lint/typecheck/tests |

---

## v2 와의 차이 (이 하네스를 처음 보시는 분께)

이전 v2 는 11 phase + 14 skill + 15 페르소나 + gate-verify framework 였습니다. self-referential 함정에 빠진 걸 막으려는 시도였지만, ralph 의 본질 (단순/멍청/지속) 을 잃었습니다.
v3-classic 은 Geoffrey Huntley 의 오리지널 패턴 (4 파일 + bash loop) 으로 회귀했고, 대표님 호칭/톤만 유지합니다.

자세한 회귀 결정 기록은 factory 의 `HANDOFF.md` 참조.
