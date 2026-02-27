import os
from dotenv import load_dotenv

# Загружаем переменные окружения из .env файла
load_dotenv()

# Токен бота - обязательная переменная
TOKEN = os.getenv('TOKEN')
if not TOKEN:
    raise ValueError("❌ Токен бота не найден! Создайте файл .env с переменной TOKEN")

# ID канала - обязательная переменная
CHANNEL_ID = os.getenv('CHANNEL_ID')
if not CHANNEL_ID:
    raise ValueError("❌ ID канала не найден! Создайте файл .env с переменной CHANNEL_ID")
CHANNEL_ID = int(CHANNEL_ID)

# ID администраторов - обязательная переменная
ADMINS_STR = os.getenv('ADMINS')
if not ADMINS_STR:
    raise ValueError("❌ Список администраторов не найден! Создайте файл .env с переменной ADMINS")
ADMINS = [int(x.strip()) for x in ADMINS_STR.split(',') if x.strip()]

# Путь к базе данных
DB_PATH = os.getenv('DB_PATH', 'anon_ekb.db')

# Настройки
MAX_POST_LENGTH = 400
MIN_POST_LENGTH = 20
MAX_MEDIA_SIZE = 20 * 1024 * 1024  # 20MB

# Бонус за реферала
REFERRAL_BONUS = 50