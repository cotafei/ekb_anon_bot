"""
Модуль для работы с базой данных SQLite
Версия: 1.1.1
"""

import sqlite3
from config import DB_PATH
from typing import List, Tuple, Optional
import logging
from contextlib import contextmanager

logger = logging.getLogger(__name__)

@contextmanager
def get_db_connection():
    """
    Контекстный менеджер для работы с БД.
    Автоматически обрабатывает коммиты, откаты и закрытие соединения.
    """
    conn = sqlite3.connect(DB_PATH, timeout=30)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
        conn.commit()
    except Exception as e:
        conn.rollback()
        logger.error(f"Ошибка БД: {e}")
        raise
    finally:
        conn.close()

def init_db():
    """Инициализация структуры базы данных при первом запуске"""
    with get_db_connection() as conn:
        cursor = conn.cursor()
        
        # Таблица постов
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS posts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            content TEXT,
            media_type TEXT,
            media_id TEXT,
            status TEXT DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            moderated_at TIMESTAMP,
            moderated_by INTEGER
        )
        """)
        
        # Таблица пользователей
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY,
            username TEXT,
            first_name TEXT,
            last_name TEXT,
            referrer_id INTEGER,
            posts_count INTEGER DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            is_banned INTEGER DEFAULT 0,
            ban_reason TEXT,
            banned_at TIMESTAMP
        )
        """)
        
        # Таблица для монет и бонусов
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS user_points (
            user_id INTEGER PRIMARY KEY,
            points INTEGER DEFAULT 0,
            last_bonus_date TEXT,
            total_earned INTEGER DEFAULT 0
        )
        """)
        
        # Таблица логов начислений
        cursor.execute("""
        CREATE TABLE IF NOT EXISTS points_log (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER,
            points INTEGER,
            reason TEXT,
            referrer_id INTEGER,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
        """)
        
        # Индексы для ускорения запросов
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_posts_status ON posts(status)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_posts_user_id ON posts(user_id)")
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_users_referrer ON users(referrer_id)")
        
        logger.info("База данных инициализирована")

def add_user(user_id: int, username: str, first_name: str, last_name: str, referrer_id: int = None):
    """Добавление нового пользователя или обновление существующего"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Проверяем валидность реферера
            if referrer_id:
                cursor.execute(
                    "SELECT id, is_banned FROM users WHERE id = ?",
                    (referrer_id,)
                )
                referrer = cursor.fetchone()
                if not referrer or referrer['is_banned']:
                    referrer_id = None
            
            # Добавляем или обновляем пользователя
            cursor.execute("""
            INSERT OR IGNORE INTO users 
            (id, username, first_name, last_name, referrer_id) 
            VALUES (?, ?, ?, ?, ?)
            """, (user_id, username, first_name, last_name, referrer_id))
            
            if cursor.rowcount == 0:
                cursor.execute("""
                UPDATE users 
                SET username = ?, first_name = ?, last_name = ?
                WHERE id = ?
                """, (username, first_name, last_name, user_id))
            
            return True
    except Exception as e:
        logger.error(f"Ошибка добавления пользователя {user_id}: {e}")
        return False

def add_post(user_id: int, content: str, media_type: str = None, media_id: str = None) -> Optional[int]:
    """Добавление нового поста в базу данных"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            # Проверяем, не забанен ли пользователь
            cursor.execute("SELECT is_banned FROM users WHERE id = ?", (user_id,))
            user = cursor.fetchone()
            if user and user['is_banned']:
                logger.warning(f"Забаненный пользователь {user_id} пытался отправить пост")
                return None
            
            # Вставляем пост
            cursor.execute("""
            INSERT INTO posts (user_id, content, media_type, media_id) 
            VALUES (?, ?, ?, ?)
            """, (user_id, content, media_type, media_id))
            
            post_id = cursor.lastrowid
            
            # Обновляем счетчик постов пользователя
            cursor.execute("""
            UPDATE users SET posts_count = posts_count + 1 WHERE id = ?
            """, (user_id,))
            
            return post_id
    except Exception as e:
        logger.error(f"Ошибка добавления поста: {e}")
        return None

def get_pending_posts() -> List[Tuple]:
    """Получение всех постов, ожидающих модерации"""
    try:
        with get_db_connection() as conn:
            conn.row_factory = None  # Возвращаем кортежи для совместимости
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM posts WHERE status='pending' ORDER BY created_at ASC")
            return cursor.fetchall()
    except Exception as e:
        logger.error(f"Ошибка получения постов: {e}")
        return []

def get_post_by_id(post_id: int) -> Optional[Tuple]:
    """Получение поста по его ID"""
    try:
        with get_db_connection() as conn:
            conn.row_factory = None
            cursor = conn.cursor()
            cursor.execute("SELECT * FROM posts WHERE id=?", (post_id,))
            return cursor.fetchone()
    except Exception as e:
        logger.error(f"Ошибка получения поста {post_id}: {e}")
        return None

def approve_post(post_id: int):
    """Одобрение поста (изменение статуса на approved)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
            UPDATE posts 
            SET status='approved', moderated_at=CURRENT_TIMESTAMP 
            WHERE id=? AND status='pending'
            """, (post_id,))
            return cursor.rowcount > 0
    except Exception as e:
        logger.error(f"Ошибка одобрения поста {post_id}: {e}")
        return False

def reject_post(post_id: int):
    """Отклонение поста (изменение статуса на rejected)"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
            UPDATE posts 
            SET status='rejected', moderated_at=CURRENT_TIMESTAMP 
            WHERE id=? AND status='pending'
            """, (post_id,))
            return cursor.rowcount > 0
    except Exception as e:
        logger.error(f"Ошибка отклонения поста {post_id}: {e}")
        return False

def get_user_stats(user_id: int) -> Tuple[int, int]:
    """Получение статистики пользователя (одобрено/всего)"""
    try:
        with get_db_connection() as conn:
            conn.row_factory = None
            cursor = conn.cursor()
            
            cursor.execute(
                "SELECT COUNT(*) FROM posts WHERE user_id=? AND status='approved'",
                (user_id,)
            )
            approved_posts = cursor.fetchone()[0]
            
            cursor.execute(
                "SELECT COUNT(*) FROM posts WHERE user_id=?",
                (user_id,)
            )
            total_posts = cursor.fetchone()[0]
            
            return approved_posts, total_posts
    except Exception as e:
        logger.error(f"Ошибка получения статистики пользователя {user_id}: {e}")
        return 0, 0

def get_global_stats() -> Tuple[int, int, int]:
    """Получение глобальной статистики бота"""
    try:
        with get_db_connection() as conn:
            conn.row_factory = None
            cursor = conn.cursor()
            
            cursor.execute("SELECT COUNT(*) FROM users")
            total_users = cursor.fetchone()[0]
            
            cursor.execute("SELECT COUNT(*) FROM posts")
            total_posts = cursor.fetchone()[0]
            
            cursor.execute("SELECT COUNT(*) FROM posts WHERE status='approved'")
            approved_posts = cursor.fetchone()[0]
            
            return total_users, total_posts, approved_posts
    except Exception as e:
        logger.error(f"Ошибка получения глобальной статистики: {e}")
        return 0, 0, 0

def get_user_balance(user_id: int) -> int:
    """Получение баланса монет пользователя"""
    try:
        with get_db_connection() as conn:
            conn.row_factory = None
            cursor = conn.cursor()
            cursor.execute("SELECT points FROM user_points WHERE user_id=?", (user_id,))
            result = cursor.fetchone()
            return result[0] if result else 0
    except Exception as e:
        logger.error(f"Ошибка получения баланса {user_id}: {e}")
        return 0

def add_user_points(user_id: int, points: int, reason: str):
    """Начисление монет пользователю"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            
            cursor.execute("""
            INSERT INTO user_points (user_id, points) VALUES (?, ?)
            ON CONFLICT(user_id) DO UPDATE SET points = points + ?
            """, (user_id, points, points))
            
            cursor.execute("""
            INSERT INTO points_log (user_id, points, reason) VALUES (?, ?, ?)
            """, (user_id, points, reason))
            
            return True
    except Exception as e:
        logger.error(f"Ошибка начисления монет: {e}")
        return False

def get_referral_stats(user_id: int) -> Tuple[int, int]:
    """Получение статистики рефералов (прямые и вторичные)"""
    try:
        with get_db_connection() as conn:
            conn.row_factory = None
            cursor = conn.cursor()
            
            cursor.execute("SELECT COUNT(*) FROM users WHERE referrer_id=?", (user_id,))
            direct = cursor.fetchone()[0]
            
            cursor.execute("""
            SELECT COUNT(*) FROM users 
            WHERE referrer_id IN (SELECT id FROM users WHERE referrer_id=?)
            """, (user_id,))
            second = cursor.fetchone()[0]
            
            return direct, second
    except Exception as e:
        logger.error(f"Ошибка получения реферальной статистики: {e}")
        return 0, 0

def update_last_bonus_date(user_id: int, date: str):
    """Обновление даты последнего получения бонуса"""
    try:
        with get_db_connection() as conn:
            cursor = conn.cursor()
            cursor.execute("""
            INSERT INTO user_points (user_id, last_bonus_date) VALUES (?, ?)
            ON CONFLICT(user_id) DO UPDATE SET last_bonus_date = ?
            """, (user_id, date, date))
            return True
    except Exception as e:
        logger.error(f"Ошибка обновления даты бонуса: {e}")
        return False

def get_last_bonus_date(user_id: int) -> Optional[str]:
    """Получение даты последнего бонуса"""
    try:
        with get_db_connection() as conn:
            conn.row_factory = None
            cursor = conn.cursor()
            cursor.execute("SELECT last_bonus_date FROM user_points WHERE user_id=?", (user_id,))
            result = cursor.fetchone()
            return result[0] if result else None
    except Exception as e:
        logger.error(f"Ошибка получения даты бонуса: {e}")
        return None

def add_referral(referrer_id: int, user_id: int):
    """Добавление реферала (заглушка для совместимости)"""
    pass