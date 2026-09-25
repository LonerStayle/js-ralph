# js-ralph v2.0.0 — 롱러닝 무인 코딩 하네스 설계

- 날짜: 2026-09-25
- 대체: v1.x (v3-classic 템플릿, Geoffrey Huntley Ralph Wiggum 루프) — `v1.2.0` 태그에 보존
- 결정자: 대표님

---

## 1. 왜 갈아엎었나

v1.x 는 "같은 프롬프트를 fresh context 로 무한 재투입" 하는 Ralph 루프였다. 2026 년 하반기 Claude Code 는
롱러닝 세션(자동 압축 + 재개), 서브에이전트, 자동 메모리, 세션 중 즉시 반영되는 프로젝트 스킬, 풍부한 hook 이벤트,
내장 `/goal` 을 기본 제공한다. 매 반복 기억을 버리는 루프는 이 위에서 오히려 손해다:

| v1.x 문제 | 원인 |
|-----------|------|
| 큰 기능을 평평한 TODO 한 줄씩 처리 → 모듈 경계·통합이 약함 | IMPLEMENTATION_PLAN.md 가 1차원 체크리스트 |
| 사이드이펙트·예외는 "알아서" | 계획 단계에 영향 분석·예외 카탈로그가 없음 |
| 같은 실수 반복 → 사람이 PROMPT.md 에 표지판 추가 | 자가 개선 경로 없음 |
| 매 iteration 전체 맥락 재구성 비용 | fresh context 강제 |

## 2. 무엇을 유지했나

- **결정적 합격 기준** (v1 원칙 4): 통과 여부는 `.harness/verify.sh` 만 정한다. LLM 리뷰는 빠진 것을 찾는 도구.
  v2 framework 폐기 사유였던 "LLM 채점 게이트" 는 여전히 없다.
- **비전 인터뷰 + CLAUDE.md 동결 + 대표님 호칭/톤**.
- **플러그인은 얇게**: 무거운 일은 Claude Code 기본 기능에 맡긴다. 커맨드 5 · 에이전트 4 · 스킬 2 · hook 3.
  (v2 framework 의 11 phase · 14 skill · 15 페르소나 재발 방지)

## 3. 구조

```
오케스트레이터 (롱러닝 메인 세션, feature-orchestration 스킬)
 ├─ planner   Phase A: SPEC.md (영향 분석 · SE · E · AC · 가정) + TREE.md (바텀업 모듈 트리)
 ├─ reviewer  계획 / 노드 diff / feature 전체를 적대적으로 검토 — 읽기 전용, 판정 안 함
 ├─ builder   노드 하나: 예외별 테스트 먼저 → 구현 → verify.sh PASS → 커밋 (깨끗한 컨텍스트)
 └─ curator   교훈 → .harness/memory/, 반복 절차 → .claude/skills/ 승격·갱신·폐기
```

### 상태는 파일, 전이는 스크립트
- `TREE.md` 노드 줄 형식 `- [ ] 1.2.3 제목 — files: … — deps: … — covers: …` 를 `harness.sh` 가 파싱한다.
- `next` 는 "자식 전부 done + deps 전부 done" 인 첫 노드 → 자연스럽게 바텀업.
- `coverage` 는 SPEC 의 모든 AC-/E- 가 어떤 노드의 `covers:` 에 있는지 확인 → 예외 누락을 계획 단계에서 차단.
- `run.json` 은 hook 이 막아서 스크립트로만 바뀐다.

### hook 3 개
| hook | 역할 |
|------|------|
| SessionStart (startup/resume/clear/compact) | 압축·재개 직후 현재 feature · 다음 노드 주입 |
| Stop | running 이고 남은 노드가 있으면 종료 차단 + 다음 노드 안내. 완료/전부 blocked/순환/상한/3회 정체 시 해제 |
| PreToolUse | 동결 후 CLAUDE.md · verify.sh · bin · 기존 verify.d 수정 차단, run.json 직접 수정 차단 |

Stop 가드는 v1 의 "같은 프롬프트 재투입" 과 다르다 — 트리 상태에서 계산한 다음 할 일을 넘기고,
진척 지문(TREE.md + git HEAD)이 3 회 연속 그대로면 스스로 멈춘다.

## 4. 자가 개선의 경계 (대표님 결정: 메모리 + 스킬까지)

| 대상 | 에이전트가 바꿀 수 있나 |
|------|--------------------------|
| `.harness/memory/` | 예 (curator) |
| `.claude/skills/` | 예 (curator — 2회 반복 시 승격, 실패 시 갱신, 2회 오도 시 폐기) |
| `.harness/verify.d/` | 추가만 |
| `CLAUDE.md` · `verify.sh` · `harness.sh` | 아니오 (hook 차단) |
| 플러그인 에이전트/스킬 | 아니오 (플러그인 배포로만) |

Claude Code 자동 메모리(`~/.claude/projects/…`)도 켜 둔다 — 개인·기기 로컬. 프로젝트 교훈은 git 추적되는
`.harness/memory/` 에 두고 CLAUDE.md 가 `@import` 로 자동 로드한다 (플러그인 에이전트는 `memory` 필드 미지원).

## 5. 사람 개입 지점

비전 동결 · 기획 투입 · `[!] blocked` 노드 결정 · 완료 보고 검토.
되돌릴 수 없는 작업(데이터 삭제 · 운영 마이그레이션 실행 · 결제 · 외부 발송 · 보안 완화 · push)은 blocked 로 대기.

## 6. 알려진 한계

- PreToolUse 의 셸 명령 검사는 최선 노력이다 (스크립트를 새로 만들어 우회하는 것까지는 못 막는다). 최종 방어선은 git 이력 + 대표님 검토.
- `defaultMode: auto` 를 쓸 수 없는 계정은 `acceptEdits` 로 바꿔야 하고, 그러면 허용 목록 밖 명령에서 확인을 묻는다.
- 병렬 builder(worktree) 는 선택 사항이며 파일이 완전히 분리될 때만 쓴다.
- 기존 v1 하네스는 마이그레이션하지 않는다. v1.2.0 을 계속 쓰거나 새 디렉토리에 `/setup-harness` 로 다시 만든다.
