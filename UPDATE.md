 # Инструкция по обновлению EKB Anonymous Bot
 
 ## Быстрое обновление (рекомендуется)
 
 ### Linux/macOS
 ```bash
 cd /путь/к/проекту
 chmod +x scripts/update_from_github.sh
 ./scripts/update_from_github.sh
 ```
 
 ### Windows
 ```batch
 cd /путь/к/проекту
 scripts\update_from_github.bat
 ```
 
 ## Что делает скрипт обновления?
 
 **Автоматически:**
 1. Создает резервную копию (data/, logs/, .env)
 2. Скачивает последнюю версию с GitHub
 3. Сохраняет ваш скрипт миграции
 4. Обновляет файлы проекта
 5. Запускает миграцию БД
 6. Перезапускает бота
 
 **Сохраняет:**
 - Базу данных (все посты, пользователи, монеты)
 - Логи
 - Файл .env с токенами
 - Ваши личные настройки
 
 ## Ручное обновление
 
 ### 1. Сделайте бэкап
 ```bash
 cp -r data backups/data_$(date +%Y%m%d)
 cp .env .env.backup
 ```
 
 ### 2. Скачайте новую версию
 ```bash
 git pull origin main
 # или
 git clone https://github.com/cotafei/ekb_anon_bot.git ekb_anon_bot_new
 ```
 
 ### 3. Обновите структуру БД
 ```bash
 cd src
 python migrate_db.py
 ```
 
 ### 4. Перезапустите бота
 ```bash
 cd ../docker && docker-compose down && docker-compose up -d --build
 ```
 
 ## История версий
 
 | Версия | Дата | Ключевые изменения |
 |--------|------|-------------------|
 | 1.1.2 | 04.03.2026 | Rate limiting, проверка медиа, логи модераторов |
 | 1.1.1 | 03.03.2026 | Исправление багов, скрипт обновления, миграция БД |
 | 1.1.0 | 02.03.2026 | Docker, FSM, монеты, рефералы, бэкапы |
 | 1.0.0 | 27.02.2026 | Первый релиз |
 
 ## Проверка версии
 
 ```bash
 # Проверьте версию в main.py
 grep "Версия:" src/main.py
 
 # Посмотрите логи
 cd docker && docker-compose logs -f
 ```
 
 ## Если что-то пошло не так
 
 ### Восстановление из бэкапа
 ```bash
 # Linux/macOS
 ./scripts/restore.sh
 
 # Windows
 scripts\restore.bat
 ```
 
 ### Откат к предыдущей версии
 ```bash
 # 1. Остановите бота
 cd docker && docker-compose down
 
 # 2. Восстановите файлы из бэкапа
 tar -xzf backups/pre_update_backup_*.tar.gz
 
 # 3. Запустите бота
 cd docker && docker-compose up -d
 ```
 
 ## Нужна помощь?
 
 Если возникли проблемы:
 - Проверьте `.env` файл
 - Посмотрите логи: `cd docker && docker-compose logs -f`
 - Создайте Issue на GitHub

 
 ---
 
 **Совет:** Перед обновлением всегда делайте бэкап! Скрипт делает это автоматически, но лишняя копия не помешает.