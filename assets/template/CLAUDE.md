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
> 9 질문 답변 + "확정" 발화 후 vision-intake 가 위 값을 `true` + ISO 타임스탬프로 갱신하고 아래 "비전 / 사양" 섹션을 채운다.
> `onboarded: true` 가 되는 순간부터 이 파일과 `.harness/verify.sh` 는 에이전트가 수정할 수 없다 (hook 이 차단).

---

## 비전 / 사양 (대표님 영역 — vision-intake 가 채움)

> 이 프로젝트에는 **마감이 없다**. 비전은 방향(북극성)이고, "완료" 는 기획(feature) 단위에만 있다.

### 1. 비전 (방향)
*(미입력. vision-intake skill 로 채워집니다.)*

### 2. 사용자
*(미입력 — "사용자 시야" 제안 에이전트가 이 사람의 눈으로 봅니다)*

### 3. 전문가
*(미입력 — "전문가 시야" 제안 에이전트가 이 사람의 눈으로 봅니다)*

### 4. 방향 신호 ("잘 가고 있다" 는 어떤 상태인가)
*(미입력)*

### 5. 금지선
*(미입력)*

### 6. 품질 기준 (모든 기능이 항상 지킴)
*(미입력)*

> 형식: `- Q-<번호> [측정] …` 은 `.harness/verify.d/q-<번호>-*.sh` 검증 스크립트로 강제된다 (없으면 다음 기획 계획에 스크립트 작성 노드가 자동 포함).
> `- Q-<번호> [판단] …` 은 reviewer 가 모든 노드에서 점검한다.

### 7. 외부 의존
*(미입력)*

### 8. 기술 스택
*(미입력 — 빈 채로 두면 아래 "기본 기술 스택" 디폴트가 적용됩니다)*

> 9번 "지금의 초점" 은 동결 대상이 아니라서 `.harness/FOCUS.md` 에 따로 둔다 (언제든 교체).

---

## 공통 — 작동 방식 (한눈에)

```
[다음 기능 제안]  기능 하나가 끝나면 (또는 /next)
  세 시야 에이전트가 서로 모른 채 각자 2개씩 제안
    lens-user (사용자) · lens-expert (전문가) · lens-maker (만드는 사람)
  synthesizer 가 중복 합치고 비전 · 금지선 · 초점으로 걸러 카드 3~5장 (시야별 최소 1장, 순위 없음)
  대표님 선택/수정 → 그 카드가 기획이 됨
  30분 무응답 → "만드는 사람" 카드만 자동 진행 (연속 3회까지, 그 뒤엔 대표님 확인 대기)

[기획 1건 구현]   /feature "<기획>" 또는 선택된 카드
  Phase A 계획   planner → SPEC.md (영향 분석 · 사이드이펙트 · 예외 카탈로그 · 수용 기준)
                          → TREE.md (기능 → 모듈 → 말단 노드, 노드마다 계약·예외·테스트)
                 reviewer 가 계획을 적대적으로 검토 → 빠진 예외/사이드이펙트 보강
                 coverage 검사: 모든 AC-/E- ID 와 스크립트 없는 측정형 품질 기준(Q-)이 노드에 매핑돼야 착수
  Phase B 구현   말단 노드부터 바텀업. 노드 하나 = builder 서브에이전트 하나 (깨끗한 컨텍스트)
                 테스트 먼저(정상 + 예외 ID 별 + 품질 기준) → 구현 → .harness/verify.sh PASS → commit → done
                 reviewer 가 노드 diff 를 예외 · [판단] 품질 기준으로 점검 → 발견분은 새 노드로 트리 확장
                 부모 노드 = 자식 통합 + 통합 테스트
  Phase C 마감   전체 검증 · 사이드이펙트 대조 · REPORT.md · curator 회고 → 대표님 보고 → 다음 기능 제안
  자가 개선      curator 가 교훈을 .harness/memory/ 에 기록, 반복 패턴은 .claude/skills/ 로 승격·갱신
```

- **마감 없음**: 프로젝트는 끝나지 않고 넓어진다. "완료" 는 기획 단위의 수용 기준에만 있다.
- **품질 기준은 강제된다**: `[측정]` 은 검증 스크립트가 커밋을 막고, `[판단]` 은 모든 노드 리뷰의 필수 점검표다.
- **롱러닝**: 한 세션이 feature 끝까지 간다. 중간에 멈추려 하면 Stop hook 이 트리 상태에서 "다음 노드" 를 계산해 이어가게 한다. 압축 뒤에는 SessionStart hook 이 방향을 복원한다.
- **합격 기준은 결정적**: `.harness/verify.sh` (lint / typecheck / tests 자동 탐지 + `verify.d/`) 만이 통과 여부를 정한다. LLM 리뷰는 빠진 것을 찾는 도구이지 합격 판정이 아니다.
- **상태 전이는 스크립트로**: 노드 · 실행 · 제안 상태는 `bash .harness/bin/harness.sh` 로만 바꾼다.

---

## 공통 — 파일 지도

| 경로 | 무엇 | 누가 |
|------|------|------|
| 이 `CLAUDE.md` | 비전 · 금지선 · 품질 기준 + 작동 방식 + 호칭/톤 | vision-intake 합성 후 동결 |
| `.harness/FOCUS.md` | 지금의 초점 (선택, 언제든 교체) | 대표님 |
| `.harness/config.json` | 제안 대기 시간 · 자동 진행 연속 상한 (보호됨) | 대표님 |
| `.harness/verify.sh` | 결정적 검증 게이트 (보호됨) | 플러그인 |
| `.harness/verify.d/*.sh` | 추가 검증 · 측정형 품질 기준 `q-<번호>-*.sh` — 추가만 가능 | 에이전트 / 대표님 |
| `.harness/bin/harness.sh` | 트리 · 실행 · 제안 상태 CLI (보호됨) | 플러그인 |
| `.harness/proposals/<시각>/` | 세 시야 원본 제안 + CARDS.md | 제안 에이전트 |
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
1. **시작**: vision-intake 9 질문 → "확정" 으로 동결
2. **다음 기능 고르기**: 제안 카드 중 선택/수정 (`/pick C2`). 30분 안에 안 고르시면 "만드는 사람" 카드만 자동 진행
3. **직접 기획** (선택): `/feature "<기획>"` 으로 언제든 끼워 넣기
4. **차단 시**: 노드가 `[!] blocked` 로 멈추면 사유를 보고 결정 → `/resume`
5. **완료 보고** 검토 (REPORT.md) · 초점 교체 (`.harness/FOCUS.md`)

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
