# {{PROJECT_NAME}} — 롱러닝 무인 코딩 하네스 (js-ralph v2)

이 파일은 **자가완결**이다 — 이 하네스를 만든 플러그인 저장소를 참조하지 않는다.
Claude Code 가 매 세션(그리고 컨텍스트 압축 뒤에도) 자동 로드한다.

---

## 🔒 비전 인터뷰 상태 (gating)

```yaml
onboarded: false
onboarded_at: null
```

> `onboarded: false` 이면 첫 응답은 **비전 인터뷰** (`vision-intake` 스킬) 로 시작한다.
> 8 질문 답변 + "확정" 발화 후 vision-intake 가 위 값을 `true` + ISO 타임스탬프로 갱신하고 아래 "비전 / 사양" 섹션을 채운다.
> `onboarded: true` 가 되는 순간부터 이 파일과 `.harness/verify.sh` 는 에이전트가 수정할 수 없다 (hook 이 차단).

---

## 비전 / 사양 (대표님 영역 — vision-intake 가 채움)

### 1. 비전
*(미입력. vision-intake skill 로 채워집니다.)*

### 2. 대상 사용자
*(미입력)*

### 3. 핵심 산출물
*(미입력)*

### 4. 성공 정의
*(미입력)*

### 5. 금지 / 범위 밖
*(미입력)*

### 6. 외부 의존
*(미입력)*

### 7. 규모·일정·비용 cap
*(미입력)*

### 8. 기술 스택
*(미입력 — 빈 채로 두면 아래 "기본 기술 스택" 디폴트가 적용됩니다)*

---

## 공통 — 작동 방식 (한눈에)

```
대표님: /feature "<기획 한 건>"
  Phase A 계획   planner → SPEC.md (영향 분석 · 사이드이펙트 · 예외 카탈로그 · 수용 기준)
                          → TREE.md (기능 → 모듈 → 말단 노드, 노드마다 계약·예외·테스트)
                 reviewer 가 계획을 적대적으로 검토 → 빠진 예외/사이드이펙트 보강
                 coverage 검사: 모든 AC-/E- ID 가 노드에 매핑돼야 착수
  Phase B 구현   말단 노드부터 바텀업. 노드 하나 = builder 서브에이전트 하나 (깨끗한 컨텍스트)
                 테스트 먼저(정상 + 예외 ID 별) → 구현 → .harness/verify.sh PASS → commit → done
                 reviewer 가 노드 diff 에서 빠진 예외 탐색 → 발견분은 새 노드로 트리 확장
                 부모 노드 = 자식 통합 + 통합 테스트
  Phase C 마감   전체 검증 · 사이드이펙트 목록 대조 · REPORT.md · curator 회고 → 대표님 보고
  자가 개선      curator 가 교훈을 .harness/memory/ 에 기록, 반복 패턴은 .claude/skills/ 로 승격·갱신
```

- **롱러닝**: 한 세션이 feature 끝까지 간다. 중간에 멈추려 하면 Stop hook 이 트리 상태에서 "다음 노드" 를 계산해 이어가게 한다. 압축 뒤에는 SessionStart hook 이 방향을 복원한다.
- **합격 기준은 결정적**: `.harness/verify.sh` (lint / typecheck / tests 자동 탐지 + `verify.d/`) 만이 통과 여부를 정한다. LLM 리뷰는 빠진 것을 찾는 도구이지 합격 판정이 아니다.
- **상태 전이는 스크립트로**: 노드 상태 · 실행 상태는 `bash .harness/bin/harness.sh` 로만 바꾼다.

---

## 공통 — 파일 지도

| 경로 | 무엇 | 누가 |
|------|------|------|
| 이 `CLAUDE.md` | 비전 + 작동 방식 + 호칭/톤 | vision-intake 합성 후 동결 |
| `.harness/verify.sh` | 결정적 검증 게이트 (보호됨) | 플러그인 |
| `.harness/verify.d/*.sh` | 프로젝트 고유 추가 검증 — 추가만 가능 | 에이전트 / 대표님 |
| `.harness/bin/harness.sh` | 트리·실행 상태 CLI (보호됨) | 플러그인 |
| `.harness/features/<slug>/SPEC.md` | 기획 원문 + 영향 분석 + 예외 카탈로그 + 수용 기준 | planner |
| `.harness/features/<slug>/TREE.md` | 모듈 트리와 노드 상태 | planner → 오케스트레이터 |
| `.harness/features/<slug>/REPORT.md` | 완료 보고 | 오케스트레이터 |
| `.harness/memory/` | 프로젝트 교훈 (git 추적, 아래에서 자동 로드) | curator |
| `.claude/skills/` | 자동 생성·갱신되는 프로젝트 스킬 | curator |

---

## 공통 — 프로젝트 메모리 (자동 로드)

@.harness/memory/MEMORY.md

---

## 공통 — 사용자 호칭 / 톤

에이전트 정의와 `.harness/` 파일은 도구 중립이라 "사용자" 라고만 표기한다.
**이 CLAUDE.md 에서 "사용자 = 대표님" 으로 치환**한다.

### 호칭
- 사용자 = **대표님 (방향 결정자)**
- 모든 응답·보고에 호칭은 "대표님" 으로 통일

### 톤
- 어투: 경어, 일관된 격식체. 반말 혼용 금지
- 길이: 응답·보고 3~5줄. 불필요한 수식어 제거
- 구조: 한 일 / 결과 / 다음 방향 분리
- 에러 메시지 그대로 노출 금지. "이런 결정이 필요합니다" 로 프레이밍
- 보고 첫 줄에 `대표님께:` prefix 권장 (필수 아님)

### 대표님 개입 시점
1. **시작**: vision-intake 8 질문 → "확정" 으로 동결
2. **기획 투입**: `/feature "<기획>"` — 기획 한 건당 한 번
3. **차단 시**: 노드가 `[!] blocked` 로 멈추면 사유를 보고 결정 → `/resume`
4. **끝**: feature 완료 보고(REPORT.md) 검토

---

## 공통 — 기본 기술 스택 (factory 디폴트)

위 "8. 기술 스택" 에 override 명시 안 했으면 이 조합으로 진행한다.

| 영역 | 기본 |
|------|------|
| Backend | Python + uv + FastAPI + SQLAlchemy |
| Web Frontend | React (Vite + TypeScript) |
| Mobile App | Android (Kotlin, Android Studio). iOS / Flutter 의도적 포기 |
| Database | Postgres |
| 그 외 (인프라/CI/캐시) | 합리적 기본값 |
