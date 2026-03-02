"""
Конфигурационный файл бота EKB Anon Bot
Версия: 1.1.1
"""

import os
from pathlib import Path
from dotenv import load_dotenv

# Загружаем переменные окружения из .env файла
load_dotenv()

# Корневые директории проекта
BASE_DIR = Path(__file__).parent.parent  # Корень проекта
DATA_DIR = BASE_DIR / 'data'              # Папка для базы данных
LOG_DIR = BASE_DIR / 'logs'                # Папка для логов

# Создаем необходимые папки при их отсутствии
DATA_DIR.mkdir(exist_ok=True, parents=True)
LOG_DIR.mkdir(exist_ok=True, parents=True)

# Токен бота (обязательный параметр)
TOKEN = os.getenv('TOKEN')
if not TOKEN:
    raise ValueError("❌ TOKEN не найден в .env")

# ID канала для публикации (обязательный параметр)
CHANNEL_ID = os.getenv('CHANNEL_ID')
if not CHANNEL_ID:
    raise ValueError("❌ CHANNEL_ID не найден в .env")
CHANNEL_ID = int(CHANNEL_ID)

# ID администраторов (обязательный параметр)
ADMINS_STR = os.getenv('ADMINS')
if not ADMINS_STR:
    raise ValueError("❌ ADMINS не найдены в .env")
ADMINS = [int(x.strip()) for x in ADMINS_STR.split(',') if x.strip()]

# Путь к файлу базы данных SQLite
DB_PATH = str(DATA_DIR / 'anon_ekb.db')

# Настройки ограничений для постов
MAX_POST_LENGTH = 400      # Максимальная длина текста
MIN_POST_LENGTH = 20       # Минимальная длина текста
MAX_MEDIA_SIZE = 20 * 1024 * 1024  # Максимальный размер медиафайлов (20MB)

# Настройки реферальной системы
REFERRAL_BONUS = 50  # Количество монет за приглашенного друга