---
description: "대표님이 추가/변경하고 싶은 요구를 자유 텍스트로 던지면, 그걸 bite-sized task 들로 분해해서 IMPLEMENTATION_PLAN.md 의 ## TODO 끝에 누적합니다."
argument-hint: "<추가하고 싶은 요구 자유 텍스트 — 줄바꿈/구두점 자유>"
---

# Expand Plan (IMPLEMENTATION_PLAN.md 자동 보강)

대표님이 `$ARGUMENTS` 로 던진 자유 텍스트 요구를 읽고, 이 하네스의 비전 + 현재 plan 상태를 종합해서 **bite-sized task 들로 분해**한 뒤 `IMPLEMENTATION_PLAN.md` 의 `## TODO` 섹션 끝에 `- [ ]` 한 줄씩 누적하십시오.

## 1. 사전 검증

현재 디렉토리가 ejected ralph 하네스인지 확인:

- `CLAUDE.md`, `PROMPT.md`, `IMPLEMENTATION_PLAN.md`, `AGENTS.md` 가 모두 존재해야 합니다.
- 하나라도 누락이면 즉시 중단하고 "여기는 ejected ralph 하네스가 아닙니다. `/setup-ralph` 부터 진행하십시오." 라고 대표님께 보고하십시오.

`$ARGUMENTS` 가 비어있으면: "추가하고 싶은 요구를 함께 적어주세요. 예: `/expand-plan 로그인에 카카오 추가하고 비밀번호 찾기 메일 발송도 붙여줘`" 라고 안내하고 중단하십시오.

## 2. 컨텍스트 로드 (모두 Read)

1. `CLAUDE.md` — 특히 "비전 / 사양" 섹션 8개 + "기본 기술 스택" 표. 대표님 비전 범위와 스택 디폴트 파악.
2. `IMPLEMENTATION_PLAN.md` — 현재 `## TODO` / `## DONE` 의 항목 전체. 중복 task 추가 방지용.
3. `AGENTS.md` — 검증 명령. task 분해 시 "테스트 추가" 류 항목이 이 검증과 정합한지 확인용.
4. `specs/*.md` (있으면) — 도메인 추가 사양.
5. `PROMPT.md` 의 `<!-- signs -->` 표지판 (있으면) — 이미 누적된 행동 규칙 위반 task 작성 금지.

## 3. 분해 규칙 (알잘딸깍센)

대표님 입력 1줄 ≠ task 1개. 입력의 **구현 복잡도** 를 보고 적절히 쪼개십시오.

### bite-size 기준 — 한 task = ralph 가 1 iteration 에 끝낼 만한 단위
- 파일 1~3개 수정 + 검증 PASS 까지 한 iteration 내 가능한 양
- "로그인 기능 추가" → ❌ 너무 큼
- "users 테이블에 social_provider 컬럼 추가 + 마이그레이션" → ✅ bite-size
- "POST /auth/social 엔드포인트 추가 + 카카오 토큰 검증 로직" → ✅ bite-size

### 횡단 자동 분해
대표님 입력이 backend + DB + frontend + 테스트 를 동시에 건드리면, **layer 단위로 자동 쪼개십시오**:

```
입력: "카카오 로그인 추가"
   ↓
- [ ] users 테이블에 social_provider, social_id 컬럼 마이그레이션 추가
- [ ] 카카오 OAuth client 설정값을 환경변수로 추출 (KAKAO_CLIENT_ID, KAKAO_CLIENT_SECRET)
- [ ] POST /auth/kakao/callback 엔드포인트 추가 — 토큰 교환 + users upsert
- [ ] 프론트 로그인 화면에 카카오 버튼 추가 + 콜백 라우트 처리
- [ ] /auth/kakao/callback 통합 테스트 (성공 + 토큰 실패 케이스)
```

### 순서 정렬
- DB 마이그레이션 → 백엔드 로직 → 프론트 → 테스트 순서로 의존성 정렬
- 한 입력 안에서 선후관계가 명확하면 plan 에도 그 순서대로 누적

### "1개 → 1개" 가 맞는 경우
- 단순 텍스트/카피 변경, 단일 함수 시그니처 수정, 환경변수 한 줄 추가 등은 굳이 쪼개지 마십시오.

### 중복 방지
- 이미 `## TODO` 에 같거나 거의 같은 항목이 있으면 **추가하지 마십시오**. 대표님께 "이미 plan 에 있어서 스킵했습니다: {항목}" 으로 보고.
- 이미 `## DONE` 에 있으면 (또는 `[x]` 토글된 상태) 재추가 금지. 같이 보고.

### 비전 범위 밖
- 입력이 `CLAUDE.md` 의 "5. 금지 / 범위 밖" 에 명시된 항목을 건드리면 **task 추가 거부**하고, 그 사유를 대표님께 보고. 강행하려면 비전부터 갱신해야 한다고 안내.

## 4. IMPLEMENTATION_PLAN.md 갱신

`Edit` 도구로 `IMPLEMENTATION_PLAN.md` 의 `## TODO` 섹션 끝 (그 다음 `---` 구분선 직전) 에 새 task 들을 한 줄씩 append:

```markdown
- [ ] {task 한 줄 — 동사로 시작, 검증 가능한 단위로}
```

기존 `<!-- ralph 가 이 아래에 - [ ] task 한 줄씩 누적합니다. -->` 주석은 보존. 그 아래에 누적.

## 5. 보고

대표님께 다음 형식으로 보고:

```
대표님께:

입력 {N}건 → task {M}개로 분해해 IMPLEMENTATION_PLAN.md 에 추가했습니다.

추가된 task:
1. {task 1}
2. {task 2}
...

(스킵된 항목 있으면)
스킵: {사유 — 중복 / 범위 밖}

다음 단계:
goal 루프 재시작 → /goal "Read PROMPT.md and follow it." --completion-promise "PROJECT_DONE" --max-iterations {권장 N}
(권장 N = 추가 task 수 × 1.3, 검증 재시도 여유 포함)
```

## 6. 금지

- vision-intake skill 트리거 금지 (`onboarded` 값 건드리지 마십시오 — 비전 동결 유지)
- `CLAUDE.md` 의 "비전 / 사양" 섹션 수정 금지 (이건 대표님이 직접 손볼 영역)
- `PROMPT.md` / `AGENTS.md` 수정 금지 (도구 중립 / 검증 정의는 대표님 영역)
- goal 루프 자동 시작 금지 — task 만 추가하고 대표님이 직접 재시작하도록 안내까지만
- `## DONE` 섹션 건드리지 마십시오 (참고용 로그 보존)
