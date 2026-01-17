# syntax=docker/dockerfile:1.5

# Build stage
FROM --platform=$BUILDPLATFORM ghcr.io/astral-sh/uv:python3.14-trixie-slim AS build

ARG BUILDPLATFORM
ARG TARGETPLATFORM

ENV PYTHONDONTWRITEBYTECODE="1"
ENV PYTHONUNBUFFERED="1"
ENV UV_COMPILE_BYTECODE="1"
ENV UV_LINK_MODE="copy"

WORKDIR /app

# Установка зависимостей
COPY pyproject.toml uv.lock* ./
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --frozen --no-install-project --no-dev

# Копирование исходного кода и сборка статики
COPY src/ ./src/
RUN uv run src/manage.py collectstatic --noinput

# Production stage
FROM --platform=$TARGETPLATFORM python:3.14-slim AS production

LABEL maintainer="Redrov Ivan <digit4lsh4d0w@ya.ru>"
LABEL version="1.0.0"
LABEL description="Django application"

# Предпочитаю объявлять порты в соответствии с протоколом которым они используются
EXPOSE 80/tcp

# Если не отдает 500 - значит живо 😄
HEALTHCHECK --interval=2s --timeout=5s --start-period=3s --retries=5 \
    CMD curl -f http://localhost:80 || exit 1

ENV PATH="/app/.venv/bin:$PATH"
ENV DJANGO_ENV="production"
ENV PYTHONDONTWRITEBYTECODE="1"
ENV PYTHONUNBUFFERED="1"

# Установка зависимостей и удаление кеша пакетов для оптимизации размера образа
RUN --mount=type=cache,target=/var/cache/apt \
    --mount=type=cache,target=/var/lib/apt \
    apt-get update && apt-get install -y --no-install-recommends \
    curl \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

# Создание пользователя для запуска приложения
RUN adduser --disabled-password --gecos '' appuser

WORKDIR /app

# Копирование зависимостей из образа сборки
COPY --chown=appuser:appuser --from=build /app/.venv/ ./.venv/
# Копирование статики из образа сборки
COPY --chown=appuser:appuser --from=build /app/src/static/ /var/www/fefu-lab/static/
# Копирование исходного кода
COPY --chown=appuser:appuser src/ ./src/

WORKDIR /app/src

RUN chmod +x docker-entrypoint.sh

USER appuser

ENTRYPOINT ["./docker-entrypoint.sh"]
