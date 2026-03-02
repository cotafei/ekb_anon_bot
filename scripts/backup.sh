#!/bin/bash

cd "$(dirname "$0")/.." || exit

BACKUP_DIR="./backups"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/ekb_bot_backup_$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "📦 Создание бэкапа базы данных и логов..."

# Создаём архив только из нужных папок
tar -czf "$BACKUP_FILE" data/ logs/

echo "✅ Бэкап создан: $BACKUP_FILE"
echo "📊 Размер: $(du -h "$BACKUP_FILE" | cut -f1)"

# Удаляем старые бэкапы (старше 30 дней)
find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +30 -delete
