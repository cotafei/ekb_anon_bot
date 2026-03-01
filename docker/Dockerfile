# Используем официальный образ Python
FROM python:3.11-slim

# Устанавливаем рабочую директорию
WORKDIR /app

# Устанавливаем системные зависимости
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Копируем файл с зависимостями
COPY requirements.txt .

# Устанавливаем Python зависимости
RUN pip install --no-cache-dir -r requirements.txt

# Копируем все файлы бота
COPY . .

# Делаем entrypoint исполняемым
RUN chmod +x /app/docker/entrypoint.sh

# Создаем volume для базы данных и логов
VOLUME ["/app/data", "/app/logs"]

# Команда для запуска бота через entrypoint
ENTRYPOINT ["/app/docker/entrypoint.sh"]