#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

cd "$(dirname "$0")/.." || exit 1

BACKUP_DIR="./backups"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/ekb_bot_backup_$DATE.tar.gz"

mkdir -p "$BACKUP_DIR"

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}  Создание резервной копии${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

if [ ! -d "./data" ] || [ ! -d "./logs" ]; then
    echo -e "${RED}❌ Директории data или logs не найдены!${NC}"
    exit 1
fi

echo -e "${YELLOW}📦 Создание бэкапа...${NC}"

cd docker && docker-compose stop bot 2>/dev/null
cd ..

tar -czf "$BACKUP_FILE" data/ logs/ 2>/dev/null

if [ $? -eq 0 ]; then
    cd docker && docker-compose start bot 2>/dev/null
    cd ..
    
    echo -e "${GREEN}✅ Бэкап создан: $BACKUP_FILE${NC}"
    echo -e "${GREEN}📊 Размер: $(du -h "$BACKUP_FILE" | cut -f1)${NC}"
    
    find "$BACKUP_DIR" -name "*.tar.gz" -type f -mtime +30 -delete
else
    echo -e "${RED}❌ Ошибка при создании бэкапа!${NC}"
    cd docker && docker-compose start bot 2>/dev/null
    exit 1
fi