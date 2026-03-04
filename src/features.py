"""
Модуль с функциями для пользователей бота
Версия: 1.1.1
"""

from aiogram import types
from datetime import datetime
from config import REFERRAL_BONUS, DAILY_BONUS
from database import add_user, get_user_balance, add_user_points, get_referral_stats, update_last_bonus_date, get_last_bonus_date

async def start_handler(message: types.Message):
    """Обработчик команды /start"""
    referrer_id = None
    if len(message.text.split()) > 1:
        ref_code = message.text.split()[1]
        if ref_code.startswith('ref_'):
            try:
                referrer_id = int(ref_code.replace('ref_', ''))
                # Исключаем возможность пригласить самого себя
                if referrer_id == message.from_user.id:
                    referrer_id = None
            except ValueError:
                referrer_id = None
    
    add_user(
        message.from_user.id,
        message.from_user.username or "",
        message.from_user.first_name or "",
        message.from_user.last_name or "",
        referrer_id
    )
    
    if referrer_id:
        # Начисляем бонус рефереру
        add_user_points(referrer_id, REFERRAL_BONUS, "referral_bonus", message.from_user.id)
    
    text = "👋 Привет! Это анонимный бот для Екатеринбурга.\n\n"
    
    if referrer_id:
        text += f"🎉 Ты пришел по ссылке друга! Твой друг получил {REFERRAL_BONUS} монет!\n\n"
    
    text += (
        "⚠️ Правила:\n"
        "— 20–400 символов\n"
        "— Без оскорблений и запрещённого контента\n"
        "— Без ссылок и контактных данных\n\n"
        "💰 Новое: Зарабатывай монеты за приглашение друзей!\n"
        "📊 /stats - твоя статистика\n"
        "👥 /referral - пригласить друзей\n"
        "🆘 /help - помощь\n"
    )
    
    await message.answer(text)

async def referral_handler(message: types.Message):
    """Обработчик команды /referral"""
    bot_username = (await message.bot.get_me()).username
    ref_link = f"https://t.me/{bot_username}?start=ref_{message.from_user.id}"
    
    # Получаем статистику
    direct_refs, second_refs = get_referral_stats(message.from_user.id)
    earned = (direct_refs * REFERRAL_BONUS) + (second_refs * (REFERRAL_BONUS // 2))
    
    text = (
        "👥 Приглашай друзей - получай монеты!\n\n"
        f"🔗 Твоя ссылка: {ref_link}\n\n"
        "💸 Награды:\n"
        f"• За друга: +{REFERRAL_BONUS} монет\n"
        f"• За друга друга: +{REFERRAL_BONUS // 2} монет\n\n"
        f"📊 Твоя статистика:\n"
        f"• Приглашено: {direct_refs} друзей\n"
        f"• Друзья друзей: {second_refs}\n"
        f"• Заработано: {earned} монет\n\n"
        "💡 Делитесь ссылкой в соцсетях!"
    )
    
    await message.answer(text)

async def daily_bonus_handler(message: types.Message):
    """Обработчик команды /daily"""
    user_id = message.from_user.id
    today = datetime.now().date().isoformat()
    last_bonus = get_last_bonus_date(user_id)
    
    if last_bonus == today:
        await message.answer("🎁 Сегодня ты уже получал бонус! Завтра приходи")
        return
    
    add_user_points(user_id, DAILY_BONUS, "daily_bonus")
    update_last_bonus_date(user_id, today)
    
    await message.answer(f"🎁 Ежедневный бонус! Получено {DAILY_BONUS} монет!")

async def stats_handler(message: types.Message):
    """Обработчик команды /stats"""
    from database import get_user_stats, get_user_balance, get_referral_stats
    
    approved, total = get_user_stats(message.from_user.id)
    balance = get_user_balance(message.from_user.id)
    direct_refs, second_refs = get_referral_stats(message.from_user.id)
    
    success_rate = round((approved / total * 100)) if total > 0 else 0
    
    text = (
        f"📊 Ваша статистика:\n\n"
        f"✅ Одобрено постов: {approved}\n"
        f"📨 Всего отправлено: {total}\n"
        f"💰 Баланс: {balance} монет\n"
        f"👥 Приглашено: {direct_refs} друзей\n"
        f"📈 Процент успеха: {success_rate}%\n\n"
        "💸 Монеты можно тратить на привилегии!"
    )
    
    await message.answer(text)

async def shop_handler(message: types.Message):
    """Обработчик команды /shop"""
    text = "🛍 Магазин временно на разработке. Скоро здесь можно будет тратить монеты!"
    await message.answer(text)