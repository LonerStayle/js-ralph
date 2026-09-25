# js-ralph

**Claude Code 플러그인 — 롱러닝 무인 코딩 하네스 (v2)**

기획 한 건을 넣으면 한 세션이 끝까지 갑니다:
영향 분석 → 사이드이펙트 · 예외 카탈로그 → 모듈 트리 설계 → 말단부터 바텀업 구현 → 결정적 검증 → 보고.
실패에서 배운 것은 프로젝트 메모리와 스킬로 스스로 쌓아 다음 기능에 씁니다.

> v1.x (Ralph Wiggum 루프 · v3-classic 템플릿) 는 `v1.2.0` 태그에 보존되어 있습니다.
> 설계 결정 전문: [`docs/features/2026-09-25-long-running-harness/design.md`](docs/features/2026-09-25-long-running-harness/design.md)

---

## 빠른 시작

```
# 1) 설치 (Claude Code 안에서 1회)
/plugin marketplace add LonerStayle/js-ralph
/plugin install js-ralph

# 2) 빈 디렉토리에서 claude 실행 후
/js-ralph:setup-harness            # 하네스 설치 + 비전 인터뷰 8 질문 → "확정"

# 3) 기획 투입 — 이후 무인 진행
/js-ralph:feature 회원가입에 이메일 인증 추가. 인증 메일 10분 만료, 재발송 1분 쿨다운.

# 진행 확인 / 정지 / 재개
/js-ralph:status
/js-ralph:pause
/js-ralph:resume [차단 노드에 대한 결정]
```

기존 프로젝트 위에는 `/js-ralph:setup-harness --overlay` — 기존 `CLAUDE.md` · `settings.json` 은 `*.pre-harness` 로 백업되고 README 는 그대로 둡니다.

필수 도구: `git`, `jq`.

---

## 작동 방식

```
/feature "<기획>"
  Phase A  planner  → SPEC.md  영향 분석 · 사이드이펙트(SE) · 예외 카탈로그(E) · 수용 기준(AC) · 가정
                    → TREE.md  기능 → 모듈 → 말단 노드 (노드마다 계약 · 예외 · 테스트)
           reviewer → 계획 적대적 검토 → 보강
           coverage → 모든 AC/E 가 노드에 매핑돼야 착수
  Phase B  말단부터: builder(테스트 먼저 → 구현 → verify.sh PASS → 커밋) → reviewer(빠진 예외 → 새 노드)
           실패 3회 → planner 가 노드를 더 잘게 재분해 → 그래도 실패면 [!] blocked, 다른 노드 계속
  Phase C  전체 검증 · SE 대조 · REPORT.md · curator 회고 → 보고
```

| 구성 | 파일 |
|------|------|
| 커맨드 5 | `commands/` setup-harness · feature · resume · pause · status |
| 에이전트 4 | `agents/` planner · builder · reviewer(읽기 전용) · curator |
| 스킬 2 | `skills/` vision-intake · feature-orchestration |
| hook 3 | `hooks/` SessionStart(방향 복원) · Stop(실행 가드) · PreToolUse(합격 기준 보호) |
| 템플릿 | `assets/template/` CLAUDE.md · `.harness/`(verify.sh, bin/harness.sh, memory/) · `.claude/settings.json` |

### 원칙

1. **롱러닝** — 한 세션이 feature 끝까지. 압축 뒤에는 hook 이 상태를 다시 주입하고, Stop 가드가 트리에서 다음 노드를 계산해 이어가게 한다.
2. **바텀업 트리** — 자식이 전부 통과해야 부모(통합) 착수. 노드는 builder 한 명이 한 번에 끝낼 크기.
3. **예외 우선** — 계획 단계에서 예외 카탈로그를 만들고, 모든 예외가 노드와 테스트로 매핑돼야 착수.
4. **결정적 합격** — `.harness/verify.sh` (스택 자동 탐지 + `verify.d/`) 만이 합격 기준. LLM 은 판정하지 않는다.
5. **자가 개선** — curator 가 교훈을 `.harness/memory/` 에, 반복 절차를 `.claude/skills/` 에. 합격 기준은 못 건드린다.

---

## 기본 기술 스택

| 영역 | 기본 |
|------|------|
| Backend | Python + uv + FastAPI + SQLAlchemy |
| Web Frontend | React (Vite + TypeScript) |
| Mobile App | Android (Kotlin) — iOS / Flutter 의도적 포기 |
| Database | Postgres |

비전 인터뷰 8번째 질문에서 바꿀 수 있습니다.

---

## 개발

```bash
bash scripts/verify-plugin.sh   # 정적 검증
bats tests/                     # 단위/통합 테스트
```
