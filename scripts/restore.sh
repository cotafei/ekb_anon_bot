#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

cd "$(dirname "$0")/.." || exit 1

BACKUP_DIR="./backups"

echo -e "${BLUE}==========================================${NC}"
echo -e "${BLUE}  Восстановление из резервной копии${NC}"
echo -e "${BLUE}==========================================${NC}"
echo ""

if [ ! -d "$BACKUP_DIR" ] || [ -z "$(ls -A "$BACKUP_DIR")" ]; then
    echo -e "${RED}❌ Нет доступных бэкапов в $BACKUP_DIR${NC}"
    exit 1
fi

echo -e "${YELLOW}Доступные бэкапы:${NC}"
ls -lh "$BACKUP_DIR"/*.tar.gz 2>/dev/null | awk '{print "  " $9 " (" $5 ")"}'
echo ""

echo -e "${YELLOW}Введите имя файла для восстановления (или 'latest' для последнего):${NC}"
read -r BACKUP_FILE

if [ "$BACKUP_FILE" = "latest" ]; then
    BACKUP_FILE=$(ls -t "$BACKUP_DIR"/*.tar.gz 2>/dev/null | head -1)
    if [ -z "$BACKUP_FILE" ]; then
        echo -e "${RED}❌ Нет бэкапов для восстановления${NC}"
        exit 1
    fi
    echo -e "${GREEN}Выбран последний бэкап: $BACKUP_FILE${NC}"
else
    BACKUP_FILE="$BACKUP_DIR/$BACKUP_FILE"
    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "${RED}❌ Файл не найден: $BACKUP_FILE${NC}"
        exit 1
    fi
fi

echo -e "${RED}⚠️  ВНИМАНИЕ: Восстановление удалит текущие данные!${NC}"
echo -e "${YELLOW}Продолжить? (y/n)${NC}"
read -r CONFIRM

if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo -e "${YELLOW}Операция отменена${NC}"
    exit 0
fi

echo -e "${YELLOW}🛑 Останавливаю бота...${NC}"
cd docker && docker-compose stop bot
cd ..

echo -e "${YELLOW}📦 Восстанавливаю данные...${NC}"
rm -rf data/* logs/* 2>/dev/null
tar -xzf "$BACKUP_FILE" -C ./

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Данные восстановлены из: $BACKUP_FILE${NC}"
    
    echo -e "${YELLOW}🚀 Запускаю бота...${NC}"
    cd docker && docker-compose start bot
    cd ..
    
    echo -e "${GREEN}✅ Восстановление завершено${NC}"
else
    echo -e "${RED}❌ Ошибка при восстановлении${NC}"
    exit 1
fi