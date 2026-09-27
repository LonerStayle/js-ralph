# CLAUDE.md — js-ralph (Claude Code 플러그인)

이 저장소(`js-ralph`)는 **Claude Code 플러그인 `js-ralph` 의 개발/배포 저장소** 다. 여기서 하네스를 직접 운영하지 않는다.

새 하네스는 빈 디렉토리에서 `/js-ralph:setup-harness` 한 번 → 비전 인터뷰(9 질문) → 세 시야 제안 카드 중 `/js-ralph:pick` → 무인 진행.

> v1.x (Geoffrey Huntley Ralph Wiggum 루프, v3-classic 템플릿) 는 **`v1.2.0` 태그**에, 그 이전 factory 모델은 `pre-plugin` 브랜치에 보존되어 있다.
> v2.0.0 에서 루프 방식을 전부 제거했다. 설계 결정 전문: `docs/features/2026-09-25-long-running-harness/design.md`

---

## 핵심 디자인 (v2 — 롱러닝 무인 코딩 하네스)

| 원칙 | 강제 메커니즘 |
|------|---------------|
| 마감 없는 비전 — 대표님은 방향 · 금지선 · 품질 기준까지만 | vision-intake 9 질문 (마감 · 규모 · 최종 산출물 질문 없음), `verify-plugin.sh` [8] |
| 다음 기능은 세 시야 제안 → 대표님 선택 | `next-proposals` 스킬 + lens-user · lens-expert · lens-maker (서로 결과 비공유) + synthesizer |
| 무응답 시 만드는 사람 카드만 자동 진행 | `harness.sh proposal wait/timeout` (기본 30분, 연속 3회 상한 — `.harness/config.json`) |
| 품질 기준 강제 | `[측정]` → `verify.d/q-<n>-*.sh` 없으면 `coverage` 가 착수 차단 / `[판단]` → reviewer 필수 점검, 위반 = high |
| 롱러닝 — 한 세션이 feature 끝까지 | `hooks/stop-guard.sh` (트리에서 다음 노드 계산, 정체 3회·상한 시 해제) + `hooks/session-context.sh` (압축 뒤 방향 복원) |
| 바텀업 모듈 트리 | `TREE.md` + `harness.sh next` (자식·deps 전부 done 이어야 착수) |
| 사이드이펙트·예외 우선 | planner 의 SPEC.md (영향 분석 · SE · E · AC) + `harness.sh coverage` 게이트 + reviewer |
| 결정적 합격 기준 | `.harness/verify.sh` (스택 자동 탐지 + `verify.d/`). LLM 채점 없음 |
| 자가 개선 (메모리 + 스킬까지) | curator → `.harness/memory/` · `.claude/skills/`. 합격 기준은 `hooks/protect-files.sh` 가 보호 |

→ 플러그인은 얇게 유지한다. 커맨드 7 · 에이전트 8 · 스킬 3 · hook 3. 새 구성요소를 늘리기 전에 Claude Code 기본 기능으로 되는지 먼저 본다 (v2 framework 11 phase · 14 skill · 15 페르소나 재발 방지).

---

## 사용자 호칭

`assets/template/CLAUDE.md` 가 "사용자 = 대표님" 으로 치환한다. `agents/*` · `skills/feature-orchestration` · `skills/next-proposals` · `.harness/*` 는 도구 중립이라 "사용자" 라고만 쓴다 (`verify-plugin.sh` [9] 가 강제).

→ 호칭/톤 변경은 `assets/template/CLAUDE.md` 의 "공통 — 사용자 호칭 / 톤" 섹션에서만 한다.

---

## 기본 기술 스택 (factory 디폴트)

명시적 다른 지시 없으면 이 조합으로 진행한다. 비전 인터뷰 8번 질문에서 override 가능.

| 영역 | 기본 |
|------|------|
| Backend | Python + uv + FastAPI + SQLAlchemy |
| Web Frontend | React (Vite + TypeScript) |
| Mobile App | Android (Kotlin, Android Studio). iOS / Flutter 의도적 포기 |
| Database | Postgres |
| 그 외 (인프라/CI/캐시) | 합리적 기본값 |

`assets/template/CLAUDE.md` 의 "공통 — 기본 기술 스택" 섹션에도 같은 표가 박혀 있다 (자가완결).

---

## 저장소 디렉토리 구조

```
js-ralph/
  .claude-plugin/plugin.json, marketplace.json
  commands/        setup-harness · next · pick · feature · resume · pause · status
  agents/          제안: lens-user · lens-expert · lens-maker (읽기 전용) · synthesizer
                   구현: planner · builder · reviewer (읽기 전용) · curator
  skills/          vision-intake · next-proposals · feature-orchestration
  hooks/           hooks.json · session-context.sh · stop-guard.sh · protect-files.sh
  scripts/         setup-harness.sh (설치 본체) · verify-plugin.sh (정적 검증)
  assets/template/ 하네스 원본 — CLAUDE.md · README.md · VERSION(=4) · .gitignore
                   .harness/{verify.sh, verify.d/, bin/harness.sh, memory/MEMORY.md, features/,
                             config.json, FOCUS.md}
                   .claude/{settings.json, skills/}
  tests/           bats (setup · harness CLI · 제안/품질 · hooks · verify 게이트 · 플러그인)
  docs/            v2 framework historical + 의사결정 기록 (보존)
```

hook 은 `${CLAUDE_PLUGIN_ROOT}/assets/template/.harness/bin/harness.sh` 를 호출한다 — 판정 로직은 `harness.sh` 한 곳에만 둔다.

---

## 작업 시 주의 (플러그인 유지보수자용)

1. **`assets/template/CLAUDE.md` 는 자가완결** — 설치 후 이 저장소를 참조할 수 없다. 작동 방식 / 호칭 / 스택 변경 시 같이 갱신.
2. **파싱되는 형식 세 가지** — TREE.md 노드 줄, CARDS.md 카드 헤더(`## C<n> [시야] 제목`), CLAUDE.md 품질 기준 줄(`- Q-<n> [측정|판단] …`).
   바꾸면 `harness.sh` 파서 · 해당 에이전트/스킬 예시 · 테스트를 같이 바꾼다.
3. **변경 후 `bash scripts/verify-plugin.sh` 와 `bats tests/`** 둘 다 통과해야 commit 한다.
4. **큰 설계 변경은 `docs/features/<날짜>-<이름>/design.md`** 에 결정과 이유를 남긴다.
5. **`docs/`** 의 v2 framework 시절 자료와 plugin 전환 기록은 historical 로 보존. 갈아엎지 마라.
6. `META-BUILDER-HANDOFF.md` 는 별도 플러그인(`/new-skill`) 인수인계 문서다. v2 의 curator 가 프로젝트 스킬 자동 생성을 일부 흡수했으니 착수 전 범위를 다시 정한다.

---

## 버전업 / 배포 워크플로 (factory 유지보수자용)

> **⚠️ 절대 규칙** — 본 플러그인 코드를 변경하고 버전을 올렸으면, **반드시 대표님께 아래 갱신 시퀀스를 안내해야 한다**. 마켓플레이스 갱신 마찰은 대표님이 모르고 지나가면 새 버전이 ejected 하네스에 안 깔리므로, 안내 누락 = 사실상 배포 실패.

### 1) 한 commit 으로 묶기

버전 올릴 때 다음 두 파일을 **같은 commit** 에 묶는다:
- `.claude-plugin/plugin.json` 의 `version`
- `.claude-plugin/marketplace.json` 의 `plugins[].source.ref` + `plugins[].version`

그 다음 tag → push 순서:

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json <기타 변경 파일>
git commit -m "feat(...): vX.Y.Z — ..."
git tag -a vX.Y.Z -m "..."
git push origin main
git push origin vX.Y.Z
```

→ tag 가 marketplace 갱신까지 포함한 commit 을 가리켜야 ref 와 실제 코드가 sync 된다. (분리 commit + 뒤늦은 tag 는 tag 시점 ref 가 옛날 marketplace.json 을 가리켜 옵셋이 생긴다.)

### 2) push 직후 대표님께 **반드시** 안내 (의무)

push 가 끝나면 대표님께 아래 시퀀스를 **반드시 보고/안내한다. 생략 금지**:

```
대표님께:

vX.Y.Z 배포 완료. 다른 ejected 하네스에서 적용하시려면:

  /plugin marketplace update js-ralph    # 카탈로그 다시 fetch
  /plugin update js-ralph                # 플러그인 코드 갱신
  /reload-plugins                        # 즉시 적용

확인: `/` 메뉴에 새 슬래시가 보이면 성공.
```

### 3) 왜 두 명령 다 필요한가
- `/plugin marketplace update <marketplace-name>` — marketplace.json 캐시 갱신 (어떤 ref 가 최신인지 클라이언트가 인식)
- `/plugin update <plugin-name>` — 그 ref 기준으로 plugin 코드 fetch
- 둘 중 하나만 하면 옛날 카탈로그 또는 옛날 코드가 남아 새 슬래시가 안 잡힌다.

---

## 릴리스 체크리스트

- [ ] `bash scripts/verify-plugin.sh` → [PASS]
- [ ] `bats tests/` → 전부 ok
- [ ] 빈 임시 디렉토리에서 `bash scripts/setup-harness.sh` → 설치 성공
- [ ] (선택) 실제 Claude Code 세션에서 `/js-ralph:setup-harness` → 인터뷰 → 작은 `/js-ralph:feature` 1건 sanity
