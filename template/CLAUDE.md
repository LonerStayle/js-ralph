# {{PROJECT_NAME}} — ralph harness

이 하네스는 js-ralph factory 의 template 에서 eject 되었다.
이 파일은 자가완결이다 — 부모 저장소를 참조하지 않는다.

---

## 도메인 (TODO: 이 하네스 고유 정보)

- 무엇을 자동화하는가: TODO
- 입력: TODO
- 산출물: TODO
- **사이클 종료 조건** (한 사이클의 spec acceptance — 매 사이클마다 다름): TODO
- **프로젝트 종료 조건 (STOP)** — 정량 기준, 충족 시 ralph 가 새 사이클 진입을 차단:
  - 비용 cap (예: cycles ≤ N)
  - 가치 cap (예: 핵심 지표 X ≥ 임계값 Y, T일 연속 유지)
  - 예외 cap (사용자 명시적 `/ralph-stop`)

---

## 운영 가정 — ralph-loop 자율 구동

이 하네스는 **`ralph-loop` 플러그인이 반복 invoke 한다는 가정**으로 설계됐다. 사람이 매 게이트마다 슬래시 커맨드를 치는 manual 모델이 아니다.

- **메인 entry**: `/ralph-tick` (= ralph-tick 스킬). ralph-loop 가 매 iteration 마다 호출. tick 1회 = 현재 phase 1 step + gate-verify + status 갱신 후 exit. 다음 tick 이 다음 step.
- **수동 override**: `/ralph-research-done`, `/ralph-ideation-done`, `/ralph-spec-done`, `/ralph-done` 등은 사람이 자율 진행을 일시 끊고 들어올 때만 사용.
- **사람 강제 인가 지점**: SPEC 동결. agent 가 `state/cycles/<N>/spec.md` 를 작성해도, `state/cycles/<N>/spec-frozen.flag` 가 없으면 IMPLEMENT 로 진입하지 않는다 (다음 tick 도 SPEC 페이즈에 머물며 spec 보강만 반복). 사람이 검토 후 flag 생성하거나 `/ralph-spec-done` 호출.
- **정지**: `project-stop-check` 가 STOP 판정 → `phase=PROJECT_DONE` → tick 이 noop 으로 종료, ralph-loop 도 자동 cancel 권고. 명시 정지: `/ralph-stop` 또는 `ralph-loop:cancel-ralph`.

---

## 사용자 동기

이 하네스의 운전자는 **개발자**다. 기획/디자인/마케팅/QA 시야를 시스템이 강제로 끌어들여야 한 쪽으로 기울지 않는다.
→ `.claude/agents/{pm,dev,qa,designer,marketer}/` 의 페르소나 풀이 사이클의 각 단계에서 자동 활성된다. 비활성 역할 폴더도 비워두지 않고 페르소나를 채워둔다.

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

dev/* 플래너와 phase-spec 스킬은 위 디폴트를 출발점으로 잡는다. 변경하려면 사용자가 명시해야 한다.

---

## 7대 원칙 (모든 ralph 하네스의 헌법)

원칙은 문서로만 존재하면 안 된다. 아래 매핑된 위치에 코드/설정으로 박혀 강제된다.

| 원칙 | 매핑 위치 | 강제 메커니즘 |
|------|-----------|----------------|
| 1. 자체 검증 | `.claude/skills/verify-loop-output/`, `.claude/skills/gate-verify/`, `.claude/hooks/run-verify.sh`, `.claude/config/verify-checklist.md` | 모든 게이트 + 루프 종료 시 자동 호출 |
| 2. 프롬프트 라우팅 | `.claude/skills/phase-*/`, `.claude/commands/` | 페이즈별 스킬·슬래시 커맨드 분리 |
| 3. 플래너 패턴 | `.claude/agents/dev/dev-architect.md`, `dev-pragmatist.md` | 구현 전 플래너 호출 강제 |
| 4. Ralph 히스토리 | `.claude/hooks/append-history.sh` → `.claude/state/ralph-history.md` | PostToolUse hook 자동 append |
| 5. 모델 라우팅 | 각 agent `model:` + `.claude/config/model-routing.md` | agent 정의에 모델 박힘 |
| 6. 배포 선세팅 | `.claude/scripts/deploy.sh`, `smoke-test.sh`, `/ralph-deploy` | 첫 그린 라이트 통과 전엔 `/ralph-start` 차단 |
| 7. 페르소나 풀 | `.claude/agents/{pm,dev,qa,designer,marketer}/` 각 ≥3 페르소나 | council 단계에서 활성 역할 자동 선택, 역할당 ≥1 페르소나 발화 |

---

## 루프 구조 (2층: 사이클 + 구현)

ralph 는 단일 루프가 아니라 **외부(사이클) + 내부(구현/검증)** 의 2층 루프로 돈다.
모든 페이즈 전이는 게이트이고, **모든 게이트마다 `gate-verify` 스킬이 박혀** 산출물 적합성을 검증한다.

```
[Cycle N]                                              ← 외부 루프
  1. RESEARCH      시장조사 (agents/marketer + pm/metrics)
       ↓ gate-verify(research)   /ralph-research-done
  2. IDEATION      아이디어회의 (전 역할 ≥1 페르소나, 발산형)
       ↓ gate-verify(ideation)   /ralph-ideation-done
  3. SPEC          기획/디자인 (pm + designer if UI)  → spec.md 동결
       ↓ gate-verify(spec)       /ralph-spec-done
  ┌── 4. IMPLEMENT  ─────────────────────────────────┐ ← 내부 루프
  │      ↓ /ralph-done
  │  5. QA-REVIEW            (qa/* ≥2)
  │      ├ 이슈   → state/.../qa-findings.md   → 4
  │      └ clean
  │  6. REVIEW-COUNCIL       (수렴, 활성 역할 ≥1)
  │      ├ 우려   → state/.../council-feedback.md → 4
  │      └ PASS
  │  7. GAP-ANALYSIS         (pm: spec 동결본 vs 실제 산출물)
  │      ├ gaps   → state/.../gaps.md          → 4
  │      └ no gaps
  │  8. CHECKLIST            (verify-loop-output, 객관)
  │      ├ FAIL   → state/.../last-failures.md → 4
  │      └ PASS   → CYCLE_DONE
  │                   ↓
  │              project-stop-check (CLAUDE.md "프로젝트 종료 조건" 자동 채점)
  │                   ├ STOP   → status=PROJECT_DONE, /ralph-cycle-start 차단
  │                   └ 미달   → /ralph-cycle-start 로 다음 사이클 진입 가능
```

**모든 게이트의 공통 검증 (`gate-verify`)**
- 직전 페이즈 산출물이 빈약/환각/무관 여부 확인
- 이전 페이즈에서 합의된 항목이 사라지진 않았는지 (drop 추적)
- 다음 페이즈에 필요한 입력이 빠짐없이 갖춰졌는지

상태는 `.claude/state/ralph-status.md` 에 기록 (`cycle=N, phase=...`).
사이클 산출물은 `.claude/state/cycles/<N>/` 에 보존.

---

## 슬래시 커맨드

**메인 (자율 구동)**
```
/ralph-run               # 자율 루프 시작 (한 단어, 내부적으로 /loop /ralph-tick)
/ralph-tick              # 한 번만 1 step 전진 (수동 관찰용)
/ralph-spec-done         # 사람이 SPEC 동결 인가 (auto-freeze 모드 아닐 때)
/ralph-stop              # 프로젝트 강제 종료
```

**수동 override (자율 일시정지하고 끼어들 때만)**
```
/ralph-deploy            # 첫 그린 라이트 (smoke deploy)
/ralph-cycle-start       # 새 사이클 수동 시작 → RESEARCH
/ralph-research-done     # RESEARCH → IDEATION
/ralph-ideation-done     # IDEATION → SPEC
/ralph-start             # dev/* 플래너 호출 → phase-implement
/ralph-done              # QA → review-council → gap-analysis → CHECKLIST → CYCLE_DONE
/ralph-verify            # 수동 체크리스트 단독 실행
```

---

## 신규 시작 체크리스트

- [ ] `.claude/scripts/{deploy,smoke-test}.sh` 도메인 명령으로 채움
- [ ] `.claude/config/verify-checklist.md` 도메인 항목 추가
- [ ] 위 "도메인" 섹션의 4 TODO 채움
- [ ] `/ralph-deploy` 1회 통과 (`.claude/state/ralph-history.md` 에 `[deploy] PASS`)
- [ ] 그 후 `/ralph-cycle-start` 로 첫 사이클 진입
