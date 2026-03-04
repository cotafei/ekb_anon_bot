"""
Миграция базы данных для обновления со старой версии на новую
Запусти один раз перед новым ботом для сохранения данных
Версия: 1.1.0
"""

import sqlite3
import logging
import os
from pathlib import Path

# Определяем путь к БД
BASE_DIR = Path(__file__).parent.parent
DB_PATH = str(BASE_DIR / 'data' / 'anon_ekb.db')

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def migrate_database():
    """
    Обновление структуры БД без потери данных
    Добавляет новые поля, которых не было в старой версии
    """
    try:
        if not os.path.exists(DB_PATH):
            logger.error(f"❌ База данных не найдена по пути: {DB_PATH}")
            return False
            
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        
        logger.info("🔧 Начинаю миграцию базы данных...")
        
        # ===== 1. Обновление таблицы posts =====
        logger.info("📝 Проверка таблицы posts...")
        
        cursor.execute("PRAGMA table_info(posts)")
        columns = [col[1] for col in cursor.fetchall()]
        logger.info(f"   📊 Существующие колонки: {', '.join(columns)}")
        
        if 'moderated_by' not in columns:
            logger.info("   ➕ Добавляем поле moderated_by в posts")
            cursor.execute("ALTER TABLE posts ADD COLUMN moderated_by INTEGER")
            logger.info("   ✅ Поле moderated_by добавлено")
        else:
            logger.info("   ✅ Поле moderated_by уже существует")
        
        # ===== 2. Обновление таблицы users =====
        logger.info("📝 Проверка таблицы users...")
        
        cursor.execute("PRAGMA table_info(users)")
        columns = [col[1] for col in cursor.fetchall()]
        logger.info(f"   📊 Существующие колонки: {', '.join(columns)}")
        
        new_user_fields = {
            'is_banned': 'INTEGER DEFAULT 0',
            'ban_reason': 'TEXT',
            'banned_at': 'TIMESTAMP'
        }
        
        for field, field_type in new_user_fields.items():
            if field not in columns:
                logger.info(f"   ➕ Добавляем поле {field} в users")
                cursor.execute(f"ALTER TABLE users ADD COLUMN {field} {field_type}")
                logger.info(f"   ✅ Поле {field} добавлено")
            else:
                logger.info(f"   ✅ Поле {field} уже существует")
        
        # ===== 3. Обновление таблицы user_points =====
        logger.info("📝 Проверка таблицы user_points...")
        
        cursor.execute("PRAGMA table_info(user_points)")
        columns = [col[1] for col in cursor.fetchall()]
        logger.info(f"   📊 Существующие колонки: {', '.join(columns)}")
        
        if 'total_earned' not in columns:
            logger.info("   ➕ Добавляем поле total_earned в user_points")
            cursor.execute("ALTER TABLE user_points ADD COLUMN total_earned INTEGER DEFAULT 0")
            
            # Заполняем total_earned существующими значениями
            cursor.execute("UPDATE user_points SET total_earned = points")
            logger.info("   ✅ Поле total_earned добавлено и заполнено")
        else:
            logger.info("   ✅ Поле total_earned уже существует")
        
        # ===== 4. ОБНОВЛЕНИЕ ТАБЛИЦЫ POINTS_LOG (САМОЕ ВАЖНОЕ) =====
        logger.info("📝 Проверка таблицы points_log...")
        
        # Проверяем существует ли таблица
        cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='points_log'")
        table_exists = cursor.fetchone()
        
        if not table_exists:
            logger.info("   📝 Таблица points_log не существует, создаем...")
            cursor.execute("""
            CREATE TABLE points_log (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER,
                points INTEGER,
                reason TEXT,
                referrer_id INTEGER,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
            """)
            logger.info("   ✅ Таблица points_log создана с колонкой referrer_id")
        else:
            # Таблица существует, проверяем колонки
            cursor.execute("PRAGMA table_info(points_log)")
            columns = [col[1] for col in cursor.fetchall()]
            logger.info(f"   📊 Существующие колонки в points_log: {', '.join(columns)}")
            
            if 'referrer_id' not in columns:
                logger.info("   ⚠️ Колонка referrer_id ОТСУТСТВУЕТ! Добавляем...")
                try:
                    cursor.execute("ALTER TABLE points_log ADD COLUMN referrer_id INTEGER")
                    logger.info("   ✅ Колонка referrer_id успешно ДОБАВЛЕНА!")
                    
                    # Пробуем заполнить данными
                    try:
                        cursor.execute("""
                            UPDATE points_log 
                            SET referrer_id = (
                                SELECT referrer_id FROM users 
                                WHERE users.id = points_log.user_id
                            )
                            WHERE referrer_id IS NULL
                        """)
                        logger.info(f"   📊 Обновлено {cursor.rowcount} записей с referrer_id")
                    except Exception as e:
                        logger.warning(f"   ⚠️ Не удалось заполнить данные: {e}")
                        
                except Exception as e:
                    logger.error(f"   ❌ Ошибка при добавлении колонки: {e}")
                    
                    # Если не получается ALTER - пересоздаем таблицу
                    logger.info("   🔄 Пробуем пересоздать таблицу...")
                    
                    # Создаем временную таблицу
                    cursor.execute("""
                    CREATE TABLE points_log_new (
                        id INTEGER PRIMARY KEY AUTOINCREMENT,
                        user_id INTEGER,
                        points INTEGER,
                        reason TEXT,
                        referrer_id INTEGER,
                        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                    )
                    """)
                    
                    # Копируем данные
                    cursor.execute("""
                    INSERT INTO points_log_new (id, user_id, points, reason, created_at)
                    SELECT id, user_id, points, reason, created_at FROM points_log
                    """)
                    
                    # Удаляем старую таблицу
                    cursor.execute("DROP TABLE points_log")
                    
                    # Переименовываем новую
                    cursor.execute("ALTER TABLE points_log_new RENAME TO points_log")
                    
                    logger.info("   ✅ Таблица points_log успешно пересоздана с колонкой referrer_id!")
            else:
                logger.info("   ✅ Колонка referrer_id уже существует")
        
        # ===== 5. Создаем недостающие индексы =====
        logger.info("📝 Проверка индексов...")
        
        indexes = [
            ("idx_posts_status", "CREATE INDEX IF NOT EXISTS idx_posts_status ON posts(status)"),
            ("idx_posts_user_id", "CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id)"),
            ("idx_users_referrer", "CREATE INDEX IF NOT EXISTS idx_users_referrer ON users(referrer_id)"),
            ("idx_points_log_user", "CREATE INDEX IF NOT EXISTS idx_points_log_user ON points_log(user_id)"),
            ("idx_points_log_referrer", "CREATE INDEX IF NOT EXISTS idx_points_log_referrer ON points_log(referrer_id)")
        ]
        
        for index_name, index_sql in indexes:
            try:
                cursor.execute(index_sql)
                logger.info(f"   ✅ Индекс {index_name} создан")
            except Exception as e:
                logger.error(f"   ❌ Ошибка создания индекса {index_name}: {e}")
        
        conn.commit()
        
        # ===== 6. ФИНАЛЬНАЯ ПРОВЕРКА =====
        logger.info("🔍 Финальная проверка...")
        
        cursor.execute("PRAGMA table_info(points_log)")
        columns = [col[1] for col in cursor.fetchall()]
        
        if 'referrer_id' in columns:
            logger.info("✅ Колонка referrer_id ПРИСУТСТВУЕТ в таблице points_log!")
        else:
            logger.error("❌ Колонка referrer_id ОТСУТСТВУЕТ в таблице points_log!")
            conn.close()
            return False
        
        # ===== 7. Показываем статистику после миграции =====
        cursor.execute("SELECT COUNT(*) FROM posts")
        posts_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM users")
        users_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM posts WHERE status='pending'")
        pending_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM points_log")
        points_log_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM points_log WHERE referrer_id IS NOT NULL")
        points_with_referrer = cursor.fetchone()[0]
        
        logger.info(f"📊 Статистика после миграции:")
        logger.info(f"   • Постов всего: {posts_count}")
        logger.info(f"   • Пользователей: {users_count}")
        logger.info(f"   • Ожидают модерации: {pending_count}")
        logger.info(f"   • Логов начислений: {points_log_count}")
        logger.info(f"   • Логов с реферером: {points_with_referrer}")
        
        conn.close()
        return True
        
    except Exception as e:
        logger.error(f"❌ Ошибка миграции: {e}")
        import traceback
        traceback.print_exc()
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
