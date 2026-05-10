# {{PROJECT_NAME}} — ralph harness

이 하네스는 js-ralph factory 의 template 에서 eject 되었다.
이 파일은 자가완결이다 — 부모 저장소를 참조하지 않는다.

---

## 대표님 지시사항 — onboarding 가이드

eject 직후 `claude` 세션을 열면 ralph 가 즉시 대표님께 인사를 드리고 아래 8가지 질문을 드립니다.
답변 내용을 바탕으로 `master-spec.md` 초안을 자동으로 합성합니다.
대표님이 "확정" / "OK" / "진행해" 라고 발화하시면 master-spec 이 동결되고 ralph 가 자율 진행을 시작합니다.

### onboarding 8 질문 catalog

1. **비전** — 이 프로젝트 한 줄 비전은?
2. **사용자** — 누가 사용하나? (1-2 문장 페르소나)
3. **핵심 산출물** — 반드시 만들어야 하는 것 1-3가지는?
4. **성공 정의** — "성공"의 정의 (정량 + 정성)?
5. **금지 / 범위 밖** — 절대 만들지 말아야 할 것은?
6. **외부 의존** — 필요한 외부 API / 데이터 소스 / 사용자 입력은?
7. **규모 / 일정 / 비용 cap** — cycles 몇 개 이하로 끝내길 원하는가?
8. **Telegram chat_id** — 진척 보고를 받을 Telegram chat_id는? (발급 방법은 README 참조)

### master-spec 동결 절차

1. ralph 가 8 질문 인터뷰 후 `.claude/state/intake/master-spec.md` 초안 작성
2. 대표님이 내용 검토 (필요 시 추가 대화)
3. 대표님이 "확정" / "OK" / "진행해" 발화 → ralph 가 frontmatter `frozen: true` + `frozen_at` 기록
4. 또는 `/ralph-spec-confirm` 슬래시 커맨드로 명시적 동결 가능
5. 동결 후 ralph 가 INTAKE phase 로 자동 전이 → chunk 분해 시작

> master-spec 은 포괄적 비전 문서입니다. 이후 ralph 가 이것을 chunk 로 분해해서 1개씩 cycle 을 돌립니다.
> master-spec 길이 권장: ≤ 50KB (약 10,000 tokens). 초과 시 ralph 가 요약 후 분해합니다.

---

## 운영 가정 — ralph-loop 자율 구동 (Stop-hook 기반)

이 하네스는 **`ralph-loop` 플러그인 (Geoffrey Huntley 의 Ralph Wiggum 기법)** 위에서 돈다. `/loop` 같은 외부 스케줄러가 아니라, **Claude Code 의 Stop hook 이 세션 종료를 가로채서 동일 prompt 를 즉시 feed back** 하는 self-referential 루프. 끊김 없이 빠르고, 각 iteration 이 자기가 만든 파일/상태를 보고 누적 개선.

- **메인 entry**: `/ralph-run` — 내부적으로 ralph-loop 를 통해 Stop hook 기반 자율 루프 시작.
- **매 iteration**: ralph-tick 스킬 1회 적용 (현재 phase 1 step + gate-verify + status 갱신). 종료 시도 → Stop hook 이 같은 prompt 재투입 → 다음 iteration.
- **종료 트리거**:
  - `<promise>PROJECT_DONE</promise>` 출력 (모든 chunk 수용 완료 시에만 — agent 거짓 출력 금지)
  - `--max-iterations 300` 도달
  - 사용자 명시 `/ralph-stop`
- **사람 강제 인가 지점**: **2회뿐**.
  - ① **master-spec 동결** (시작): onboarding 인터뷰 후 "확정" 발화 1회
  - ② **PROJECT_DONE 검토** (끝): 결과물 확인 후 사인 1회
  - 매 cycle 사람 게이트 없음. SPEC 동결 / FIXING / CYCLE_DONE 사인 모두 자동.
- **수동 override**: `/ralph-tick` (한 번만 1 step), `/ralph-respec` (master-spec 갱신 후 INTAKE 재실행), `/ralph-stop` (PROJECT_DONE 으로 굳히기).

---

## 사용자 동기

이 하네스의 운전자는 **대표님 (방향 결정자)** 이다. 5역할 페르소나는 **직원**이다.

대표님은:
- 시작에서 master-spec (비전/지시) 을 작성하고 동결 (1회)
- 중간에는 관여 없음. Telegram 으로 진척 보고만 받음
- 끝에서 PROJECT_DONE 결과물을 검토 (1회)

직원(페르소나 풀)이 대표님의 지시를 실행한다:
- PM: 기획/방향 담당
- Dev: 구현 담당
- QA: 품질 검증 담당
- Designer: UI/UX 담당 (컨텍스트 활성)
- Marketer: 마케팅/카피 담당 (컨텍스트 활성)

모든 산출물 톤 = "대표님께 보고드리는 형식" (비기술 언어, 결정 사유 + 결과 + 다음 방향).

---

## 기본 기술 스택 (factory 디폴트)

이 하네스가 다음 중 하나에 해당되면, 명시적 다른 지시 없는 한 이 조합으로 진행한다.

| 영역 | 기본 스택 |
|------|-----------|
| Backend | Python + uv + FastAPI + SQLAlchemy |
| Web Frontend | React |
| Mobile App | Android (Kotlin, Android Studio). **iOS / Flutter 는 의도적으로 포기.** |
| Database | Postgres |
| 그 외 (인프라/CI/캐시 등) | 합리적 기본값 알아서 결정 |

---

## 6대 원칙 (모든 ralph 하네스의 헌법)

원칙은 문서로만 존재하면 안 된다. 아래 매핑된 위치에 코드/설정으로 박혀 강제된다.

| 원칙 | 매핑 위치 | 강제 메커니즘 |
|------|-----------|----------------|
| 1. 자체 검증 | `.claude/skills/verify-loop-output/`, `.claude/skills/gate-verify/`, `.claude/hooks/run-verify.sh`, `.claude/config/verify-checklist.md` | 모든 게이트 + 루프 종료 시 자동 호출, runtime-evidence 필수 |
| 2. 프롬프트 라우팅 | `.claude/skills/phase-*/`, `.claude/commands/` | 페이즈별 스킬·슬래시 커맨드 분리 |
| 3. Ralph 히스토리 | `.claude/hooks/append-history.sh` → `.claude/state/ralph-history.md` | PostToolUse hook 자동 append |
| 4. 모델 라우팅 | 각 agent `model:` + `.claude/config/model-routing.md` | agent 정의에 모델 박힘 |
| 5. 배포 선세팅 | `.claude/scripts/deploy.sh`, `smoke-test.sh`, `/ralph-deploy` | 첫 그린 라이트 통과 전엔 사이클 진입 차단 |
| 6. 페르소나 풀 | `.claude/agents/{pm,dev,qa,designer,marketer}/` 각 ≥3 페르소나 | council 단계에서 활성 역할 자동 선택, 역할당 ≥2 페르소나 발화, 대표님 호칭 + 보고체 톤 |

---

## 루프 구조

ralph 는 **단일 연속 루프**로 돈다. 페이즈 전이는 모두 게이트이고, **모든 게이트마다 `gate-verify` 스킬이 박혀** 산출물 적합성을 검증한다.

```
[시작]
  NOT_STARTED: master-spec 미동결 → onboarding 인터뷰 (~8 질문) → master-spec 합성 → "확정" 동결
       ↓ (master-spec.frozen 생성)
  INTAKE: LLM 이 master-spec → chunk N개 분해 → manifest.md 생성 (사람 review X, 자동 통과)
       ↓

[Chunk K 사이클 — 외부 루프]
  CHUNK_DETAIL: chunk K 의 구현 방안 + 디테일 발산 (페르소나 dispatch, dispatch cap 적용)
       ↓ gate-verify(chunk_detail)
  SPEC: chunk 상세화 → spec.md 동결
       ↓ gate-verify(spec)
  ┌── IMPLEMENT ─────────────────────────────────┐ ← FAIL 시 직회귀 (FIXING_* phase 없음)
  │      ↓
  │  QA_REVIEW           (qa/* ≥2)
  │      ├ 이슈   → qa-findings.md   → IMPLEMENT
  │      └ clean
  │  REVIEW_COUNCIL      (수렴, 활성 역할 ≥2, dispatch cap 적용)
  │      ├ 우려   → council-feedback.md → IMPLEMENT
  │      └ PASS
  │  GAP_ANALYSIS        (pm: master-spec chunk vs 실제 산출물 1:1 대조)
  │      ├ gaps   → gaps.md          → IMPLEMENT
  │      └ no gaps
  │  CHECKLIST           (verify-loop-output, runtime-evidence 필수)
  │      ├ FAIL   → last-failures.md → IMPLEMENT
  │      └ PASS   → CYCLE_DONE
  │                   ↓ Telegram 진척 보고 (대표님 톤)
  │              project-stop-check (모든 chunk 수용 여부 채점)
  │                   ├ 완료   → PROJECT_DONE → Telegram 완료 보고
  │                   └ 미달   → 다음 chunk → CHUNK_DETAIL (자동)
  │
  │  [STUCK 발생 시] fail_streak ≥5 또는 deferral_count ≥3
  │      → manifest 에 BLOCKED 표기 + Telegram 개입 요청
  │      → 다음 PENDING chunk 로 우회 (ralph 멈춤 X)
```

**모든 게이트의 공통 검증 (`gate-verify`)**
- 직전 페이즈 산출물이 빈약/환각/무관 여부 확인
- master-spec chunk 의 acceptance 항목이 반영됐는지 확인 (drop 추적)
- 다음 페이즈에 필요한 입력이 빠짐없이 갖춰졌는지

상태는 `.claude/state/ralph-status.md` 에 기록.
사이클 산출물은 `.claude/state/cycles/<N>/` 에 보존.
master-spec 및 chunk 는 `.claude/state/intake/` 에 보존.

---

## 슬래시 커맨드

**메인 (자율 구동)**
```
/ralph-run               # 자율 루프 시작 (한 단어, ralph-loop 기반 Stop hook self-loop)
/ralph-tick              # 한 번만 1 step 전진 (수동 관찰용)
/ralph-respec            # master-spec 갱신 후 INTAKE 재실행 (BLOCKED chunk 해제용)
/ralph-stop              # 프로젝트 강제 종료 (PROJECT_DONE 으로 굳히기)
```

**수동 override (자율 일시정지하고 끼어들 때만)**
```
/ralph-deploy            # 첫 그린 라이트 (smoke deploy)
/ralph-start             # dev/* 페르소나 호출 → phase-implement
/ralph-done              # QA → review-council → gap-analysis → CHECKLIST → CYCLE_DONE
/ralph-verify            # 수동 체크리스트 단독 실행
```

**[deprecated] v1 커맨드 — 호출 시 안내 메시지만 출력**
```
/ralph-research-done     # 폐기 (RESEARCH phase 제거됨)
/ralph-ideation-done     # 폐기 (IDEATION phase 제거됨)
/ralph-spec-done         # 폐기 → /ralph-respec 으로 대체
/ralph-cycle-start       # 폐기 (자동 진행으로 대체)
```

---

## 신규 시작 체크리스트

- [ ] `.claude/config/notify.md` 의 `telegram_chat_id` 채움 (onboarding 8번째 질문에서 받음)
- [ ] `.claude/scripts/{deploy,smoke-test}.sh` 도메인 명령으로 채움
- [ ] `.claude/config/verify-checklist.md` 도메인 항목 추가
- [ ] `/ralph-deploy` 1회 통과 (`.claude/state/ralph-history.md` 에 `[deploy] PASS`)
- [ ] 그 후 `/ralph-run` 으로 onboarding 시작 (ralph 가 대표님께 인사 → 8 질문 → master-spec 합성 → 동결 → INTAKE 자동 전이)
