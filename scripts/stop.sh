#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}🛑 Остановка бота...${NC}"

cd "$(dirname "$0")/../docker" || exit 1
docker-compose down

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Бот остановлен${NC}"
else
    echo -e "${RED}❌ Ошибка при остановке${NC}"
    exit 1
fi