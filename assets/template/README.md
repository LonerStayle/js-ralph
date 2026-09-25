# {{PROJECT_NAME}}

js-ralph v2 롱러닝 무인 코딩 하네스로 만든 프로젝트입니다.
기획 한 건을 넣으면 영향 분석 → 모듈 트리 설계 → 바텀업 구현 → 검증 → 보고까지 한 세션에서 끝까지 진행합니다.

---

## 사전 조건

- Claude Code 에 **js-ralph 플러그인**(v2 이상) 설치 — 훅과 에이전트가 플러그인에 들어 있습니다.
- `jq`, `git` (필수) · 스택별 도구 (`uv`, `npm`, `./gradlew` 등)

---

## 빠른 시작

```bash
cd {{PROJECT_NAME}}
claude
```

1. **비전 인터뷰** — 첫 세션에서 `vision-intake` 가 8 질문을 드립니다. "확정" 하시면 `CLAUDE.md` 가 동결됩니다.
2. **기획 투입** — 기능 하나를 자유롭게 설명합니다.
   ```
   /js-ralph:feature 회원가입에 이메일 인증 추가. 인증 메일은 10분 만료, 재발송은 1분 쿨다운.
   ```
3. **무인 진행** — 계획(SPEC/TREE) 확정 후 끝까지 자동 진행합니다. 진행 상황은 언제든:
   ```
   /js-ralph:status
   ```
4. **멈춤 / 재개**
   ```
   /js-ralph:pause     # 현재 노드 마무리 후 정지
   /js-ralph:resume    # 차단 해소 후 또는 새 세션에서 이어가기
   ```

---

## 파일 구조

```
CLAUDE.md                      비전 + 작동 방식 + 호칭 (동결 후 보호)
.harness/
  verify.sh                    결정적 검증 게이트 (보호) — 스택 자동 탐지
  verify.d/*.sh                추가 검증 — 추가만 가능
  bin/harness.sh               트리·실행 상태 CLI (보호)
  features/<slug>/SPEC.md      기획 · 영향 분석 · 예외 카탈로그 · 수용 기준
  features/<slug>/TREE.md      모듈 트리 + 노드 상태
  features/<slug>/REPORT.md    완료 보고
  memory/MEMORY.md             프로젝트 교훈 (자동 로드)
.claude/
  settings.json                권한 (auto 모드) · 자동 메모리 · 자동 압축
  skills/                      에이전트가 스스로 만들고 고치는 프로젝트 스킬
```

---

## 안전장치

| 위험 | 막는 방법 |
|------|-----------|
| 에이전트가 테스트/검증을 약하게 바꿔 통과 | `verify.sh` · `bin/` · 기존 `verify.d/` 수정 차단 (PreToolUse hook) |
| 비전을 에이전트가 임의 변경 | 동결 후 `CLAUDE.md` 수정 차단 |
| 같은 실패를 무한 반복 | 트리/커밋 변화 없이 3회 연속 멈추면 자동 blocked |
| 폭주 | `max_continuations` (기본 300) 도달 시 자동 일시정지 |
| 되돌릴 수 없는 결정 | 데이터 삭제·결제·보안 정책 변경 노드는 `[!] blocked` 로 대표님 판단 대기 |

`auto` 권한 모드를 쓸 수 없는 환경이면 `.claude/settings.json` 의 `defaultMode` 를 `acceptEdits` 로 바꾸십시오 (허용 목록 밖 명령은 확인을 묻게 됩니다).
