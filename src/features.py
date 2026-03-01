"""
Модуль с функциями для пользователей бота
Версия: 1.1.0
"""

import sqlite3
from aiogram import types, Bot
from aiogram.filters import Command
from datetime import datetime
from config import DB_PATH, CHANNEL_ID, REFERRAL_BONUS
from database import add_user, get_user_balance, add_user_points, get_referral_stats, update_last_bonus_date, get_last_bonus_date, add_referral

async def start_handler(message: types.Message):
    """Обработчик команды /start"""
    referrer_id = None
    if len(message.text.split()) > 1:
        ref_code = message.text.split()[1]
        if ref_code.startswith('ref_'):
            try:
                referrer_id = int(ref_code.replace('ref_', ''))
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
        add_referral(referrer_id, message.from_user.id)
        add_user_points(referrer_id, REFERRAL_BONUS, "referral_bonus")
    
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
    earned = (direct_refs * 50) + (second_refs * 25)
    
    # Простой текст - ссылка будет кликабельной автоматически
    text = (
        "👥 Приглашай друзей - получай монеты!\n\n"
        f"🔗 Твоя ссылка: {ref_link}\n\n"
        "💸 Награды:\n"
        f"• За друга: +50 монет\n"
        f"• За друга друга: +25 монет\n\n"
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
    
    bonus = 10
    add_user_points(user_id, bonus, "daily_bonus")
    update_last_bonus_date(user_id, today)
    
    await message.answer(f"🎁 Ежедневный бонус! Получено {bonus} монет!")

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
    text = (
        "🛍️ Магазин привилегий:\n\n"
        "🚀 Срочная модерация - 100 монет\n"
        "📌 Закреп поста на 24ч - 300 монет\n"
        "🎨 Цветной текст - 50 монет\n"
        "👻 Полная анонимность - 200 монет\n\n"
        "💡 Используй монеты для улучшения постов!"
    )
    
    await message.answer(text)