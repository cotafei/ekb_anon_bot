#!/bin/bash

# ============================================
# MEGA ADMIN CONSOLE v2.0 - EKB Anon Bot
# УЛУЧШЕННАЯ ВЕРСИЯ С НАВИГАЦИЕЙ
# ============================================

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
NC='\033[0m'
BOLD='\033[1m'
BLINK='\033[5m'

cd "$(dirname "$0")/.." || exit 1
PROJECT_ROOT=$(pwd)

# Функция выполнения SQL
exec_sql() {
    docker exec -i ekb-anon-bot sqlite3 /app/data/anon_ekb.db "$1" 2>/dev/null
}

# Функция заголовка
print_header() {
    local title="$1"
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}  ${WHITE}$title${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
}

# Функция подвала
print_footer() {
    echo -e "\n${YELLOW}────────────────────────────────────────${NC}"
    echo -e "${CYAN}0) Назад в главное меню${NC}"
    echo -e "${RED}9) Выход${NC}"
    echo -e "${YELLOW}────────────────────────────────────────${NC}"
}

# Функция проверки статуса (УЛУЧШЕННАЯ)
check_status() {
    echo -e "\n${CYAN}════════════════════════════════════════════${NC}"
    echo -e "${WHITE}📊 СТАТУС БОТА${NC}"
    echo -e "${CYAN}────────────────────────────────────────${NC}"
    
    if docker ps | grep -q ekb-anon-bot; then
        echo -e "   ${GREEN}✅ БОТ РАБОТАЕТ${NC}"
        
        # Получаем метрики
        CPU=$(docker stats --no-stream --format "{{.CPUPerc}}" ekb-anon-bot 2>/dev/null | sed 's/%//')
        MEM=$(docker stats --no-stream --format "{{.MemUsage}}" ekb-anon-bot 2>/dev/null)
        MEM_PERCENT=$(docker stats --no-stream --format "{{.MemPerc}}" ekb-anon-bot 2>/dev/null)
        
        # Цветная индикация CPU
        if (( $(echo "$CPU > 50" | bc -l) )); then
            CPU_COLOR=$RED
        elif (( $(echo "$CPU > 20" | bc -l) )); then
            CPU_COLOR=$YELLOW
        else
            CPU_COLOR=$GREEN
        fi
        echo -e "   💻 CPU: ${CPU_COLOR}${CPU}%${NC}"
        
        # Цветная индикация RAM
        MEM_VAL=$(echo $MEM_PERCENT | sed 's/%//')
        if (( $(echo "$MEM_VAL > 70" | bc -l 2>/dev/null || echo 0) )); then
            MEM_COLOR=$RED
        elif (( $(echo "$MEM_VAL > 40" | bc -l 2>/dev/null || echo 0) )); then
            MEM_COLOR=$YELLOW
        else
            MEM_COLOR=$GREEN
        fi
        echo -e "   🐏 RAM: ${MEM_COLOR}${MEM} (${MEM_PERCENT})${NC}"
        
        UPTIME=$(docker inspect --format='{{.State.StartedAt}}' ekb-anon-bot | xargs date -d 2>/dev/null)
        echo -e "   ⏰ Запущен: $UPTIME"
    else
        echo -e "   ${RED}❌ БОТ ОСТАНОВЛЕН${NC}"
        echo -e "   ${YELLOW}💡 Используй '4' → '1' для запуска${NC}"
    fi
    
    # Статистика БД с индикацией
    TOTAL_USERS=$(exec_sql "SELECT COUNT(*) FROM users;")
    TOTAL_POSTS=$(exec_sql "SELECT COUNT(*) FROM posts;")
    PENDING=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='pending';")
    BANNED=$(exec_sql "SELECT COUNT(*) FROM users WHERE is_banned=1;")
    
    echo -e "\n   👥 Пользователей: ${WHITE}$TOTAL_USERS${NC}"
    
    # Индикация постов
    if [ "$PENDING" -gt 0 ]; then
        echo -e "   📝 Постов: $TOTAL_POSTS ${YELLOW}(+$PENDING в очереди)${NC} ${BLINK}👀${NC}"
    else
        echo -e "   📝 Постов: $TOTAL_POSTS"
    fi
    
    # Индикация банов
    if [ "$BANNED" -gt 0 ]; then
        echo -e "   🔴 Забанено: ${RED}$BANNED${NC}"
    else
        echo -e "   🔴 Забанено: $BANNED"
    fi
}

# Функция отображения прогресс-бара
show_progress() {
    local duration=$1
    local message=$2
    echo -n "$message "
    for i in $(seq 1 20); do
        echo -n "▓"
        sleep $duration
    done
    echo " ✅"
}

# Функция просмотра логов (УЛУЧШЕННАЯ)
show_logs() {
    while true; do
        clear
        print_header "📋 ПРОСМОТР ЛОГОВ"
        
        echo -e "\n${GREEN}1) 📋 Последние 50 строк${NC}"
        echo -e "${GREEN}2) 📅 Логи за сегодня${NC}"
        echo -e "${RED}3) 🔥 Только ошибки${NC}"
        echo -e "${GREEN}4) 📊 Статистика запросов${NC}"
        echo -e "${CYAN}5) 🔄 Логи в реальном времени${NC}"
        echo -e "${GREEN}6) 💾 Сохранить логи в файл${NC}"
        echo -e "${GREEN}7) 🧹 Очистить логи${NC}"
        echo ""
        echo -e "${YELLOW}0) Назад${NC}"
        echo -e "${RED}9) Выход${NC}"
        echo ""
        read -p "Выбери: " log_choice
        
        case $log_choice in
            1) 
                echo -e "\n${CYAN}Последние 50 строк:${NC}"
                cd docker && docker-compose logs --tail=50 --no-log-prefix | cat
                ;;
            2) 
                echo -e "\n${CYAN}Логи за сегодня:${NC}"
                cd docker && docker-compose logs --since="$(date +%Y-%m-%d)" --no-log-prefix | cat
                ;;
            3) 
                echo -e "\n${RED}Ошибки:${NC}"
                cd docker && docker-compose logs --tail=500 --no-log-prefix 2>&1 | grep -i error | grep -v "heartbeat" | cat
                ;;
            4)
                echo -e "\n${CYAN}Статистика запросов:${NC}"
                cd docker && docker-compose logs --tail=1000 --no-log-prefix 2>&1 | grep "handled" | tail -20
                ;;
            5) 
                echo -e "\n${CYAN}Логи в реальном времени (Ctrl+C для выхода):${NC}"
                cd docker && docker-compose logs -f
                ;;
            6)
                LOGFILE="/tmp/bot_logs_$(date +%Y%m%d_%H%M%S).txt"
                cd docker && docker-compose logs --tail=5000 --no-log-prefix > "$LOGFILE"
                echo -e "${GREEN}✅ Логи сохранены в: $LOGFILE${NC}"
                ;;
            7)
                > logs/bot.log
                echo -e "${GREEN}🧹 Логи очищены!${NC}"
                ;;
            9) exit 0 ;;
            0) break ;;
        esac
        cd "$PROJECT_ROOT" || exit
        echo ""
        read -p "Нажми Enter для продолжения..."
    done
}

# Функция управления пользователями (УЛУЧШЕННАЯ)
user_management() {
    while true; do
        clear
        print_header "👥 УПРАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯМИ"
        
        # Показываем краткую статистику
        TOTAL=$(exec_sql "SELECT COUNT(*) FROM users;")
        ACTIVE=$(exec_sql "SELECT COUNT(*) FROM users WHERE is_banned=0;")
        BANNED=$(exec_sql "SELECT COUNT(*) FROM users WHERE is_banned=1;")
        NEW_TODAY=$(exec_sql "SELECT COUNT(*) FROM users WHERE DATE(created_at)=DATE('now');")
        
        echo -e "\n${CYAN}📊 Краткая статистика:${NC}"
        echo -e "   👥 Всего: $TOTAL | ✅ Активных: $ACTIVE | 🔴 Забанено: $BANNED | 🆕 За сегодня: $NEW_TODAY"
        echo -e "${PURPLE}────────────────────────────────────────${NC}"
        
        echo -e "${GREEN}1)  📋 Список пользователей${NC}"
        echo -e "${GREEN}2)  🔍 Поиск пользователя${NC}"
        echo -e "${RED}3)  ⛔ Забанить${NC}"
        echo -e "${GREEN}4)  ✅ Разбанить${NC}"
        echo -e "${RED}5)  📋 Список забаненных${NC}"
        echo -e "${GREEN}6)  💰 Изменить монеты${NC}"
        echo -e "${YELLOW}7)  🏆 Топ по монетам${NC}"
        echo -e "${CYAN}8)  📊 Статистика пользователей${NC}"
        echo -e "${RED}9)  🗑️ Удалить пользователя${NC}"
        echo ""
        echo -e "${YELLOW}0) Назад${NC}"
        echo -e "${RED}99) Выход${NC}"
        echo ""
        read -p "Выбери действие: " user_choice
        
        case $user_choice in
            1) 
                echo -e "\n${CYAN}👥 Последние 30 пользователей:${NC}"
                exec_sql "
                SELECT 
                    u.id,
                    COALESCE(u.username, '—'),
                    COALESCE(up.points, 0),
                    u.posts_count,
                    CASE WHEN u.is_banned = 1 THEN '🔴' ELSE '✅' END,
                    DATE(u.created_at)
                FROM users u
                LEFT JOIN user_points up ON u.id = up.user_id
                ORDER BY u.id DESC
                LIMIT 30;
                " | column -t -s '|'
                ;;
            2)
                read -p "Введи ID или username: " query
                echo -e "\n${CYAN}Результаты поиска:${NC}"
                exec_sql "
                SELECT 
                    u.id,
                    u.username,
                    u.first_name,
                    u.last_name,
                    COALESCE(up.points, 0),
                    u.posts_count,
                    u.referrer_id,
                    u.created_at,
                    CASE WHEN u.is_banned = 1 THEN 'ДА' ELSE 'НЕТ' END,
                    COALESCE(u.ban_reason, '—')
                FROM users u
                LEFT JOIN user_points up ON u.id = up.user_id
                WHERE u.id = '$query' OR u.username LIKE '%$query%' OR u.first_name LIKE '%$query%';
                " | while IFS="|" read -r id username fn ln points posts ref created banned reason; do
                    echo -e "\n${WHITE}════════════════════════════════════${NC}"
                    echo -e "${WHITE}👤 ИНФОРМАЦИЯ О ПОЛЬЗОВАТЕЛЕ${NC}"
                    echo -e "${WHITE}════════════════════════════════════${NC}"
                    echo -e "${GREEN}🆔 ID:${NC} $id"
                    echo -e "${GREEN}📧 Username:${NC} @$username"
                    echo -e "${GREEN}📛 Имя:${NC} $fn $ln"
                    echo -e "${YELLOW}💰 Монеты:${NC} $points"
                    echo -e "${CYAN}📝 Постов:${NC} $posts"
                    echo -e "${PURPLE}👥 Реферер:${NC} $ref"
                    echo -e "${BLUE}📅 Регистрация:${NC} $created"
                    
                    if [ "$banned" = "ДА" ]; then
                        echo -e "${RED}⛔ Статус: ЗАБАНЕН${NC}"
                        echo -e "${RED}   Причина: $reason${NC}"
                    else
                        echo -e "${GREEN}✅ Статус: Активен${NC}"
                    fi
                done
                ;;
            3)
                echo -e "\n${RED}⛔ БАН ПОЛЬЗОВАТЕЛЯ${NC}"
                read -p "ID пользователя: " user_id
                # Проверяем существует ли
                EXISTS=$(exec_sql "SELECT username FROM users WHERE id=$user_id;")
                if [ -z "$EXISTS" ]; then
                    echo -e "${RED}❌ Пользователь не найден!${NC}"
                else
                    read -p "Причина бана: " reason
                    exec_sql "
                    UPDATE users 
                    SET is_banned=1, ban_reason='$reason', banned_at=CURRENT_TIMESTAMP 
                    WHERE id=$user_id;
                    "
                    echo -e "${GREEN}✅ Пользователь $user_id забанен!${NC}"
                fi
                ;;
            4)
                echo -e "\n${GREEN}✅ РАЗБАН ПОЛЬЗОВАТЕЛЯ${NC}"
                read -p "ID пользователя: " user_id
                exec_sql "UPDATE users SET is_banned=0, ban_reason=NULL WHERE id=$user_id;"
                echo -e "${GREEN}✅ Пользователь $user_id разбанен!${NC}"
                ;;
            5)
                echo -e "\n${RED}⛔ СПИСОК ЗАБАНЕННЫХ:${NC}"
                exec_sql "
                SELECT id, username, ban_reason, datetime(banned_at, 'localtime') 
                FROM users WHERE is_banned=1 
                ORDER BY banned_at DESC;
                " | column -t -s '|'
                if [ $? -ne 0 ]; then
                    echo "Нет забаненных пользователей"
                fi
                ;;
            6)
                echo -e "\n${YELLOW}💰 ИЗМЕНЕНИЕ МОНЕТ${NC}"
                read -p "ID пользователя: " user_id
                CURRENT=$(exec_sql "SELECT points FROM user_points WHERE user_id=$user_id;")
                [ -z "$CURRENT" ] && CURRENT=0
                echo -e "Текущий баланс: ${YELLOW}$CURRENT${NC}"
                read -p "Новый баланс: " new_points
                exec_sql "
                INSERT INTO user_points (user_id, points) VALUES ($user_id, $new_points)
                ON CONFLICT(user_id) DO UPDATE SET points=$new_points;
                "
                echo -e "${GREEN}✅ Баланс изменен: $CURRENT → $new_points${NC}"
                ;;
            7)
                echo -e "\n${YELLOW}🏆 ТОП-10 ПО МОНЕТАМ:${NC}"
                echo -e "${PURPLE}────────────────────────${NC}"
                exec_sql "
                SELECT 
                    u.id, 
                    COALESCE(u.username, '—'), 
                    COALESCE(up.points, 0) 
                FROM users u 
                LEFT JOIN user_points up ON u.id=up.user_id 
                ORDER BY points DESC LIMIT 10;
                " | nl -w3 -s') ' | while read line; do
                    echo -e "${GREEN}$line${NC}"
                done
                ;;
            8)
                echo -e "\n${CYAN}📊 ДЕТАЛЬНАЯ СТАТИСТИКА:${NC}"
                TOTAL=$(exec_sql "SELECT COUNT(*) FROM users;")
                ACTIVE=$(exec_sql "SELECT COUNT(*) FROM users WHERE is_banned=0;")
                BANNED=$(exec_sql "SELECT COUNT(*) FROM users WHERE is_banned=1;")
                WITH_POSTS=$(exec_sql "SELECT COUNT(DISTINCT user_id) FROM posts;")
                WITH_REFERRALS=$(exec_sql "SELECT COUNT(DISTINCT referrer_id) FROM users WHERE referrer_id IS NOT NULL;")
                AVG_POSTS=$(exec_sql "SELECT AVG(posts_count) FROM users;")
                
                echo -e "   👥 Всего пользователей: $TOTAL"
                echo -e "   ✅ Активных: $ACTIVE"
                echo -e "   🔴 Забанено: $BANNED"
                echo -e "   📝 С постами: $WITH_POSTS"
                echo -e "   👥 С рефералами: $WITH_REFERRALS"
                echo -e "   📊 Среднее постов: $AVG_POSTS"
                ;;
            9)
                echo -e "\n${RED}⚠️ УДАЛЕНИЕ ПОЛЬЗОВАТЕЛЯ${NC}"
                read -p "ID пользователя: " user_id
                USER_INFO=$(exec_sql "SELECT username FROM users WHERE id=$user_id;")
                if [ -n "$USER_INFO" ]; then
                    echo -e "${RED}Пользователь: @$USER_INFO${NC}"
                    read -p "${RED}ТОЧНО УДАЛИТЬ? (напиши YES): ${NC}" confirm
                    if [ "$confirm" = "YES" ]; then
                        show_progress 0.05 "Удаление данных..."
                        exec_sql "DELETE FROM posts WHERE user_id=$user_id;"
                        exec_sql "DELETE FROM user_points WHERE user_id=$user_id;"
                        exec_sql "DELETE FROM points_log WHERE user_id=$user_id;"
                        exec_sql "DELETE FROM users WHERE id=$user_id;"
                        echo -e "${GREEN}✅ Пользователь удален!${NC}"
                    fi
                else
                    echo -e "${RED}❌ Пользователь не найден!${NC}"
                fi
                ;;
            99) exit 0 ;;
            0) break ;;
        esac
        echo ""
        read -p "Нажми Enter для продолжения..."
    done
}

# Функция быстрых действий
quick_actions() {
    while true; do
        clear
        print_header "⚡ БЫСТРЫЕ ДЕЙСТВИЯ"
        
        PENDING_COUNT=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='pending';")
        
        echo -e "\n${GREEN}1) 🔄 Перезапустить бота${NC}"
        echo -e "${GREEN}2) 📦 Создать бэкап${NC}"
        echo -e "${RED}3) 🔥 Посмотреть ошибки${NC}"
        
        if [ "$PENDING_COUNT" -gt 0 ]; then
            echo -e "${YELLOW}4) ✅ Одобрить все посты (${PENDING_COUNT} шт)${NC}"
        else
            echo -e "${GRAY}4) ✅ Одобрить все посты (нет в очереди)${NC}"
        fi
        
        echo -e "${CYAN}5) 📊 Показать метрики${NC}"
        echo -e "${PURPLE}6) 🔌 Проверить подключения${NC}"
        echo ""
        echo -e "${YELLOW}0) Назад${NC}"
        echo -e "${RED}9) Выход${NC}"
        echo ""
        read -p "Выбери: " quick_choice
        
        case $quick_choice in
            1)
                show_progress 0.1 "Перезапуск бота"
                cd docker && docker-compose restart && cd "$PROJECT_ROOT"
                echo -e "${GREEN}✅ Бот перезапущен!${NC}"
                ;;
            2)
                ./scripts/backup.sh
                ;;
            3)
                echo -e "\n${RED}Последние ошибки:${NC}"
                cd docker && docker-compose logs --tail=200 --no-log-prefix 2>&1 | grep -i error | tail -20
                ;;
            4)
                if [ "$PENDING_COUNT" -gt 0 ]; then
                    exec_sql "UPDATE posts SET status='approved', moderated_at=CURRENT_TIMESTAMP WHERE status='pending';"
                    echo -e "${GREEN}✅ Одобрено $PENDING_COUNT постов!${NC}"
                else
                    echo -e "${YELLOW}⚠️ Нет постов на модерации${NC}"
                fi
                ;;
            5)
                echo -e "\n${CYAN}📊 МЕТРИКИ:${NC}"
                echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
                echo "RAM: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
                echo "DISK: $(df -h . | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
                echo "Docker: $(docker ps -q | wc -l) контейнеров"
                ;;
            6)
                echo -e "\n${CYAN}🔌 ПРОВЕРКА ПОДКЛЮЧЕНИЙ:${NC}"
                echo -n "Telegram API: "
                docker exec ekb-anon-bot python -c "import requests; print('✅ OK' if requests.get('https://api.telegram.org').status_code==200 else '❌ FAIL')" 2>/dev/null
                echo -n "База данных: "
                docker exec ekb-anon-bot python -c "import sqlite3; conn=sqlite3.connect('data/anon_ekb.db'); print('✅ OK'); conn.close()" 2>/dev/null
                ;;
            9) exit 0 ;;
            0) break ;;
        esac
        echo ""
        read -p "Нажми Enter для продолжения..."
    done
}

# ГЛАВНОЕ МЕНЮ
while true; do
    clear
    echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}          ${WHITE}🔥 MEGA ADMIN CONSOLE v2.0 🔥${NC}                ${BLUE}║${NC}"
    echo -e "${BLUE}║${NC}              ${CYAN}⚡ УПРАВЛЯЙ БОТОМ С УДОВОЛЬСТВИЕМ ⚡${NC}          ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
    
    check_status
    
    echo -e "\n${PURPLE}════════════════════════════════════════════${NC}"
    echo -e "${WHITE}ГЛАВНОЕ МЕНЮ${NC}"
    echo -e "${PURPLE}────────────────────────────────────────${NC}"
    echo -e "${GREEN}1)  👥 Управление пользователями${NC}"
    echo -e "${GREEN}2)  📝 Управление постами${NC}"
    echo -e "${YELLOW}3)  💰 Управление монетами${NC}"
    echo -e "${CYAN}4)  ⚙️ Системные операции${NC}"
    echo -e "${PURPLE}5)  📊 Статистика и аналитика${NC}"
    echo -e "${BLUE}6)  📋 Просмотр логов${NC}"
    echo -e "${WHITE}7)  ⚡ Быстрые действия${NC}"
    echo -e "${RED}8)  🛠️ Диагностика${NC}"
    echo -e "${PURPLE}────────────────────────────────────────${NC}"
    echo -e "${RED}9)  🚪 Выход${NC}"
    echo ""
    read -p "Выбери раздел [1-9]: " main_choice
    
    case $main_choice in
        1) user_management ;;
        2) post_management ;;
        3) points_management ;;
        4) system_operations ;;
        5) stats_analytics ;;
        6) show_logs ;;
        7) quick_actions ;;
        8)
            echo -e "\n${CYAN}🛠️ ДИАГНОСТИКА:${NC}"
            echo -e "${PURPLE}────────────────────────${NC}"
            
            # Проверка контейнера
            echo -n "🐳 Docker контейнер: "
            if docker ps | grep -q ekb-anon-bot; then
                echo -e "${GREEN}✅ РАБОТАЕТ${NC}"
            else
                echo -e "${RED}❌ ОСТАНОВЛЕН${NC}"
            fi
            
            # Проверка API Telegram
            echo -n "📡 Telegram API: "
            if docker exec ekb-anon-bot python -c "import requests; requests.get('https://api.telegram.org', timeout=5)" 2>/dev/null; then
                echo -e "${GREEN}✅ ДОСТУПНО${NC}"
            else
                echo -e "${RED}❌ НЕТ СВЯЗИ${NC}"
            fi
            
            # Проверка БД
            echo -n "💾 База данных: "
            if docker exec ekb-anon-bot python -c "import sqlite3; sqlite3.connect('data/anon_ekb.db')" 2>/dev/null; then
                echo -e "${GREEN}✅ ОК${NC}"
                # Размер БД
                DB_SIZE=$(docker exec ekb-anon-bot ls -lh data/anon_ekb.db | awk '{print $5}')
                echo "   📊 Размер БД: $DB_SIZE"
            else
                echo -e "${RED}❌ ОШИБКА${NC}"
            fi
            
            # Проверка дискового пространства
            echo -n "💽 Диск: "
            DISK_USAGE=$(df -h . | awk 'NR==2 {print $5}' | sed 's/%//')
            if [ "$DISK_USAGE" -gt 90 ]; then
                echo -e "${RED}⚠️  ЗАНЯТО $DISK_USAGE%${NC}"
            elif [ "$DISK_USAGE" -gt 70 ]; then
                echo -e "${YELLOW}⚠️  ЗАНЯТО $DISK_USAGE%${NC}"
            else
                echo -e "${GREEN}✅ ЗАНЯТО $DISK_USAGE%${NC}"
            fi
            ;;
        9)
            echo -e "\n${GREEN}👋 До свидания! Бот продолжает работать в фоне.${NC}"
            echo -e "${YELLOW}💡 Для остановки бота используй: scripts/stop.sh${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Неверный выбор!${NC}"
            sleep 1
            ;;
    esac
    
    echo ""
    read -p "Нажми Enter для продолжения..."
done
