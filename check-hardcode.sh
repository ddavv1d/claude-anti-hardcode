#!/bin/bash
# check-hardcode.sh — хук Claude Code против хардкода.
# PreToolUse (Edit|Write): проверяет код, который Claude СОБИРАЕТСЯ записать,
# и блокирует запись, если в нём секреты, адреса внешних сервисов,
# ставки/комиссии/TTL или деньги во float. Код возврата 2 = запись отменена,
# текст ошибки уходит Claude, и он переписывает код через конфиг/переменные окружения.
# Требует jq. Лицензия MIT.
set -uo pipefail
INPUT=$(cat)
command -v jq >/dev/null 2>&1 || { echo "check-hardcode: не найден jq (brew install jq / apt install jq)" >&2; exit 2; }

FILE_PATH=$(printf '%s' "$INPUT" | jq -r '.tool_input.file_path // empty')
CONTENT=$(printf '%s' "$INPUT" | jq -r '.tool_input.content // .tool_input.new_string // empty')
[ -z "$CONTENT" ] && exit 0

# Где значения разрешены: документация, конфиги, тесты, фикстуры, сиды.
case "$FILE_PATH" in
  *.md|*.txt|*.json|*.yaml|*.yml|*.toml|*.env.example) exit 0 ;;
  */config/*|config/*|*/tests/*|tests/*|*test*|*/fixtures/*|*/docs/*|docs/*|*/seeds/*) exit 0 ;;
esac

fail() {
  echo "ЗАБЛОКИРОВАНО (check-hardcode): $1" >&2
  echo "Файл: $FILE_PATH" >&2
  echo "Вынеси значение в конфиг или переменную окружения и перепиши код." >&2
  exit 2
}

# 1. Секреты (грубые шаблоны; полный скан — gitleaks в CI)
printf '%s' "$CONTENT" | grep -qiE 'AKIA[0-9A-Z]{16}|-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|(api[_-]?key|secret|password|token)[a-z_]*\s*[:=]\s*["'"'"'][A-Za-z0-9+/_.-]{16,}["'"'"']' \
  && fail "похоже на секрет в коде. Секреты — только из окружения или секрет-хранилища"

# 2. URL внешних сервисов в коде (localhost, example.*, схемы разрешены)
URL=$(printf '%s' "$CONTENT" | grep -oE 'https?://[^"'"'"' )]+' | grep -vE 'localhost|127\.0\.0\.1|example\.(com|org)|schema|w3\.org' | head -1)
[ -n "$URL" ] && fail "адрес внешнего сервиса в коде ($URL) — это конфигурация"

# 3. Ставки, комиссии, налоги, TTL
printf '%s' "$CONTENT" | grep -qiE '(vat|nds|tax|commission|take_rate|fee)[a-z_]*\s*[:=]\s*[0-9]+([.,][0-9]+)?|ttl[a-z_]*\s*[:=]\s*[0-9]{2,}' \
  && fail "ставка/комиссия/TTL зашита в код — это данные, они меняются"

# 4. Деньги во float
printf '%s' "$CONTENT" | grep -qiE '(price|amount|money|balance|total|sum)[a-z_]*\s*[:=]\s*[0-9]+\.[0-9]+([^"0-9]|$)|(float|double)\s+(price|amount|money|balance)' \
  && fail "деньги во float. Храни целыми копейками/центами (integer)"

exit 0
