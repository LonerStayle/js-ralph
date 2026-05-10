# ralph 재설계 — 외부 master-spec 모델

작성일: 2026-05-10
상태: 합의 완료, 구현 미착수 (다음 세션에서 진행)
출처: show-money cycle 1~6 사후분석 (`~/jinsup_ralph/show-money/docs/lessons/`) + 사용자 대화

---

## 0. TL;DR

**기존 ralph**: 자기가 spec 만들고 자기가 채점 → self-referential 함정
**신규 ralph**: 외부에서 가져온 큰 MD = spec source-of-truth → ralph 는 그 MD 따라가는지만 본다

→ Claude Code 는 **개발 자동화 전용**. 가치 판정은 사람(외부 기획자)이 큰 MD 1개 작성하는 걸로 위임.

---

## 1. 무엇이 무너졌나 (show-money postmortem 요약)

show-money repo 6 cycle 자율 진행 → STOP 6/6 PASS → PROJECT_DONE 발화.
사용자가 `make up` 한 번 한 직후 발견:

1. 카드 cta_url 이 정부24 메인 같은 generic landing — URL 진위 검증 없음
2. RSS 어댑터가 표제 trim 만, 본문 추출 / LLM 분류 / 광고 차단 0
3. 라벨 클릭 시 시각 피드백 없음, 다음 카드 노출 없음
4. 개인화 0

매 cycle 의 council/QA 가 이걸 cycle N+ 로 이월하면서 6 cycle 동안 가치 task 한 번도 IMPLEMENT 안 됨.

**구조적 함정 5가지**

| # | 함정 | 본질 |
|---|------|------|
| 1 | STOP 조건이 자동 검증 가능 메트릭만 | "agent 자율 검증 가능" = 측정 가능한 것만. Goodhart's law 의 ralph 버전 |
| 2 | council 페르소나 시야가 spec 안에 갇힘 | spec 자체가 인프라 약속이면 council 도 인프라만 봄 |
| 3 | fixture-driven test 가 STOP evidence 로 너무 강력 | mock PASS = "충족" 판정. fixture 의미 검증은 ralph 영역 외 |
| 4 | "cycle N+ 이월" 이 가치 task 의 묘지 | 6 cycle 동안 LLM 요약/UX/개인화 한 번도 IMPLEMENT 안 됨 |
| 5 | 페르소나 dispatch 비용 절감 누적 | cycle 4+ 메인 self-synth 로 외부 시야 사라짐 |

**핵심 한 줄**: "사용자 1번 클릭 = ralph 6 cycle 보다 강력한 quality gate"

---

## 2. 사용자 thesis (2026-05-10 결정)

> "Claude Code 는 정말 개발 자동화만 해야 할 거 같고, 기획이나 그런 건 외부 기획·디자인 전문 에이전트를 연계하는 게 맞다"
>
> "기획자가 엄청 큰 MD 를 가져오면 거기서 기획을 상세화 해주거나 디자인을 짜주고 그리고 개발하는 방식으로 가야 할 거 같아"

**왜 합리적인가**
- self-referential 함정의 핵심 = "spec source-of-truth 가 ralph 안". 외부 큰 MD = source 가 ralph 밖이면 함정 자체 차단
- ralph 강점(spec 좁을 때 잘함)에 정확히 맞음. 큰 MD 안의 1 챕터 = 1 cycle spec
- 책임 경계 명확: 가치 판정 = 외부 기획자, 구현 = ralph

**주의점 (반대 시야)**
- "외부 LLM 기획 에이전트도 같은 함정" — 결국 LLM 이면 spec 안에서만 사고. 진짜 외부 시야는 LLM 이 아니라 사람/베타
- "상세화" 단계도 LLM 이 새 가치 추가하면 self-referential 재진입. **chunk 분해 + 순서화만 허용, 새 가치 추가 금지** 강제 필요
- 디자인은 정보구조/플로우/카피 가이드까지가 LLM 한계. 픽셀/브랜드는 Figma 외주
- 큰 MD 가 misaligned 면 결과도 misaligned (GIGO). 외부 MD 품질 = ralph 출력 품질

---

## 3. 기존 vs 신규 — 표 비교

| 항목 | 기존 ralph | 신규 ralph |
|------|------------|-------------|
| spec 의 출처 | ralph 가 매 cycle RESEARCH + IDEATION 으로 **스스로 만듦** | 사람/기획자가 **밖에서 가져온 큰 MD** 1개 |
| 가치 판정 | ralph 가 자기 산출물을 자기 채점 (self-referential) | 외부 MD = 정답지. ralph 는 정답지 따라가는지만 본다 |
| 함정 | "내가 만든 시험지를 내가 채점" → 다 PASS 인데 막상 띄우면 의미 없음 | 외부 시험지가 진짜 시장/사용자 기반이면 함정 차단 |
| ralph 책임 | 기획 + 디자인 + 개발 + 검증 (전부) | 큰 MD 분해 + 디자인 상세화 + 개발 + 회귀 차단 |
| 사람 책임 | SPEC 동결 1회 (or 0회) | **큰 MD 작성** 1회 (이게 핵심 work) |
| RESEARCH/IDEATION | 새 가치 발굴 (위험: drift) | 약화 — chunk 의 "어떻게 구현할지" 디테일만 |
| PROJECT_DONE 조건 | 자동 검증 가능 메트릭 (카드 ≥30 등) | master-spec 모든 chunk 소진 + 각 chunk acceptance PASS |

---

## 4. 흐름 도표

```
[기존]
사용자 → "이런 거 만들어줘" 한 줄
   ↓
ralph cycle 1: RESEARCH → IDEATION → SPEC → 구현
   ↓ (자기 spec 자기 채점, PASS)
ralph cycle 2: 또 RESEARCH → IDEATION → SPEC → 구현
   ↓ ...
ralph cycle 6: PROJECT_DONE  ← STOP 메트릭 6/6 충족
   ↓
사용자 띄워봄 → "어 이거 카드 의미 없는데?"   ❌


[신규]
사용자 (또는 외부 기획자) → 큰 MD 1개 작성
  · 페이지 흐름, 핵심 카드 구조, URL 정책, 카피 톤, 카테고리 우선순위...
  · 이게 정답지. ralph 는 이걸 만들 권한 없음
   ↓
ralph INTAKE (1회): MD 읽고 chunk N개로 자동 분해
  · chunk 1 = "docker + /health"
  · chunk 2 = "정부24 어댑터 + 본문 추출"
  · chunk 3 = "라벨 클릭 시각 피드백"
  · ...
   ↓
ralph cycle 1: chunk 1 만 SPEC 상세화 → 구현
   ↓ (외부 MD vs 산출물 정합성으로 채점)
ralph cycle 2: chunk 2 만 → 구현
   ↓ ...
ralph cycle N: 마지막 chunk → PROJECT_DONE
   ↓
사용자 띄워봄 → MD 에 적힌 그대로 동작  ✅
(MD 가 부실하면 결과도 부실 — 책임이 사람한테 명확히 있음)
```

**비유**: 기존 = 학생이 자기 시험지 자기가 만들어 자기가 채점. 100점.
신규 = 학원 선생이 시험지 1장 줌. 학생은 그 시험지만 풀고, 채점도 그 정답지로.

---

## 5. factory template 패치 — 무엇이 정확히 바뀌나 (3개)

### 패치 1. 새 phase `INTAKE` 추가
- cycle 시작 전 1회만 실행
- 입력: 사용자가 박은 외부 MD (위치: `.claude/state/intake/master-spec.md` 또는 `docs/master-spec.md`)
- 출력: chunk N개로 분해된 `state/intake/chunks/<i>.md` + `state/intake/manifest.md` (순서/의존성)
- chunk 정의: 1 chunk = 1 cycle 분량 (acceptance criteria 5~10개 수준)
- 새 슬래시: `/ralph-intake` (또는 ralph-tick 의 첫 phase 로 NOT_STARTED → INTAKE → CYCLE_1 자동 전이)

### 패치 2. RESEARCH/IDEATION 약화
- 현재: 매 cycle 시작 시 시장조사 + 발산형 아이디어
- 신규: 매 cycle 시작 시 "이번 chunk 의 구현 방안 N개 비교" 만. **외부 MD 외 항목 추가 금지**
- gate-verify 에 drift detection 추가: "본 cycle 산출물 항목이 master-spec chunk 항목 ⊆ 인지" 검증. 위반 시 FAIL

### 패치 3. GAP_ANALYSIS 기준 변경
- 현재: "ralph 가 만든 spec.md vs 산출물" (자기참조)
- 신규: "**master-spec chunk vs 산출물**" 정합성만 본다
- council 페르소나 입력에도 master-spec chunk 가 명시 입력으로 박힘 — "spec 외부 시야" 대신 "master-spec 정답지 외부 시야"

### 부수 변경
- **PROJECT_DONE 조건 재정의**: master-spec 모든 chunk 소진 + 각 chunk acceptance PASS. 기존 "카드 ≥30" 같은 자동 메트릭 제거 (그건 chunk 안에 acceptance 로 박혀 있을 것)
- **CLAUDE.md template 갱신**: "도메인" 섹션을 "외부 master-spec 위치 + 작성 가이드" 로 교체
- **README**: 새 흐름 (사람 1단계: master-spec 작성 → ralph 2단계: INTAKE → ralph 3단계: 자율 cycle) 명시

---

## 6. 사람의 책임 (재정의)

| 빈도 | 일 |
|------|------|
| 프로젝트 시작 시 1회 | **큰 master-spec MD 작성** (이게 진짜 work, 외부 기획자/디자이너 기용 가능) |
| cycle 종료 시 (선택) | 1분 review — skip 해도 자율 진행 |

**더 안 해도 되는 일**: 매 cycle SPEC 동결 인가 (master-spec 이 spec source-of-truth 라 자동 통과)

---

## 7. master-spec MD 작성 가이드 (사람용 — 다음 세션에서 정교화)

**최소 포함 항목**
1. 도메인 한 문단 — 무엇을, 누구에게, 왜
2. 페이지/화면 흐름 — 정보구조 + 카피 톤 + 핵심 인터랙션
3. 데이터 모델 — 엔티티 + 핵심 필드 + 외부 소스 정책
4. 외부 인터페이스 — API 어댑터 정책 + URL 진위 정책
5. **chunk 분해 힌트** (선택) — 사람이 미리 cycle 단위 쪼개면 INTAKE 가 그대로 따름
6. acceptance criteria — chunk 별로 "무엇이 통과해야 끝인가"
7. 비고: 가치 가설 + 실패 신호 + 운영 단계 메트릭 (이건 ralph 가 안 봄, 사람용)

**금지**
- "직관적이고 좋은 UX" 같은 모호한 형용사만 — chunk 분해 불가
- ralph 가 알아서 정하라는 식의 빈 곳 — drift 발생

---

## 8. 다음 세션 — 즉시 할 일 체크리스트

- [ ] `template/CLAUDE.md` 의 "도메인" 섹션 → "외부 master-spec" 섹션으로 교체
- [ ] `template/.claude/skills/` 에 `phase-intake/` 추가 (master-spec → chunks 분해 로직)
- [ ] `template/.claude/skills/ralph-tick/SKILL.md` 의 phase 디스패치 표에 INTAKE 추가, RESEARCH/IDEATION 의 책임 좁힘
- [ ] `template/.claude/skills/phase-research/`, `phase-spec/` 의 프롬프트 갱신 — master-spec chunk 외 항목 추가 금지 명시
- [ ] `template/.claude/skills/gate-verify/` 에 drift detection 추가
- [ ] `template/.claude/skills/gap-analysis/` 의 비교 기준을 master-spec chunk 로 교체
- [ ] `template/.claude/skills/project-stop-check/` 의 STOP 조건을 chunk 소진 기준으로 교체
- [ ] `template/.claude/state/intake/` 디렉터리 + 빈 `master-spec.md` placeholder
- [ ] `template/.claude/commands/ralph-intake.md` 추가 (선택 — ralph-tick 자동 전이로 갈음 가능)
- [ ] `README.md` 의 빠른 시작을 새 흐름으로 갱신 (master-spec 작성 → /ralph-run)
- [ ] master-spec 작성 가이드 별도 파일 (`docs/master-spec-guide.md`) 작성

**show-money 마이그레이션 (선택)**
- show-money 는 cycle 6 PROJECT_DONE 상태. 새 모델로 갈아탈지는 사용자 판단
- 갈아탈 경우: postmortem 의 미흡 항목 (LLM 요약, URL 진위, UX) 을 master-spec 으로 다시 작성 → ralph 새 cycle 진입

---

## 9. 참고

- `~/jinsup_ralph/show-money/docs/lessons/2026-05-09-ralph-self-loop-postmortem.md` — 281 lines 사후분석 (원본)
- `~/jinsup_ralph/show-money/docs/lessons/feedback-to-ralph-factory.md` — 5가지 함정 + factory 개선 제안 (원본)
- 본 문서 = 위 둘 + 2026-05-10 사용자 대화의 합의 결과

---

_End. 다음 세션에서 8번 체크리스트 따라 factory template 패치 진행._
