#!/bin/bash

# ============================================
# Скрипт автоматического обновления EKB Anon Bot с GitHub
# Версия: 1.2 (с правильной проверкой ошибок)
# ============================================

# Цвета для красивого вывода
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

REPO_URL="https://github.com/cotafei/ekb_anon_bot.git"
TEMP_DIR="ekb_anon_bot_temp"
BACKUP_DIR="backups"
DATE=$(date +"%Y%m%d_%H%M%S")

echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}   EKB Anon Bot - Обновление с GitHub   ${NC}"
echo -e "${BLUE}===========================================${NC}"
echo ""

# Переходим в корневую директорию проекта
cd "$(dirname "$0")/.." || { echo -e "${RED}❌ Ошибка: не могу найти корень проекта${NC}"; exit 1; }
echo -e "${GREEN}✅ Корень проекта: $(pwd)${NC}"

# 1. Проверяем наличие git
if ! command -v git &> /dev/null; then
    echo -e "${RED}❌ Git не установлен!${NC}"
    echo "Пожалуйста, установите Git: https://git-scm.com/"
    exit 1
else
    echo -e "${GREEN}✅ Git найден${NC}"
fi

# 2. Проверяем наличие python
if ! command -v python &> /dev/null; then
    echo -e "${RED}❌ Python не установлен!${NC}"
    echo "Устанавливаю Python..."
    sudo apt update && sudo apt install -y python3 python3-pip
    sudo ln -s /usr/bin/python3 /usr/bin/python
else
    echo -e "${GREEN}✅ Python найден${NC}"
fi

# 3. Проверяем наличие docker-compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}❌ docker-compose не установлен!${NC}"
    echo "Устанавливаю docker-compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
else
    echo -e "${GREEN}✅ docker-compose найден${NC}"
fi

# 4. Создаем резервную копию текущей версии
echo -e "${YELLOW}📦 Создаю резервную копию...${NC}"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/pre_update_backup_$DATE.tar.gz"

# Останавливаем бота перед бэкапом (если он запущен)
if [ -f "docker/docker-compose.yml" ]; then
    echo -e "${YELLOW}⏸️  Останавливаю бота...${NC}"
    cd docker && docker-compose stop bot 2>/dev/null && cd ..
fi

# Создаем бэкап важных данных
if [ -d "data" ] || [ -d "logs" ] || [ -f ".env" ]; then
    tar -czf "$BACKUP_FILE" data/ logs/ .env 2>/dev/null
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Резервная копия создана: $BACKUP_FILE${NC}"
    else
        echo -e "${RED}❌ Ошибка при создании бэкапа!${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠️ Нет данных для бэкапа, продолжаем...${NC}"
fi

# 5. Клонируем свежую версию с GitHub
echo -e "${YELLOW}📥 Скачиваю последнюю версию с GitHub...${NC}"
rm -rf "$TEMP_DIR" 2>/dev/null
git clone --depth 1 "$REPO_URL" "$TEMP_DIR"

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Ошибка при клонировании репозитория!${NC}"
    # Запускаем бота обратно, если останавливали
    if [ -f "docker/docker-compose.yml" ]; then
        cd docker && docker-compose start bot 2>/dev/null && cd ..
    fi
    exit 1
fi
echo -e "${GREEN}✅ Репозиторий скачан${NC}"

# 6. Сохраняем скрипт миграции
echo -e "${YELLOW}💾 Сохраняю скрипт миграции...${NC}"
if [ -f "src/migrate_db.py" ]; then
    cp src/migrate_db.py /tmp/migrate_db.py.bak
    echo -e "${GREEN}✅ Скрипт миграции сохранен${NC}"
fi

# 7. Обновляем файлы проекта
echo -e "${YELLOW}🔄 Обновляю файлы проекта...${NC}"

# Обновляем папку src
echo "   📁 Обновляю src/"
rm -rf src_new 2>/dev/null
cp -r "$TEMP_DIR/src" ./src_new

# Восстанавливаем скрипт миграции
if [ -f "/tmp/migrate_db.py.bak" ]; then
    cp /tmp/migrate_db.py.bak src_new/migrate_db.py
    echo -e "${GREEN}   ✅ Скрипт миграции восстановлен${NC}"
fi

# Обновляем docker
echo "   📁 Обновляю docker/"
rm -rf docker_new 2>/dev/null
cp -r "$TEMP_DIR/docker" ./docker_new

# Обновляем scripts
echo "   📁 Обновляю scripts/"
rm -rf scripts_new 2>/dev/null
cp -r "$TEMP_DIR/scripts" ./scripts_new
# Сохраняем текущий скрипт обновления
if [ -f "scripts/update_from_github.sh" ]; then
    cp scripts/update_from_github.sh scripts_new/
fi

# Обновляем корневые файлы
cp "$TEMP_DIR/requirements.txt" ./requirements_new.txt 2>/dev/null
cp "$TEMP_DIR/.env.example" ./.env.example_new 2>/dev/null
cp "$TEMP_DIR/CHANGELOG.md" ./CHANGELOG.md_new 2>/dev/null
cp "$TEMP_DIR/UPDATE.md" ./UPDATE.md_new 2>/dev/null

# 8. Заменяем старые папки новыми
echo -e "${YELLOW}🔁 Заменяю старые файлы новыми...${NC}"
rm -rf src docker scripts 2>/dev/null
mv src_new src
mv docker_new docker
mv scripts_new scripts
mv requirements_new.txt requirements.txt 2>/dev/null
mv .env.example_new .env.example 2>/dev/null
mv CHANGELOG.md_new CHANGELOG.md 2>/dev/null
mv UPDATE.md_new UPDATE.md 2>/dev/null

# Делаем скрипты исполняемыми
chmod +x scripts/*.sh 2>/dev/null
chmod +x docker/*.sh 2>/dev/null

# 9. Восстанавливаем .env
echo -e "${YELLOW}🔧 Проверяю наличие .env файла...${NC}"
if [ ! -f ".env" ]; then
    echo -e "${YELLOW}⚠️  Файл .env не найден, создаю из .env.example${NC}"
    cp .env.example .env
    echo -e "${RED}⚠️  ОТРЕДАКТИРУЙТЕ .env файл!${NC}"
    echo -e "${YELLOW}   nano .env${NC}"
    exit 1
else
    echo -e "${GREEN}✅ .env файл сохранен${NC}"
fi

# 10. Запускаем миграцию БД
echo -e "${YELLOW}🔄 Запускаю миграцию базы данных...${NC}"
cd src
if python migrate_db.py; then
    echo -e "${GREEN}✅ Миграция БД успешно выполнена${NC}"
else
    echo -e "${RED}❌ Ошибка при миграции БД!${NC}"
    exit 1
fi
cd ..

# 11. Запускаем бота
echo -e "${YELLOW}🚀 Запускаю обновленного бота...${NC}"
cd docker
if docker-compose up -d --build; then
    echo -e "${GREEN}✅ Бот успешно обновлен и запущен!${NC}"
else
    echo -e "${RED}❌ Ошибка при запуске бота!${NC}"
    echo "   Проверьте логи: cd docker && docker-compose logs"
    exit 1
fi
cd ..

# 12. Убираем за собой временную папку
rm -rf "$TEMP_DIR" /tmp/migrate_db.py.bak 2>/dev/null

echo ""
echo -e "${GREEN}✅ Обновление завершено!${NC}"
echo -e "${BLUE}📊 Информация:${NC}"
echo "   • Резервная копия: $BACKUP_FILE"
echo "   • Миграция БД: выполнена"
echo "   • Логи: cd docker && docker-compose logs -f"
