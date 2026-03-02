@echo off
chcp 65001 > nul
title EKB Anon Bot Restore
cd /d %~dp0..

echo ========================================
echo    Восстановление из резервной копии
echo ========================================
echo.

set BACKUP_DIR=backups

if not exist %BACKUP_DIR% (
    echo [❌] Директория %BACKUP_DIR% не найдена!
    pause
    exit /b 1
)

echo [📋] Доступные бэкапы:
echo.
dir /b %BACKUP_DIR%\*.tar.gz 2>nul
echo.
if %errorlevel% neq 0 (
    echo [❌] Нет бэкапов для восстановления
    pause
    exit /b 1
)

set /p BACKUP_FILE="Введите имя файла для восстановления: "

if "%BACKUP_FILE%"=="" (
    echo [❌] Имя файла не может быть пустым
    pause
    exit /b 1
)

set FULL_PATH=%BACKUP_DIR%\%BACKUP_FILE%
if not exist "%FULL_PATH%" (
    echo [❌] Файл не найден: %FULL_PATH%
    pause
    exit /b 1
)

echo.
echo [⚠️] ВНИМАНИЕ: Восстановление удалит текущие данные!
set /p CONFIRM="Продолжить? (y/n): "

if /i not "%CONFIRM%"=="y" (
    echo [🛑] Операция отменена
    pause
    exit /b 0
)

echo.
echo [1/4] Остановка бота...
cd docker && docker-compose stop bot >nul 2>&1
cd ..

echo [2/4] Удаление старых данных...
if exist data rmdir /s /q data >nul 2>&1
if exist logs rmdir /s /q logs >nul 2>&1
mkdir data logs >nul 2>&1

echo [3/4] Восстановление из архива...
tar -xzf "%FULL_PATH%" -C ./

if %errorlevel% equ 0 (
    echo [✅] Данные восстановлены из: %FULL_PATH%
    
    echo [4/4] Запуск бота...
    cd docker && docker-compose start bot >nul 2>&1
    cd ..
    
    echo.
    echo [✅] Восстановление завершено
) else (
    echo [❌] Ошибка при восстановлении!
    cd docker && docker-compose start bot >nul 2>&1
    cd ..
)

pause