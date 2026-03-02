"""
Миграция базы данных для обновления со старой версии на новую
Запусти один раз перед новым ботом для сохранения данных
Версия: 1.0.0
"""

import sqlite3
import logging
from database import DB_PATH

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def migrate_database():
    """
    Обновление структуры БД без потери данных
    Добавляет новые поля, которых не было в старой версии
    """
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        logger.info("🔧 Начинаю миграцию базы данных...")
        
        # ===== 1. Обновление таблицы posts =====
        logger.info("📝 Проверка таблицы posts...")
        
        cursor.execute("PRAGMA table_info(posts)")
        columns = [col[1] for col in cursor.fetchall()]
        
        if 'moderated_by' not in columns:
            logger.info("   ➕ Добавляем поле moderated_by в posts")
            cursor.execute("ALTER TABLE posts ADD COLUMN moderated_by INTEGER")
        else:
            logger.info("   ✅ Поле moderated_by уже существует")
        
        # ===== 2. Обновление таблицы users =====
        logger.info("📝 Проверка таблицы users...")
        
        cursor.execute("PRAGMA table_info(users)")
        columns = [col[1] for col in cursor.fetchall()]
        
        new_user_fields = {
            'is_banned': 'INTEGER DEFAULT 0',
            'ban_reason': 'TEXT',
            'banned_at': 'TIMESTAMP'
        }
        
        for field, field_type in new_user_fields.items():
            if field not in columns:
                logger.info(f"   ➕ Добавляем поле {field} в users")
                cursor.execute(f"ALTER TABLE users ADD COLUMN {field} {field_type}")
            else:
                logger.info(f"   ✅ Поле {field} уже существует")
        
        # ===== 3. Обновление таблицы user_points =====
        logger.info("📝 Проверка таблицы user_points...")
        
        cursor.execute("PRAGMA table_info(user_points)")
        columns = [col[1] for col in cursor.fetchall()]
        
        if 'total_earned' not in columns:
            logger.info("   ➕ Добавляем поле total_earned в user_points")
            cursor.execute("ALTER TABLE user_points ADD COLUMN total_earned INTEGER DEFAULT 0")
            
            # Заполняем total_earned существующими значениями
            cursor.execute("UPDATE user_points SET total_earned = points")
            logger.info("   📊 Заполнены исторические данные")
        else:
            logger.info("   ✅ Поле total_earned уже существует")
        
        # ===== 4. Создаем недостающие индексы =====
        logger.info("📝 Проверка индексов...")
        
        indexes = [
            "CREATE INDEX IF NOT EXISTS idx_posts_status ON posts(status)",
            "CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id)",
            "CREATE INDEX IF NOT EXISTS idx_users_referrer ON users(referrer_id)"
        ]
        
        for index in indexes:
            try:
                cursor.execute(index)
                logger.info(f"   ✅ Индекс создан: {index.split()[-1]}")
            except Exception as e:
                logger.error(f"   ❌ Ошибка создания индекса: {e}")
        
        conn.commit()
        logger.info("✅ Миграция успешно завершена!")
        
        # ===== 5. Показываем статистику после миграции =====
        cursor.execute("SELECT COUNT(*) FROM posts")
        posts_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM users")
        users_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM posts WHERE status='pending'")
        pending_count = cursor.fetchone()[0]
        
        logger.info(f"📊 Статистика после миграции:")
        logger.info(f"   • Постов всего: {posts_count}")
        logger.info(f"   • Пользователей: {users_count}")
        logger.info(f"   • Ожидают модерации: {pending_count}")
        
        conn.close()
        return True
        
    except Exception as e:
        logger.error(f"❌ Ошибка миграции: {e}")
        return False

if __name__ == "__main__":
    print("\n" + "="*60)
    print("🔄 МИГРАЦИЯ БАЗЫ ДАННЫХ".center(60))
    print("="*60 + "\n")
    
    success = migrate_database()
    
    if success:
        print("\n✅ Миграция завершена успешно! Можно запускать бота.\n")
    else:
        print("\n❌ Ошибка миграции! Сделай бэкап и попробуй снова.\n")