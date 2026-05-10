---
name: notify-sender
description: FR-9. CYCLE_DONE / STUCK_<phase> / PROJECT_DONE 발생 시 사용자(대표님)에게 Telegram 메시지를 발송하고, 답장 폴링 후 inbox 에 저장.
model: sonnet
---

# notify-sender

## 호출 시점 (FR-9)

다음 세 가지 이벤트가 발생할 때 `ralph-tick` 이 이 스킬을 호출한다.

| 이벤트 | 발생 조건 |
|--------|-----------|
| `CYCLE_DONE` | `project-stop-check` 가 CONTINUE 판정 후 다음 사이클 시작 직전 |
| `STUCK_<phase>` | gate-verify FAIL 5회 연속 — 사람 개입이 필요한 상황 |
| `PROJECT_DONE` | `project-stop-check` 가 STOP 판정, 또는 `/ralph-stop` 호출 |

---

## 절차

### 1. 설정 읽기

`config/notify.md` 에서 다음을 읽는다.

- `telegram_chat_id` — 비어 있으면 **콘솔 fallback** (§ Fallback 참조)
- `default_channel` — 현재는 `telegram` 고정
- 이벤트별 메시지 schema (§ 메시지 스키마 참조)

### 2. 메시지 합성

현재 이벤트 종류(CYCLE_DONE / STUCK / PROJECT_DONE)에 맞는 schema 를 읽고, 아래 원칙으로 메시지 본문을 작성한다.

**톤 원칙 (대표님 톤)**
- 비기술 언어 사용. "PR merge", "gate-verify" 같은 개발 용어 금지.
- 반말/격식 혼용 없이 일관된 어투 (경어, 짧고 명확하게).
- 3~5줄 핵심만. 불필요한 수식어 제거.
- 기획 / 개발 / 다음 방향을 명확히 분리해서 전달.
- 숫자가 있으면 반드시 포함 (사이클 번호, 통과 항목 수 등).

**메시지 구조**
```
[상황 한 줄 요약]

기획: <이번에 결정·확정된 것>
개발: <이번에 만들어진 것 — 기능 단위로>
다음: <다음 사이클/단계에서 할 것 OR 사람이 해야 할 것>

(STUCK 일 때만) 막힌 이유: <한 줄, 비기술 요약>
(PROJECT_DONE 일 때만) 최종 결과: <완료된 기능 목록 3~5개>
```

### 3. Telegram MCP 직호출 — 발송

`config/notify.md` 의 `telegram_chat_id` 가 설정된 경우, `mcp__plugin_telegram_telegram__reply` 를 직접 호출한다.

```
tool: mcp__plugin_telegram_telegram__reply
params:
  chat_id: <notify.md 의 telegram_chat_id>
  message: <합성된 메시지 본문>
```

- **bot token 불필요** — MCP 플러그인이 관리.
- `reply_to` 는 생략 (신규 메시지, quote-reply 아님).
- 발송 성공 시 `state/ralph-history.md` 에 append:
  ```
  [notify] SENT event=<이벤트> chat_id=<id> ts=<ISO>
  ```

### 4. Telegram MCP 직호출 — 폴링 (답장 수신)

발송 성공 후, 사용자 답장을 수집해 inbox 에 저장한다. 폴링은 **LLM tick 안에서** 수행 (별도 프로세스 없음).

> Telegram Bot API 는 history 검색 API 가 없다 — 새 메시지는 도착 시점에만 보인다. 따라서 폴링은 "발송 직후 한 번" 만 수행하며, 이후 메시지는 다음 tick 시작 시 재시도한다.

**폴링 절차**

1. (현재 구현: 도착 이벤트 기반) 이 tick 안에서 Telegram 채널 메시지 태그 `<channel source="telegram" ...>` 가 있으면 바로 읽는다.
2. 없으면 폴링 생략 — 다음 tick 에서 재시도.
3. 수신된 메시지가 있으면 `state/inbox/<ISO-timestamp>.md` 에 저장:

```markdown
# inbox entry
ts: <ISO>
from: <user 필드>
chat_id: <chat_id>
message_id: <message_id>
---
<메시지 본문>
```

4. `state/ralph-history.md` 에 append:
   ```
   [notify] INBOX_RECEIVED ts=<ISO> from=<user>
   ```

---

## Fallback

### MCP 호출 실패

1. `state/notifications.log` 에 실패 내역 append (timestamp + 이벤트 + 에러 메시지).
2. `state/ralph-history.md` 에 append:
   ```
   [notify] FAIL event=<이벤트> reason=<에러 요약> ts=<ISO>
   ```
3. **재시도 없음** — 다음 이벤트가 발생할 때 자연스럽게 재시도된다.
4. ralph-loop 진행을 블록하지 않는다 (notify 실패는 치명적 오류 아님).

### chat_id 미설정

`config/notify.md` 의 `telegram_chat_id` 가 비어 있거나 `CHANGEME` 인 경우:

1. Telegram 호출을 건너뛴다.
2. 콘솔(표준 출력)에 메시지 본문을 출력한다:
   ```
   [notify:console] event=<이벤트>
   <합성된 메시지 본문>
   ```
3. `state/ralph-history.md` 에 append:
   ```
   [notify] CONSOLE_FALLBACK event=<이벤트> ts=<ISO>
   ```

---

## 출력 체크

이 스킬 완료 후 반드시 다음을 확인한다.

- `state/ralph-history.md` 마지막 줄에 `[notify]` entry 존재
- SENT 또는 CONSOLE_FALLBACK 또는 FAIL 중 하나로 끝남
- FAIL 인 경우 `state/notifications.log` 에 상세 내역 존재
