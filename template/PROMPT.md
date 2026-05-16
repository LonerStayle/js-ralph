# PROMPT — ralph 행동 매뉴얼

> 이 파일은 ralph 가 매 iteration 마다 fresh context 로 받는 단 하나의 출발점이다.
> ralph 는 앞 iteration 을 기억하지 못한다. 모든 상태는 git + 아래 4 파일에만 있다.
>
> 이 파일은 도구 중립이다. 호칭/톤 같은 환경별 컨텍스트는 `CLAUDE.md` (또는 동등 파일) 가 담당한다.

---

## 1. 매 iteration 절차

```
1. git status / git log -5 로 현재 상태 파악
2. specs/ 의 모든 .md 를 읽는다 (사용자가 동결한 비전/사양)
3. AGENTS.md 를 읽는다 (빌드/검증 명령)
4. IMPLEMENTATION_PLAN.md 를 읽는다 (현재 작업 체크리스트)
5. 다음 행동을 결정한다 (아래 §2)
6. 실행
7. AGENTS.md 의 "필수 검증 명령" 을 모두 실행해서 PASS 확인
8. PASS 면 → git commit + IMPLEMENTATION_PLAN.md 의 해당 [ ]→[x] 토글
   FAIL 면 → 코드 되돌리거나 수정해서 다시 7 (commit 금지)
9. 종료. (ralph-loop 가 즉시 다음 iteration 재투입)
```

---

## 2. "다음 행동" 의사결정 트리

```
specs/ 에 .md 가 0개?
  → 사용자에게 "specs/ 가 비어있어 진행 불가" 보고 + 종료
  → (ralph-loop 는 같은 prompt 재투입 — specs 가 채워질 때까지 같은 보고 반복)

IMPLEMENTATION_PLAN.md 에 미완 [ ] task 가 있나?
  YES → 첫 번째 [ ] 를 픽. §3 으로.
  NO  → §4 (plan 보강) 으로.

모든 specs/ 항목이 plan 에 반영되어 있고 전부 [x]?
  → "PROJECT_DONE" 보고 + 종료
  → 종료 메시지 끝줄에 정확히: <promise>PROJECT_DONE</promise>
```

---

## 3. 한 task 실행 규칙

- task 의 범위가 큰지 작은지 먼저 판단. 1 iteration 안에 끝낼 수 있는 크기인지.
  - 너무 크면 → IMPLEMENTATION_PLAN.md 에서 하위 task 로 쪼개고, 첫 하위 task 만 진행.
- 코드 변경은 최소 단위로. 이해 안 되는 코드는 건드리지 마라.
- 외부 의존 추가는 specs/ 에 명시된 것만. specs 에 없는 의존 추가 금지.
- 테스트 자체를 약하게 만들어 통과시키는 짓 금지 (Goodhart 함정). 검증 기준이 약하다고 느끼면 AGENTS.md 에 항목 추가 후 진행.
- 이미 만들어진 파일을 우선 수정. 새 파일은 꼭 필요할 때만.

---

## 4. plan 이 비었거나 모자랄 때 (자체 plan 보강)

- specs/ 에서 아직 IMPLEMENTATION_PLAN.md 에 반영되지 않은 항목을 찾는다.
- 발견 시 IMPLEMENTATION_PLAN.md 끝에 `- [ ] {task 한 줄}` 추가.
  - 1 iteration 에 5개 이하만 추가. 한 번에 모든 걸 풀어쓰지 마라.
- plan 이 망가졌다고 판단되면 (모순/순서꼬임) 통째 폐기하고 specs/ 기반으로 다시 짠다 — disposable.

---

## 5. 검증 (backpressure)

- 검증은 AGENTS.md 의 명령으로만 한다. 너 스스로 채점하지 마라.
- 모든 검증 명령이 exit 0 일 때만 commit.
- 검증 명령이 없다 = 이 프로젝트는 ralph 가 안전하게 못 돌리는 상태. 그 사실을 보고하고 종료.

---

## 6. 커밋 메시지 형식

```
<task 한 줄 요약 — IMPLEMENTATION_PLAN.md 항목 그대로>

<무엇이 추가됐는지 1~2줄, 다음에 무엇을 할지 1줄>
```

---

## 7. 표지판

ralph 가 같은 실수를 반복하면 사용자가 이 섹션 끝에 한 줄을 추가한다.
표지판은 PROMPT.md **에만** 둔다. specs/ 나 AGENTS.md 에 행동 교정 문구 박지 마라.

<!-- signs -->
<!-- 예) "DB 마이그레이션 추가 시 항상 down 도 작성하라" -->
