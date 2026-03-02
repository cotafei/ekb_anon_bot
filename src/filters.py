"""
Модуль фильтрации контента
Проверяет посты на соответствие правилам
Версия: 1.1.0
"""

import re
from typing import Tuple

# Список опасных слов (база для фильтрации)
DANGEROUS_WORDS = [
    "гондон", "террорист", "бомба", "отрав", "оружие",
    "похищен", "убийство", "насилие", "экстремист", "шантаж"
]

# Регулярное выражение для поиска опасных слов с окончаниями
DANGEROUS_WORDS_PATTERN = re.compile(
    r'\b(' + '|'.join(map(re.escape, DANGEROUS_WORDS)) + r')(а|у|ы|е|ом|ами|и)?\b',
    re.IGNORECASE
)

# Паттерны для запрещенного контента
BLACKLIST_PATTERNS = [
    r'\b\d{11,}\b',        # Номера телефонов (11+ цифр)
    r'\b\d{16,}\b',        # Номера банковских карт (16+ цифр)
    r'http[s]?://\S+',      # Ссылки
    r'@\w+',                # Упоминания пользователей
]

BLACKLIST_COMPILED = [re.compile(p, re.IGNORECASE) for p in BLACKLIST_PATTERNS]

def check_rules(text: str) -> Tuple[bool, str]:
    """
    Проверка текста на соответствие правилам
    Возвращает (True, "OK") если всё хорошо, иначе (False, причина)
    """
    text = text.strip()

    # Проверка длины
    if len(text) < 20:
        return False, "Сообщение слишком короткое (мин. 20 символов)."
    if len(text) > 400:
        return False, "Сообщение слишком длинное (макс. 400 символов)."

    # Проверка на опасные слова
    if DANGEROUS_WORDS_PATTERN.search(text):
        return False, "Сообщение содержит опасные слова."

    # Проверка на запрещенные паттерны
    for pattern in BLACKLIST_COMPILED:
        if pattern.search(text):
            return False, "Сообщение содержит запрещённые элементы (ссылки, контакты и т.д.)."

    # Проверка на спам (повторяющиеся символы)
    if re.search(r'(.)\1{8,}', text):
        return False, "Сообщение содержит слишком много повторяющихся символов."

    return True, "OK"