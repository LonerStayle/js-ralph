---
name: next-proposals
description: 하네스 프로젝트에서 다음에 만들 기능을 세 시야(사용자 · 전문가 · 만드는 사람) 서브에이전트로 독립 제안받아 카드로 정리하고, 사용자 선택을 기다리다 기한이 지나면 "만드는 사람" 카드만 자동 진행하는 절차. feature 마감 직후, /next, 비전 동결 직후에 호출.
user-invocable: false
---

# next-proposals

다음 기능은 사용자가 고른다. 에이전트는 **서로 다른 세 시야에서 독립적으로** 후보를 내고, 정리해서 보여주고, 기다린다.
상태 전이는 전부 `bash .harness/bin/harness.sh proposal …` 로 한다.

## 0. 사전 확인

- `bash .harness/bin/harness.sh status` 가 `running` 이면 제안하지 않는다 — 진행 중 feature 부터 끝낸다.
- `bash .harness/bin/harness.sh proposal status` 가 `pending` 이면 새로 만들지 말고 그 카드를 다시 보여준 뒤 3번(대기)으로 간다.

## 1. 세 시야 독립 제안 (병렬)

```bash
DIR=$(bash .harness/bin/harness.sh proposal new)
```

**lens-user · lens-expert · lens-maker** 세 서브에이전트를 **한 메시지에서 동시에, 포그라운드로**(`run_in_background: false`) 호출한다
(플러그인 에이전트라 `js-ralph:lens-user` 처럼 보일 수 있다).
- 세 에이전트에게 같은 입력만 준다: "다음 기능 후보 2개를 네 시야로 제안하라. 제안 디렉토리: $DIR".
- **서로의 결과를 전달하지 않는다.** 앞 에이전트의 결과를 뒤 에이전트 프롬프트에 넣으면 시야가 섞여 이 절차가 무의미해진다.
- 각 결과를 그대로 `$DIR/lens-user.md` · `$DIR/lens-expert.md` · `$DIR/lens-maker.md` 에 저장한다.

## 2. 정리

**synthesizer** 를 포그라운드로 호출 — 제안 디렉토리 경로만 넘긴다. 결과 `$DIR/CARDS.md` 를 확인하고:

```bash
bash .harness/bin/harness.sh proposal open "$DIR"
git add .harness/proposals && git commit -m "proposal: 다음 기능 후보 $(basename "$DIR")"
```

사용자에게 카드를 보여준다 — 카드마다 `C번호 [시야] 제목` + `왜` + `크기` 3줄 요약.
끝에 안내한다: 고르려면 `/pick C2` (수정 사항은 뒤에 이어서), 직접 기획은 `/feature …`,
**30분 안에 고르지 않으면 "만드는 사람" 카드를 자동으로 진행한다**는 것 (config.json 의 값을 읽어 정확한 시간으로).

## 3. 대기 (백그라운드 타이머)

```bash
bash .harness/bin/harness.sh proposal wait
```
를 **백그라운드로** 실행하고(Bash `run_in_background`) 턴을 마친다. 타이머가 끝나면 결과 한 줄로 다시 깨어난다:

| 결과 | 할 일 |
|------|-------|
| `CHOSEN C<n>` | 이미 `/pick` 으로 처리됨 — 아무것도 하지 않는다 |
| `AUTO C<n>` | 4번으로 — "응답이 없어 만드는 사람 카드 C<n> 을 자동 진행합니다" 라고 한 줄 알리고 진행 |
| `WAIT_USER …` | 자동 진행 연속 상한 도달. 한 줄 알리고 사용자를 기다린다 (재타이머 없음) |
| `NO_AUTO_CARD` | 자동 진행 가능한 카드가 없음. 한 줄 알리고 기다린다 |

사용자가 대기 중에 카드를 고르면 `/pick` 이 처리한다 (타이머는 상태를 보고 조용히 끝난다).
세션이 끊겼다가 다시 열리면 SessionStart hook 이 기한 경과 여부를 알려준다 — 그때 `proposal timeout` 을 실행해 같은 표대로 처리한다.

## 4. 선택된 카드를 기획으로

```bash
bash .harness/bin/harness.sh proposal card      # 선택/자동 카드 본문
```
카드의 `기획:` 문장(사용자가 `/pick` 에 수정 사항을 붙였으면 그것까지 합쳐서)을 기획 원문으로 삼아
`feature-orchestration` 스킬을 **Phase A 부터** 진행한다. SPEC.md `## 원문` 에 카드 번호와 제안 디렉토리를 함께 적는다.
그 다음 `bash .harness/bin/harness.sh proposal done`.
