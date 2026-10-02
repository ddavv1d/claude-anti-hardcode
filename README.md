# claude-anti-hardcode

A hook for Claude Code that stops Claude from hardcoding values: it blocks a write before the code reaches the file.

Хук для Claude Code. Не даёт Claude вшивать в код пароли, ключи, адреса сервисов и ставки. Запись блокируется ещё до того, как код попал в файл.

## Что ловит

| Что | Пример, который заблокируется |
|---|---|
| Секреты | `API_KEY = "your_key_1234567890abcd"` |
| Адреса внешних сервисов | `PAY_URL = "https://sandbox.pay.io/v1"` |
| Ставки, комиссии, TTL | `VAT = 0.12`, `fee = 5` |
| Деньги во float | `price = 19.99` |

Claude получает текст ошибки и сам переписывает код: выносит значение в конфиг или переменную окружения.

Не трогает: `.md`, `.json`, `.yaml`, `.toml`, `.env.example`, папки `config/`, `tests/`, `fixtures/`, `docs/`, `seeds/`, `localhost`.

## Установка (1 минута)

Нужен `jq`: `brew install jq` (macOS) или `sudo apt install jq` (Linux).

**1. Скачай хук:**

```bash
mkdir -p ~/.claude/hooks
curl -fsSL https://raw.githubusercontent.com/ddavv1d/claude-anti-hardcode/main/check-hardcode.sh -o ~/.claude/hooks/check-hardcode.sh
chmod +x ~/.claude/hooks/check-hardcode.sh
```

**2. Подключи в `~/.claude/settings.json`** — добавь в `hooks.PreToolUse`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "$HOME/.claude/hooks/check-hardcode.sh", "timeout": 30 }
        ]
      }
    ]
  }
}
```

Если в файле уже есть `hooks`, добавь только объект с `"matcher": "Edit|Write"` в существующий массив `PreToolUse`.

**3. Перезапусти Claude Code** и проверь:

```bash
echo '{"tool_input":{"file_path":"app.py","content":"price = 19.99"}}' | ~/.claude/hooks/check-hardcode.sh; echo "код: $?"
```

Должно быть `ЗАБЛОКИРОВАНО … код: 2`.

## Только для одного проекта

Положи файл в `.claude/hooks/check-hardcode.sh` внутри проекта, а в `.claude/settings.json` проекта укажи команду `"$CLAUDE_PROJECT_DIR"/.claude/hooks/check-hardcode.sh`.

## Важно

Это быстрый барьер, а не полный сканер. В CI добавь `gitleaks` для секретов. Шаблоны грубые: если хук мешает в каком-то файле, добавь путь в блок `case` в начале скрипта.

Лицензия: MIT.
