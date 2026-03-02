#!/bin/sh

echo "=========================================="
echo "  EKB Anon Bot - Запуск в Docker"
echo "=========================================="
echo "Версия: 1.1.1"
echo "Дата: $(date)"
echo "=========================================="

# Создаем директории
mkdir -p /app/data /app/logs /app/backups

# Даем правильные права
chmod 777 /app/data /app/logs /app/backups
chmod 666 /app/data/*.db 2>/dev/null || true

# Проверяем .env
if [ ! -f /app/.env ]; then
    echo "❌ Файл .env не найден!"
    exit 1
fi

# Проверяем токен
if ! grep -q "TOKEN" /app/.env; then
    echo "❌ Токен не найден!"
    exit 1
fi

echo "✅ Конфигурация загружена"
echo "📁 База данных: /app/data/anon_ekb.db"
echo "=========================================="

# Запускаем миграцию если есть
if [ -f /app/src/migrate_db.py ]; then
    echo "🔄 Проверка миграции БД..."
    cd /app/src && python migrate_db.py
fi

echo "🚀 Запуск бота..."
exec python /app/src/main.py
