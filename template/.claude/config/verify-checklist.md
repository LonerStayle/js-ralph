# verify checklist (원칙 1)

verify-loop-output 스킬이 매 루프 종료 시 이 항목들을 채점한다.
**각 하네스가 자기 도메인에 맞게 다시 채워야 한다.**

## 일반 (모든 하네스 공통)

- [ ] 이번 루프의 plan.md step 이 `[x]` 로 마킹되어 있다
- [ ] 변경된 파일이 빌드/타입체크/린트를 통과한다 (해당되는 경우)
- [ ] 새/수정된 함수에 대한 최소 1개 이상의 테스트가 존재한다
- [ ] `.claude/state/ralph-history.md` 에 이번 루프 entry 가 append 되어 있다
- [ ] 도메인 smoke test (`.claude/scripts/smoke-test.sh`) 가 여전히 통과한다

## 도메인 (TODO: 이 하네스 고유 항목으로 교체)

- [ ] (예) 사용자 가입 플로우 e2e 가 통과한다
- [ ] (예) 응답 p95 latency < 300ms
