import sqlite3
from config import DB_PATH
from typing import List, Tuple, Optional

def init_db():
    """Инициализация базы данных"""
    conn = sqlite3.connect(DB_PATH)
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
        moderated_at TIMESTAMP
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
        FOREIGN KEY (referrer_id) REFERENCES users (id)
    )
    """)
    
    # Таблица статистики
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS stats (
        date TEXT PRIMARY KEY,
        posts_count INTEGER DEFAULT 0,
        users_count INTEGER DEFAULT 0
    )
    """)
    
    # Таблица для монет и бонусов
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS user_points (
        user_id INTEGER PRIMARY KEY,
        points INTEGER DEFAULT 0,
        last_bonus_date TEXT
    )
    """)
    
    # Таблица логов начислений
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS points_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        points INTEGER,
        reason TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
    """)
    
    conn.commit()
    conn.close()

def add_user(user_id: int, username: str, first_name: str, last_name: str, referrer_id: int = None):
    """Добавление нового пользователя"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("SELECT id FROM users WHERE id = ?", (user_id,))
    if not cursor.fetchone():
        cursor.execute(
            "INSERT INTO users (id, username, first_name, last_name, referrer_id) VALUES (?, ?, ?, ?, ?)",
            (user_id, username, first_name, last_name, referrer_id)
        )
    
    conn.commit()
    conn.close()

def add_post(user_id: int, content: str, media_type: str = None, media_id: str = None) -> int:
    """Добавление нового поста"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute(
        "INSERT INTO posts (user_id, content, media_type, media_id) VALUES (?, ?, ?, ?)",
        (user_id, content, media_type, media_id)
    )
    
    post_id = cursor.lastrowid
    
    cursor.execute(
        "UPDATE users SET posts_count = posts_count + 1 WHERE id = ?",
        (user_id,)
    )
    
    conn.commit()
    conn.close()
    return post_id

def get_pending_posts() -> List[Tuple]:
    """Получение всех постов на модерации"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM posts WHERE status='pending' ORDER BY created_at ASC")
    rows = cursor.fetchall()
    conn.close()
    return rows

def get_post_by_id(post_id: int) -> Optional[Tuple]:
    """Получение поста по ID"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM posts WHERE id=?", (post_id,))
    row = cursor.fetchone()
    conn.close()
    return row

def approve_post(post_id: int):
    """Одобрение поста"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "UPDATE posts SET status='approved', moderated_at=CURRENT_TIMESTAMP WHERE id=?",
        (post_id,)
    )
    conn.commit()
    conn.close()

def reject_post(post_id: int):
    """Отклонение поста"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "UPDATE posts SET status='rejected', moderated_at=CURRENT_TIMESTAMP WHERE id=?",
        (post_id,)
    )
    conn.commit()
    conn.close()

def get_user_stats(user_id: int) -> Tuple[int, int]:
    """Статистика пользователя"""
    conn = sqlite3.connect(DB_PATH)
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
    
    conn.close()
    return approved_posts, total_posts

def get_global_stats() -> Tuple[int, int, int]:
    """Глобальная статистика бота"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("SELECT COUNT(*) FROM users")
    total_users = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM posts")
    total_posts = cursor.fetchone()[0]
    
    cursor.execute("SELECT COUNT(*) FROM posts WHERE status='approved'")
    approved_posts = cursor.fetchone()[0]
    
    conn.close()
    return total_users, total_posts, approved_posts


def get_user_balance(user_id: int) -> int:
    """Получить баланс пользователя в монетах"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("SELECT points FROM user_points WHERE user_id=?", (user_id,))
    result = cursor.fetchone()
    conn.close()
    return result[0] if result else 0

def add_user_points(user_id: int, points: int, reason: str):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Обновляем баланс
    cursor.execute("""
    INSERT INTO user_points (user_id, points) VALUES (?, ?)
    ON CONFLICT(user_id) DO UPDATE SET points = points + ?
    """, (user_id, points, points))
    
    # Логируем начисление
    cursor.execute(
        "INSERT INTO points_log (user_id, points, reason) VALUES (?, ?, ?)",
        (user_id, points, reason)
    )
    
    conn.commit()
    conn.close()

def get_referral_stats(user_id: int) -> Tuple[int, int]:
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Прямые рефералы
    cursor.execute("SELECT COUNT(*) FROM users WHERE referrer_id=?", (user_id,))
    direct = cursor.fetchone()[0]
    
    # Вторичные рефералы (рефералы рефералов)
    cursor.execute("""
    SELECT COUNT(*) FROM users 
    WHERE referrer_id IN (
        SELECT id FROM users WHERE referrer_id=?
    )
    """, (user_id,))
    second = cursor.fetchone()[0]
    
    conn.close()
    return direct, second

def update_last_bonus_date(user_id: int, date: str):
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("""
    INSERT INTO user_points (user_id, last_bonus_date) VALUES (?, ?)
    ON CONFLICT(user_id) DO UPDATE SET last_bonus_date = ?
    """, (user_id, date, date))
    
    conn.commit()
    conn.close()

def get_last_bonus_date(user_id: int) -> Optional[str]:
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("SELECT last_bonus_date FROM user_points WHERE user_id=?", (user_id,))
    result = cursor.fetchone()
    conn.close()
    return result[0] if result else None

def add_referral(referrer_id: int, user_id: int):
    pass  # Функция оставлена для совместимости