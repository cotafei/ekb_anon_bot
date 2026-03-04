 # EKB Anonymous Bot
 
 ![Python 3.10+](https://img.shields.io/badge/Python-3.10+-blue.svg)
 ![aiogram 3.x](https://img.shields.io/badge/aiogram-3.x-green.svg)
 ![SQLite 3](https://img.shields.io/badge/SQLite-3-lightgrey.svg)
 ![Docker](https://img.shields.io/badge/Docker-ready-blue.svg)
 ![Version](https://img.shields.io/badge/Version-1.1.2-orange.svg)
 ![License MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
 ![Windows](https://img.shields.io/badge/Windows-supported-brightgreen.svg)
 ![Linux](https://img.shields.io/badge/Linux-supported-brightgreen.svg)
 
 ## О проекте
 
 EKB Anonymous Bot — это высоконагруженный Telegram-бот для анонимных публикаций в городском сообществе Екатеринбурга. Проект представляет собой полностью готовое решение с системой модерации, геймификацией, внутренней экономикой и полной Docker-поддержкой.
 
 ### Для чего это?
 - Анонимное общение — пользователи делятся мыслями без страха быть узнанными
 - Контроль контента — модераторы фильтруют нежелательные посты
 - Монетизация активности — система поощрения активных пользователей
 - Аналитика — полная статистика постов и пользователей
 
 ## Версии
 
 ### Версия 1.1.2 (текущая)
 - Rate limiting: защита от спама (60 секунд между постами)
 - Проверка размера медиа (до 20MB)
 - Логирование модераторов
 - Контакт поддержки в config (@C0taf31)
 
 ### Версия 1.1.1
 - Docker-поддержка
 - FSM-модерация
 - Скрипты обновления
 - Миграция БД
 
  ### Версия 1.1.0
 - Реферальная система (50/25 монет)
 - Ежедневный бонус (+10 монет)
 - Магазин привилегий
 
 ### Версия 1.0.0
 - Базовая архитектура
 - Модерация постов
 - Фильтрация контента
 
 ## Возможности
 
 ### Для пользователей
 - Анонимные посты (текст, фото, видео)
 - Система монет за активность
 - Реферальная программа: 50 монет за друга, 25 за друга друга
 - Ежедневный бонус: +10 монет каждый день
 - Магазин привилегий
 - Личная статистика
 
 ### Для администраторов
 - FSM-модерация с причиной отказа
 - Список всех постов на модерации
 - Команды /cancel, /skip для быстрой модерации
 - Просмотр детальной информации о посте
 - Глобальная статистика

 ### Безопасность
 - Фильтр мата и оскорблений
 - Блокировка ссылок и контактов
 - Контроль длины поста (20-400 символов)
 - Rate limiting (60 секунд)
 - Проверка размера медиа (до 20MB)
 
 ## Технический стек
 
 | Компонент | Технология |
 |-----------|------------|
 | Язык | Python 3.10+ |
 | Фреймворк | Aiogram 3.x |
 | База данных | SQLite3 |
 | Контейнеризация | Docker, docker-compose |
 | Безопасность | python-dotenv |
 | ОС | Windows / Linux / macOS |
 
 ## Установка и запуск
 
 ### Через Docker (рекомендуется)
 
 ```bash
 git clone https://github.com/cotafei/ekb_anon_bot.git
 cd ekb_anon_bot
 cp .env.example .env
 # Отредактируйте .env (токен, канал, админы)
 
 # Linux/macOS
 chmod +x scripts/run.sh
 ./scripts/run.sh
 
 # Windows
 scripts\run.bat
 ```
 
 ### Локальный запуск без Docker
 
 ```bash
 pip install -r requirements.txt
 python src/main.py
 ```
 
 ## Конфигурация (.env)
 
 ```
 TOKEN=1234567890:ABCdefGHIjklMNOpqrsTUVwxyz
 CHANNEL_ID=-1001234567890
 ADMINS=123456789,987654321
 SUPPORT_CONTACT=@C0taf31
 DB_PATH=data/anon_ekb.db
 ```
 
 ## Структура проекта
 
 ```
  ekb_anon_bot/
 ├── src/                    # Исходный код
 │   ├── main.py
 │   ├── config.py
 │   ├── database.py
 │   ├── admin.py
 │   ├── handlers.py
 │   ├── features.py
 │   ├── filters.py
 │   ├── utils.py
 │   └── migrate_db.py
 ├── docker/                  # Docker файлы
 ├── scripts/                 # Скрипты управления
 ├── data/                    # База данных
 ├── logs/                     # Логи
 ├── backups/                  # Бэкапы
 ├── .env.example
 ├── requirements.txt
 └── README.md
 ```
 
 ## Скрипты управления
 
 | Скрипт | Назначение | Windows | Linux |
 |--------|------------|---------|-------|
 | run | Запуск бота | run.bat | run.sh |
 | stop | Остановка бота | stop.bat | stop.sh |
 | backup | Создание бэкапа | backup.bat | backup.sh |
 | restore | Восстановление | restore.bat | restore.sh |
 | update | Обновление с GitHub | update_from_github.bat | update_from_github.sh |
 
 ## Команды бота
 
 ### Для всех пользователей
 - /start - Начало работы
 - /help - Справка
 - /rules - Правила
 - /stats - Статистика
 - /referral - Рефералы
 - /daily - Бонус
 - /shop - Магазин
 - /cancel - Отмена
 
 ### Для администраторов
 - /moderate - Модерация
 - /admin_stats - Статистика бота
 - /skip - Пропустить модерацию

 ## Экономическая система
 
 ### Заработок монет
 - Приглашение друга: +50 монет
 - Друг пригласил друга: +25 монет
 - Ежедневный бонус: +10 монет
 
 ### Магазин привилегий
 - Срочная модерация: 100 монет
 - Закреп поста: 300 монет
 - Цветной текст: 50 монет
 - Полная анонимность: 200 монет
 
 ## Обновление с GitHub
 
 ```bash
 # Linux/macOS
 ./scripts/update_from_github.sh
 
 # Windows
 scripts\update_from_github.bat
 ```
 
 ## Поддержка
 
 По всем вопросам обращайтесь к автору: @C0taf31
 
 ---
 
 © 2026 EKB Anonymous Bot. Все права защищены.
 Сделано с ❤️ для Екатеринбурга