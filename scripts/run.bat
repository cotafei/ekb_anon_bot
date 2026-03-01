@echo off
chcp 65001 > nul
cd /d %~dp0..
echo ========================================
echo    EKB Anon Bot - Запуск на Windows
echo ========================================
echo.

REM Создаем директории
if not exist data mkdir data
if not exist logs mkdir logs
if not exist backups mkdir backups

echo [OK] Директории созданы
echo.

REM Проверяем .env
if not exist .env (
    echo [ERROR] Файл .env не найден!
    echo Скопируйте .env.example в .env и заполните данные
    pause
    exit /b 1
)

REM Запускаем через Docker
echo [INFO] Запуск бота...
docker-compose -f docker/docker-compose.yml up -d --build

echo.
echo [OK] Бот запущен!
echo [INFO] Для просмотра логов: docker-compose -f docker/docker-compose.yml logs -f
pause