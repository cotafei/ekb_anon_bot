FROM python:3.11-slim

# Установка системных зависимостей и полезных утилит
RUN apt-get update && apt-get install -y \
    gcc \
    sqlite3 \
    curl \
    wget \
    nano \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Создание пользователя для безопасности
RUN useradd -m -u 1000 botuser && mkdir -p /app && chown -R botuser:botuser /app

WORKDIR /app

# Копирование requirements
COPY --chown=botuser:botuser requirements.txt .

# Установка Python зависимостей
RUN pip install --no-cache-dir -r requirements.txt

# Копирование исходного кода
COPY --chown=botuser:botuser . .

# Права на выполнение entrypoint
RUN chmod +x docker/entrypoint.sh

# Переключение на непривилегированного пользователя
USER botuser

# Запуск бота
ENTRYPOINT ["/app/docker/entrypoint.sh"]
