#!/bin/bash
# Docker entrypoint скрипт для Django приложения с опциональными миграциями БД

set -euo pipefail

# Функция для вывода сообщений с временной меткой
log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

# Проверка переменной окружения RUN_MIGRATIONS
if [ "${RUN_MIGRATIONS:-false}" = "true" ]; then
    log "Выполнение миграций базы данных Django..."
    python manage.py migrate --noinput
    log "Миграции базы данных успешно завершены."
fi

# Проверка аргументов командной строки
if [ $# -gt 0 ]; then
    log "Выполнение пользовательской команды: $*"
    exec "$@"
else
    log "Запуск приложения Gunicorn..."
    exec gunicorn \
        --bind "[::]:80" \
        --workers "3" \
        --timeout "120" \
        "web_2025.wsgi:application"
fi