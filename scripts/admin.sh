#!/bin/bash

# ============================================
# MEGA ADMIN CONSOLE v2.0 - EKB Anon Bot
# ПОЛНАЯ ВЕРСИЯ СО ВСЕМИ ФУНКЦИЯМИ
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
        if (( $(echo "$CPU > 50" | bc -l 2>/dev/null || echo 0) )); then
            CPU_COLOR=$RED
        elif (( $(echo "$CPU > 20" | bc -l 2>/dev/null || echo 0) )); then
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

# ============================================
# ФУНКЦИЯ УПРАВЛЕНИЯ ПОСТАМИ
# ============================================
post_management() {
    while true; do
        clear
        print_header "📝 УПРАВЛЕНИЕ ПОСТАМИ"
        
        # Показываем краткую статистику
        TOTAL=$(exec_sql "SELECT COUNT(*) FROM posts;")
        APPROVED=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='approved';")
        REJECTED=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='rejected';")
        PENDING=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='pending';")
        
        echo -e "\n${CYAN}📊 Статистика постов:${NC}"
        echo -e "   📝 Всего: $TOTAL | ✅ Одобрено: $APPROVED | ❌ Отклонено: $REJECTED | ⏳ В очереди: ${YELLOW}$PENDING${NC}"
        echo -e "${PURPLE}────────────────────────────────────────${NC}"
        
        echo -e "${YELLOW}1)  ⏳ Ожидают модерации${NC}"
        echo -e "${GREEN}2)  📋 Все посты${NC}"
        echo -e "${CYAN}3)  🔍 Поиск поста${NC}"
        echo -e "${GREEN}4)  ✅ Одобрить пост${NC}"
        echo -e "${RED}5)  ❌ Отклонить пост${NC}"
        echo -e "${RED}6)  🗑️ Удалить пост${NC}"
        echo -e "${CYAN}7)  📊 Детальная статистика${NC}"
        echo -e "${GREEN}8)  🔄 Массовое одобрение${NC}"
        echo -e "${BLUE}9)  📈 Посты по дням${NC}"
        echo ""
        echo -e "${YELLOW}0) Назад${NC}"
        echo -e "${RED}99) Выход${NC}"
        echo ""
        read -p "Выбери действие: " post_choice
        
        case $post_choice in
            1)
                echo -e "\n${YELLOW}⏳ ПОСТЫ НА МОДЕРАЦИИ:${NC}"
                exec_sql "
                SELECT id, user_id, substr(content,1,70), datetime(created_at, 'localtime') 
                FROM posts WHERE status='pending' 
                ORDER BY created_at;
                " | while IFS="|" read -r id user content date; do
                    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                    echo -e "🆔 #$id | 👤 $user | 📅 $date"
                    echo -e "📝 $content..."
                done
                ;;
            2)
                echo -e "\n${CYAN}📋 ВСЕ ПОСТЫ (последние 30):${NC}"
                exec_sql "
                SELECT 
                    id, 
                    user_id, 
                    status,
                    CASE status 
                        WHEN 'approved' THEN '✅' 
                        WHEN 'rejected' THEN '❌' 
                        ELSE '⏳' 
                    END,
                    substr(content,1,40), 
                    datetime(created_at, 'localtime')
                FROM posts ORDER BY id DESC LIMIT 30;
                " | column -t -s '|'
                ;;
            3)
                read -p "Введи ID поста: " post_id
                echo -e "\n${CYAN}🔍 ПОСТ #$post_id${NC}"
                exec_sql "SELECT * FROM posts WHERE id=$post_id;" | while IFS="|" read -r id user content media_type media_id status created moderated moderated_by; do
                    echo -e "${WHITE}════════════════════════════════════${NC}"
                    echo -e "${GREEN}🆔 ID:${NC} $id"
                    echo -e "${GREEN}👤 Автор:${NC} $user"
                    echo -e "${GREEN}📊 Статус:${NC} $( [ "$status" = "approved" ] && echo "✅ Одобрен" || [ "$status" = "rejected" ] && echo "❌ Отклонен" || echo "⏳ В очереди" )"
                    echo -e "${GREEN}🎨 Тип:${NC} ${media_type:-текст}"
                    echo -e "${GREEN}📅 Создан:${NC} $created"
                    echo -e "${GREEN}🕒 Модерирован:${NC} ${moderated:-нет}"
                    echo -e "${GREEN}👮 Модератор:${NC} ${moderated_by:-нет}"
                    echo -e "${WHITE}────────────────────────${NC}"
                    echo -e "${CYAN}📝 Текст:${NC}\n$content"
                done
                ;;
            4)
                read -p "ID поста для одобрения: " post_id
                exec_sql "UPDATE posts SET status='approved', moderated_at=CURRENT_TIMESTAMP WHERE id=$post_id AND status='pending';"
                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}✅ Пост #$post_id одобрен!${NC}"
                else
                    echo -e "${RED}❌ Ошибка или пост уже обработан${NC}"
                fi
                ;;
            5)
                read -p "ID поста для отклонения: " post_id
                exec_sql "UPDATE posts SET status='rejected', moderated_at=CURRENT_TIMESTAMP WHERE id=$post_id AND status='pending';"
                if [ $? -eq 0 ]; then
                    echo -e "${RED}❌ Пост #$post_id отклонен!${NC}"
                else
                    echo -e "${RED}❌ Ошибка или пост уже обработан${NC}"
                fi
                ;;
            6)
                read -p "ID поста для удаления: " post_id
                read -p "${RED}ТОЧНО УДАЛИТЬ? (yes): ${NC}" confirm
                if [ "$confirm" = "yes" ]; then
                    exec_sql "DELETE FROM posts WHERE id=$post_id;"
                    echo -e "${RED}🗑️ Пост #$post_id удален!${NC}"
                fi
                ;;
            7)
                echo -e "\n${CYAN}📊 ДЕТАЛЬНАЯ СТАТИСТИКА ПОСТОВ:${NC}"
                TOTAL=$(exec_sql "SELECT COUNT(*) FROM posts;")
                APPROVED=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='approved';")
                REJECTED=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='rejected';")
                PENDING=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='pending';")
                WITH_MEDIA=$(exec_sql "SELECT COUNT(*) FROM posts WHERE media_type IS NOT NULL;")
                WITHOUT_MEDIA=$(exec_sql "SELECT COUNT(*) FROM posts WHERE media_type IS NULL;")
                
                echo -e "   📊 Всего постов: $TOTAL"
                echo -e "   ✅ Одобрено: $APPROVED ($(echo "scale=2; $APPROVED*100/$TOTAL" | bc 2>/dev/null)%)"
                echo -e "   ❌ Отклонено: $REJECTED ($(echo "scale=2; $REJECTED*100/$TOTAL" | bc 2>/dev/null)%)"
                echo -e "   ⏳ В очереди: $PENDING"
                echo -e "   🎨 С медиа: $WITH_MEDIA"
                echo -e "   📝 Текст: $WITHOUT_MEDIA"
                ;;
            8)
                PENDING=$(exec_sql "SELECT COUNT(*) FROM posts WHERE status='pending';")
                if [ "$PENDING" -gt 0 ]; then
                    read -p "Одобрить все $PENDING постов? (yes): " confirm
                    if [ "$confirm" = "yes" ]; then
                        exec_sql "UPDATE posts SET status='approved', moderated_at=CURRENT_TIMESTAMP WHERE status='pending';"
                        echo -e "${GREEN}✅ Одобрено $PENDING постов!${NC}"
                    fi
                else
                    echo -e "${YELLOW}⚠️ Нет постов на модерации${NC}"
                fi
                ;;
            9)
                echo -e "\n${CYAN}📈 ПОСТЫ ПО ДНЯМ (последние 14 дней):${NC}"
                exec_sql "
                SELECT 
                    DATE(created_at) as date,
                    COUNT(*) as total,
                    SUM(CASE WHEN status='approved' THEN 1 ELSE 0 END) as approved,
                    SUM(CASE WHEN status='rejected' THEN 1 ELSE 0 END) as rejected
                FROM posts 
                GROUP BY DATE(created_at)
                ORDER BY date DESC
                LIMIT 14;
                " | column -t -s '|'
                ;;
            99) exit 0 ;;
            0) break ;;
        esac
        echo ""
        read -p "Нажми Enter для продолжения..."
    done
}

# ============================================
# ФУНКЦИЯ УПРАВЛЕНИЯ МОНЕТАМИ
# ============================================
points_management() {
    while true; do
        clear
        print_header "💰 УПРАВЛЕНИЕ МОНЕТАМИ"
        
        # Показываем общую статистику
        TOTAL_POOL=$(exec_sql "SELECT SUM(points) FROM user_points;")
        [ -z "$TOTAL_POOL" ] && TOTAL_POOL=0
        AVG_BALANCE=$(exec_sql "SELECT AVG(points) FROM user_points;")
        [ -z "$AVG_BALANCE" ] && AVG_BALANCE=0
        MAX_BALANCE=$(exec_sql "SELECT MAX(points) FROM user_points;")
        [ -z "$MAX_BALANCE" ] && MAX_BALANCE=0
        
        echo -e "\n${CYAN}💰 Общая статистика:${NC}"
        echo -e "   💰 Всего монет: ${YELLOW}$TOTAL_POOL${NC}"
        echo -e "   📊 Средний баланс: $AVG_BALANCE"
        echo -e "   🏆 Макс. баланс: $MAX_BALANCE"
        echo -e "${PURPLE}────────────────────────────────────────${NC}"
        
        echo -e "${GREEN}1)  💰 Начислить всем${NC}"
        echo -e "${GREEN}2)  💰 Начислить пользователю${NC}"
        echo -e "${RED}3)  💸 Списать у пользователя${NC}"
        echo -e "${YELLOW}4)  🔄 Обнулить баланс${NC}"
        echo -e "${CYAN}5)  📜 История начислений${NC}"
        echo -e "${YELLOW}6)  🏆 Топ по монетам${NC}"
        echo -e "${BLUE}7)  📊 Детальная статистика${NC}"
        echo ""
        echo -e "${YELLOW}0) Назад${NC}"
        echo -e "${RED}99) Выход${NC}"
        echo ""
        read -p "Выбери действие: " points_choice
        
        case $points_choice in
            1)
                read -p "Сумма для всех пользователей: " amount
                read -p "Причина начисления: " reason
                show_progress 0.05 "Начисление монет"
                exec_sql "
                INSERT INTO user_points (user_id, points) 
                SELECT id, $amount FROM users WHERE is_banned=0
                ON CONFLICT(user_id) DO UPDATE SET points = points + $amount;
                INSERT INTO points_log (user_id, points, reason) 
                SELECT id, $amount, '$reason' FROM users WHERE is_banned=0;
                "
                echo -e "${GREEN}✅ Начислено $amount монет всем активным пользователям!${NC}"
                ;;
            2)
                read -p "ID пользователя: " user_id
                CURRENT=$(exec_sql "SELECT points FROM user_points WHERE user_id=$user_id;")
                [ -z "$CURRENT" ] && CURRENT=0
                echo -e "Текущий баланс: ${YELLOW}$CURRENT${NC}"
                read -p "Сумма начисления: " amount
                read -p "Причина: " reason
                exec_sql "
                INSERT INTO user_points (user_id, points) VALUES ($user_id, $amount)
                ON CONFLICT(user_id) DO UPDATE SET points = points + $amount;
                INSERT INTO points_log (user_id, points, reason) VALUES ($user_id, $amount, '$reason');
                "
                echo -e "${GREEN}✅ Начислено $amount монет пользователю $user_id!${NC}"
                ;;
            3)
                read -p "ID пользователя: " user_id
                CURRENT=$(exec_sql "SELECT points FROM user_points WHERE user_id=$user_id;")
                [ -z "$CURRENT" ] && CURRENT=0
                echo -e "Текущий баланс: ${YELLOW}$CURRENT${NC}"
                read -p "Сумма списания: " amount
                read -p "Причина: " reason
                if [ "$amount" -gt "$CURRENT" ]; then
                    echo -e "${RED}❌ Недостаточно монет! Баланс: $CURRENT${NC}"
                else
                    exec_sql "
                    UPDATE user_points SET points = points - $amount WHERE user_id=$user_id;
                    INSERT INTO points_log (user_id, points, reason) VALUES ($user_id, -$amount, '$reason');
                    "
                    echo -e "${GREEN}✅ Списано $amount монет у пользователя $user_id!${NC}"
                fi
                ;;
            4)
                read -p "ID пользователя: " user_id
                read -p "${RED}ОБНУЛИТЬ БАЛАНС? (yes): ${NC}" confirm
                if [ "$confirm" = "yes" ]; then
                    CURRENT=$(exec_sql "SELECT points FROM user_points WHERE user_id=$user_id;")
                    exec_sql "UPDATE user_points SET points=0 WHERE user_id=$user_id;"
                    exec_sql "INSERT INTO points_log (user_id, points, reason) VALUES ($user_id, -$CURRENT, 'admin_reset');"
                    echo -e "${YELLOW}🔄 Баланс пользователя $user_id обнулен!${NC}"
                fi
                ;;
            5)
                echo -e "\n${CYAN}📜 ПОСЛЕДНИЕ ОПЕРАЦИИ:${NC}"
                exec_sql "
                SELECT 
                    datetime(created_at, 'localtime'),
                    user_id,
                    points,
                    reason
                FROM points_log 
                ORDER BY created_at DESC 
                LIMIT 30;
                " | while IFS="|" read -r date user points reason; do
                    if [ "$points" -gt 0 ]; then
                        echo -e "${GREEN}[$date] User $user: +$points ($reason)${NC}"
                    else
                        echo -e "${RED}[$date] User $user: $points ($reason)${NC}"
                    fi
                done
                ;;
            6)
                echo -e "\n${YELLOW}🏆 ТОП ПО МОНЕТАМ:${NC}"
                echo -e "${PURPLE}────────────────────────${NC}"
                exec_sql "
                SELECT 
                    u.id,
                    COALESCE(u.username, '—'),
                    COALESCE(up.points, 0),
                    u.posts_count
                FROM users u 
                LEFT JOIN user_points up ON u.id=up.user_id 
                ORDER BY points DESC LIMIT 15;
                " | nl -w3 -s') ' | while read line; do
                    echo -e "${GREEN}$line${NC}"
                done
                ;;
            7)
                echo -e "\n${BLUE}📊 ДЕТАЛЬНАЯ СТАТИСТИКА:${NC}"
                TOTAL_USERS=$(exec_sql "SELECT COUNT(*) FROM users;")
                USERS_WITH_POINTS=$(exec_sql "SELECT COUNT(*) FROM user_points;")
                TOTAL_POOL=$(exec_sql "SELECT SUM(points) FROM user_points;")
                AVG=$(exec_sql "SELECT AVG(points) FROM user_points;")
                MEDIAN=$(exec_sql "SELECT points FROM user_points ORDER BY points LIMIT 1 OFFSET (SELECT COUNT(*)/2 FROM user_points);")
                
                echo -e "   👥 Всего пользователей: $TOTAL_USERS"
                echo -e "   💰 С монетами: $USERS_WITH_POINTS"
                echo -e "   💰 Общий пул: $TOTAL_POOL"
                echo -e "   📊 Средний баланс: $AVG"
                echo -e "   📈 Медианный баланс: $MEDIAN"
                ;;
            99) exit 0 ;;
            0) break ;;
        esac
        echo ""
        read -p "Нажми Enter для продолжения..."
    done
}

# ============================================
# ФУНКЦИЯ СИСТЕМНЫХ ОПЕРАЦИЙ
# ============================================
system_operations() {
    while true; do
        clear
        print_header "⚙️ СИСТЕМНЫЕ ОПЕРАЦИИ"
        
        echo -e "\n${GREEN}1)  🚀 Запустить бота${NC}"
        echo -e "${RED}2)  🛑 Остановить бота${NC}"
        echo -e "${YELLOW}3)  🔄 Перезапустить${NC}"
        echo -e "${BLUE}4)  🏗️ Пересобрать${NC}"
        echo -e "${GREEN}5)  📦 Создать бэкап${NC}"
        echo -e "${CYAN}6)  🔄 Восстановить из бэкапа${NC}"
        echo -e "${PURPLE}7)  🗃️ Миграция БД${NC}"
        echo -e "${YELLOW}8)  🔍 Проверить обновления${NC}"
        echo -e "${RED}9)  🧹 Очистить логи${NC}"
        echo -e "${BLUE}10) 📊 Ресурсы сервера${NC}"
        echo -e "${GREEN}11) 🔌 Переподключить к API${NC}"
        echo ""
        echo -e "${YELLOW}0) Назад${NC}"
        echo -e "${RED}99) Выход${NC}"
        echo ""
        read -p "Выбери действие: " sys_choice
        
        case $sys_choice in
            1)
                show_progress 0.1 "Запуск бота"
                cd docker && docker-compose up -d && cd "$PROJECT_ROOT"
                echo -e "${GREEN}✅ Бот запущен!${NC}"
                ;;
            2)
                show_progress 0.1 "Остановка бота"
                cd docker && docker-compose stop && cd "$PROJECT_ROOT"
                echo -e "${YELLOW}🛑 Бот остановлен!${NC}"
                ;;
            3)
                show_progress 0.1 "Перезапуск бота"
                cd docker && docker-compose restart && cd "$PROJECT_ROOT"
                echo -e "${GREEN}🔄 Бот перезапущен!${NC}"
                ;;
            4)
                show_progress 0.2 "Пересборка бота"
                cd docker && docker-compose down && docker-compose up -d --build && cd "$PROJECT_ROOT"
                echo -e "${GREEN}🏗️ Бот пересобран!${NC}"
                ;;
            5)
                ./scripts/backup.sh
                ;;
            6)
                ./scripts/restore.sh
                ;;
            7)
                echo -e "${YELLOW}🔄 Запуск миграции БД...${NC}"
                docker exec ekb-anon-bot python /app/src/migrate_db.py
                echo -e "${GREEN}✅ Миграция выполнена!${NC}"
                ;;
            8)
                echo -e "${YELLOW}🔍 Проверка обновлений...${NC}"
                git fetch origin
                LOCAL=$(git rev-parse HEAD)
                REMOTE=$(git rev-parse origin/main 2>/dev/null)
                if [ "$LOCAL" = "$REMOTE" ]; then
                    echo -e "${GREEN}✅ Версия актуальна!${NC}"
                else
                    echo -e "${YELLOW}📥 Доступно обновление!${NC}"
                    echo -e "   Локальная: ${LOCAL:0:7}"
                    echo -e "   GitHub: ${REMOTE:0:7}"
                    echo -e "\n${CYAN}Запусти update_from_github.sh для обновления${NC}"
                fi
                ;;
            9)
                > logs/bot.log
                echo -e "${GREEN}🧹 Логи очищены!${NC}"
                ;;
            10)
                echo -e "\n${CYAN}💻 РЕСУРСЫ СЕРВЕРА:${NC}"
                echo -e "${PURPLE}────────────────────────${NC}"
                echo "CPU: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}')%"
                echo "RAM: $(free -h | awk '/^Mem:/ {print $3 "/" $2}')"
                echo "DISK: $(df -h . | awk 'NR==2 {print $3 "/" $2 " (" $5 ")"}')"
                echo "Uptime: $(uptime | awk '{print $3,$4}' | sed 's/,//')"
                echo "Load: $(uptime | awk -F'load average:' '{print $2}')"
                ;;
            11)
                echo -e "${YELLOW}🔌 Переподключение к API...${NC}"
                cd docker && docker-compose restart && cd "$PROJECT_ROOT"
                echo -e "${GREEN}✅ Бот переподключен!${NC}"
                ;;
            99) exit 0 ;;
            0) break ;;
        esac
        echo ""
        read -p "Нажми Enter для продолжения..."
    done
}

# ============================================
# ФУНКЦИЯ СТАТИСТИКИ И АНАЛИТИКИ
# ============================================
stats_analytics() {
    while true; do
        clear
        print_header "📊 СТАТИСТИКА И АНАЛИТИКА"
        
        # Статистика за сегодня
        TODAY=$(date +%Y-%m-%d)
        USERS_TODAY=$(exec_sql "SELECT COUNT(*) FROM users WHERE DATE(created_at)='$TODAY';")
        POSTS_TODAY=$(exec_sql "SELECT COUNT(*) FROM posts WHERE DATE(created_at)='$TODAY';")
        POINTS_TODAY=$(exec_sql "SELECT COALESCE(SUM(points),0) FROM points_log WHERE DATE(created_at)='$TODAY';")
        
        echo -e "\n${GREEN}📊 СТАТИСТИКА ЗА СЕГОДНЯ:${NC}"
        echo -e "   👥 Новых пользователей: $USERS_TODAY"
        echo -e "   📝 Новых постов: $POSTS_TODAY"
        echo -e "   💰 Начислено монет: $POINTS_TODAY"
        echo -e "${PURPLE}────────────────────────────────────────${NC}"
        
        echo -e "${CYAN}1)  📅 Детальная статистика по дням${NC}"
        echo -e "${GREEN}2)  ⏰ Активность по часам${NC}"
        echo -e "${YELLOW}3)  🎨 Типы контента${NC}"
        echo -e "${BLUE}4)  ⏱️ Эффективность модерации${NC}"
        echo -e "${PURPLE}5)  👥 Реферальная статистика${NC}"
        echo -e "${GREEN}6)  🔄 Удержание пользователей${NC}"
        echo -e "${RED}7)  📥 Экспорт в CSV${NC}"
        echo -e "${YELLOW}8)  📊 Полный отчет${NC}"
        echo ""
        echo -e "${YELLOW}0) Назад${NC}"
        echo -e "${RED}99) Выход${NC}"
        echo ""
        read -p "Выбери: " stats_choice
        
        case $stats_choice in
            1)
                echo -e "\n${CYAN}📅 ПОСЛЕДНИЕ 14 ДНЕЙ:${NC}"
                exec_sql "
                SELECT 
                    DATE(created_at) as date,
                    COUNT(DISTINCT user_id) as users,
                    COUNT(*) as posts,
                    SUM(CASE WHEN status='approved' THEN 1 ELSE 0 END) as approved,
                    SUM(CASE WHEN status='rejected' THEN 1 ELSE 0 END) as rejected
                FROM posts 
                GROUP BY DATE(created_at)
                ORDER BY date DESC
                LIMIT 14;
                " | column -t -s '|'
                ;;
            2)
                echo -e "\n${GREEN}⏰ АКТИВНОСТЬ ПО ЧАСАМ:${NC}"
                exec_sql "
                SELECT 
                    strftime('%H', created_at) as hour,
                    COUNT(*) as posts,
                    COUNT(DISTINCT user_id) as users
                FROM posts 
                GROUP BY hour
                ORDER BY hour;
                " | column -t -s '|'
                ;;
            3)
                echo -e "\n${YELLOW}🎨 ТИПЫ КОНТЕНТА:${NC}"
                exec_sql "
                SELECT 
                    COALESCE(media_type, 'text') as type,
                    COUNT(*) as count,
                    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM posts), 1) || '%' as percentage
                FROM posts 
                GROUP BY media_type
                ORDER BY count DESC;
                " | column -t -s '|'
                ;;
            4)
                echo -e "\n${BLUE}⏱️ ЭФФЕКТИВНОСТЬ МОДЕРАЦИИ:${NC}"
                AVG_TIME=$(exec_sql "SELECT AVG(strftime('%s', moderated_at) - strftime('%s', created_at)) / 3600.0 FROM posts WHERE moderated_at IS NOT NULL;")
                FASTEST=$(exec_sql "SELECT MIN(strftime('%s', moderated_at) - strftime('%s', created_at)) / 60.0 FROM posts WHERE moderated_at IS NOT NULL;")
                MODS=$(exec_sql "SELECT COUNT(DISTINCT moderated_by) FROM posts WHERE moderated_by IS NOT NULL;")
                
                echo -e "   ⏱️ Среднее время: ${AVG_TIME:-0} часов"
                echo -e "   ⚡ Самое быстрое: ${FASTEST:-0} минут"
                echo -e "   👮 Модераторов: $MODS"
                ;;
            5)
                echo -e "\n${PURPLE}👥 РЕФЕРАЛЬНАЯ СТАТИСТИКА:${NC}"
                TOTAL_REFS=$(exec_sql "SELECT COUNT(*) FROM users WHERE referrer_id IS NOT NULL;")
                UNIQUE_REFS=$(exec_sql "SELECT COUNT(DISTINCT referrer_id) FROM users WHERE referrer_id IS NOT NULL;")
                TOP_REF=$(exec_sql "
                SELECT referrer_id, COUNT(*) as cnt 
                FROM users 
                WHERE referrer_id IS NOT NULL 
                GROUP BY referrer_id 
                ORDER BY cnt DESC 
                LIMIT 1;
                ")
                
                echo -e "   👥 Всего рефералов: $TOTAL_REFS"
                echo -e "   👤 Уникальных рефереров: $UNIQUE_REFS"
                echo -e "   🏆 Топ реферер: $TOP_REF"
                ;;
            6)
                echo -e "\n${GREEN}🔄 УДЕРЖАНИЕ ПОЛЬЗОВАТЕЛЕЙ:${NC}"
                DAY7=$(exec_sql "SELECT COUNT(DISTINCT user_id) FROM posts WHERE created_at > datetime('now', '-7 days');")
                DAY30=$(exec_sql "SELECT COUNT(DISTINCT user_id) FROM posts WHERE created_at > datetime('now', '-30 days');")
                TOTAL=$(exec_sql "SELECT COUNT(*) FROM users;")
                
                echo -e "   👥 Всего пользователей: $TOTAL"
                echo -e "   📊 Активных за 7 дней: $DAY7 ($(echo "scale=1; $DAY7*100/$TOTAL" | bc 2>/dev/null)%)"
                echo -e "   📊 Активных за 30 дней: $DAY30 ($(echo "scale=1; $DAY30*100/$TOTAL" | bc 2>/dev/null)%)"
                ;;
            7)
                echo -e "${YELLOW}📥 Экспорт данных...${NC}"
                exec_sql ".mode csv
.headers on
SELECT * FROM users;
" > /tmp/users_export_$(date +%Y%m%d).csv
                exec_sql ".mode csv
.headers on
SELECT * FROM posts;
" > /tmp/posts_export_$(date +%Y%m%d).csv
                echo -e "${GREEN}✅ Экспортировано в /tmp/${NC}"
                ls -lh /tmp/*_export_$(date +%Y%m%d).csv
                ;;
            8)
                echo -e "\n${YELLOW}📊 ПОЛНЫЙ ОТЧЕТ:${NC}"
                echo -e "${PURPLE}────────────────────────${NC}"
                
                # Собираем всю статистику
                TOTAL_USERS=$(exec_sql "SELECT COUNT(*) FROM users;")
                TOTAL_POSTS=$(exec_sql "SELECT COUNT(*) FROM posts;")
                TOTAL_POINTS=$(exec_sql "SELECT SUM(points) FROM user_points;")
                AVG_POSTS=$(exec_sql "SELECT AVG(posts_count) FROM users;")
                
                echo -e "👥 Пользователи: $TOTAL_USERS"
                echo -e "📝 Посты: $TOTAL_POSTS"
                echo -e "💰 Монеты: $TOTAL_POINTS"
                echo -e "📊 Среднее постов на пользователя: $AVG_POSTS"
                echo ""
                echo -e "${CYAN}Нажми Enter для полного отчета...${NC}"
                read
                
                # Детальный отчет
                echo -e "\n${WHITE}════════════════════════════════════════════${NC}"
                echo -e "${WHITE}ПОЛЬЗОВАТЕЛИ:${NC}"
                exec_sql "SELECT is_banned, COUNT(*) FROM users GROUP BY is_banned;" | while read line; do
                    [ "$line" = "0|"* ] && echo "✅ Активных: ${line#0|}"
                    [ "$line" = "1|"* ] && echo "🔴 Забанено: ${line#1|}"
                done
                
                echo -e "\n${WHITE}ПОСТЫ:${NC}"
                exec_sql "SELECT status, COUNT(*) FROM posts GROUP BY status;" | while read line; do
                    case $line in
                        "approved|"*) echo "✅ Одобрено: ${line#approved|}" ;;
                        "rejected|"*) echo "❌ Отклонено: ${line#rejected|}" ;;
                        "pending|"*) echo "⏳ В очереди: ${line#pending|}" ;;
                    esac
                done
                ;;
            99) exit 0 ;;
            0) break ;;
        esac
        echo ""
        read -p "Нажми Enter для продолжения..."
    done
}

# ============================================
# ФУНКЦИЯ ПРОСМОТРА ЛОГОВ
# ============================================
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
        echo -e "${RED}7) 🧹 Очистить логи${NC}"
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

# ============================================
# ФУНКЦИЯ УПРАВЛЕНИЯ ПОЛЬЗОВАТЕЛЯМИ
# ============================================
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
                        show_progress 0.05 "Удаление данных"
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

# ============================================
# ФУНКЦИЯ БЫСТРЫХ ДЕЙСТВИЙ
# ============================================
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
        echo -e "${GREEN}7) 💰 Топ-5 по монетам${NC}"
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
                docker exec ekb-anon-bot python -c "import requests; print('✅ OK' if requests.get('https://api.telegram.org').status_code==200 else '❌ FAIL')" 2>/dev/null || echo "❌ FAIL"
                echo -n "База данных: "
                docker exec ekb-anon-bot python -c "import sqlite3; conn=sqlite3.connect('data/anon_ekb.db'); print('✅ OK'); conn.close()" 2>/dev/null || echo "❌ FAIL"
                ;;
            7)
                echo -e "\n${YELLOW}💰 ТОП-5 ПО МОНЕТАМ:${NC}"
                exec_sql "
                SELECT 
                    u.id, 
                    COALESCE(u.username, '—'), 
                    COALESCE(up.points, 0) 
                FROM users u 
                LEFT JOIN user_points up ON u.id=up.user_id 
                ORDER BY points DESC LIMIT 5;
                " | column -t -s '|'
                ;;
            9) exit 0 ;;
            0) break ;;
        esac
        echo ""
        read -p "Нажми Enter для продолжения..."
    done
}

# ============================================
# ГЛАВНОЕ МЕНЮ
# ============================================
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
