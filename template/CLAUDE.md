# {{PROJECT_NAME}} — ralph harness

이 하네스는 js-ralph factory 의 template 에서 eject 되었다.
이 파일은 자가완결이다 — 부모 저장소를 참조하지 않는다.

---

## 도메인 (TODO: 이 하네스 고유 정보)

- 무엇을 자동화하는가: TODO
- 입력: TODO
- 산출물: TODO
- 종료 조건 (DONE 정의): TODO

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
  │      └ PASS   → CYCLE_DONE ─► [Cycle N+1] /ralph-cycle-start
```

**모든 게이트의 공통 검증 (`gate-verify`)**
- 직전 페이즈 산출물이 빈약/환각/무관 여부 확인
- 이전 페이즈에서 합의된 항목이 사라지진 않았는지 (drop 추적)
- 다음 페이즈에 필요한 입력이 빠짐없이 갖춰졌는지

상태는 `.claude/state/ralph-status.md` 에 기록 (`cycle=N, phase=...`).
사이클 산출물은 `.claude/state/cycles/<N>/` 에 보존.

---

## 슬래시 커맨드

```
/ralph-deploy            # 원칙 6 — 첫 그린 라이트 (smoke deploy)
/ralph-cycle-start       # 새 사이클 시작 → RESEARCH
/ralph-research-done     # RESEARCH → IDEATION
/ralph-ideation-done     # IDEATION → SPEC
/ralph-spec-done         # SPEC 동결 → IMPLEMENT
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
