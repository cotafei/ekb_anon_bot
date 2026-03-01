#!/bin/sh

echo "=========================================="
echo "  EKB Anon Bot - Запуск в Docker"
echo "=========================================="
echo "Версия: 1.1.0"
echo "Дата: $(date)"
echo "=========================================="

# Создаем необходимые директории
mkdir -p /app/data /app/logs

# Проверяем наличие .env файла
if [ ! -f /app/.env ]; then
    echo "❌ Файл .env не найден!"
    echo "Скопируйте .env.example в .env и заполните данные"
    exit 1
fi

# Проверяем наличие токена
if ! grep -q "TOKEN" /app/.env; then
    echo "❌ Токен бота не найден в .env файле!"
    exit 1
fi

echo "✅ Конфигурация загружена"
echo "📁 База данных: /app/data/anon_ekb.db"
echo "📁 Логи: /app/logs/bot.log"
echo "=========================================="

# Запускаем бота
echo "🚀 Запуск бота..."
exec python /app/src/main.py