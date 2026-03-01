import re
from typing import Tuple

# Основные опасные слова
DANGEROUS_WORDS = [
    "гондон", "террорист", "бомба", "отрав", "оружие",
    "похищен", "убийство", "насилие", "экстремист", "шантаж"
]

# Regex для слов с окончаниями
DANGEROUS_WORDS_PATTERN = re.compile(
    r'\b(' + '|'.join(map(re.escape, DANGEROUS_WORDS)) + r')(а|у|ы|е|ом|ами|и)?\b',
    re.IGNORECASE
)

# Черный список паттернов (ссылки, телефоны, карты, упоминания)
BLACKLIST_PATTERNS = [
    r'\b\d{11,}\b',        # телефоны
    r'\b\d{16,}\b',        # карты
    r'http[s]?://\S+',      # ссылки
    r'@\w+',                # упоминания
]

BLACKLIST_COMPILED = [re.compile(p, re.IGNORECASE) for p in BLACKLIST_PATTERNS]

def check_rules(text: str) -> Tuple[bool, str]:
    """Проверка текста на соответствие правилам"""
    text = text.strip()

    # Жёсткое ограничение длины
    if len(text) < 20:
        return False, "Сообщение слишком короткое (мин. 20 символов)."
    if len(text) > 400:
        return False, "Сообщение слишком длинное (макс. 400 символов)."

    # Проверка опасных слов
    if DANGEROUS_WORDS_PATTERN.search(text):
        return False, "Сообщение содержит опасные слова."

    # Проверка черных паттернов
    for pattern in BLACKLIST_COMPILED:
        if pattern.search(text):
            return False, "Сообщение содержит запрещённые элементы (ссылки, контакты и т.д.)."

    # Спам: повторяющиеся символы более 8 раз
    if re.search(r'(.)\1{8,}', text):
        return False, "Сообщение содержит слишком много повторяющихся символов."

    return True, "OK"