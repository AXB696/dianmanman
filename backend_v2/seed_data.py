"""
填充虚拟数据，让 Dashboard 看起来用户量很大
运行一次即可：python seed_data.py
"""
import sqlite3
import random
from datetime import datetime, timedelta

import bcrypt

DB = "data/smart_charge.db"

conn = sqlite3.connect(DB)
cur = conn.cursor()

# ── 密码哈希（bcrypt，与 auth 登录模块保持一致）───────
def hash_pw(pw: str) -> str:
    return bcrypt.hashpw(pw.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")

# ── 随机日期（近30天内）───────────────────────────────
now = datetime.utcnow()
def rand_date(days_ago_max=30):
    delta = timedelta(days=random.randint(0, days_ago_max),
                     hours=random.randint(0, 23),
                     minutes=random.randint(0, 59))
    return (now - delta).strftime("%Y-%m-%d %H:%M:%S")

def rand_date_before(stop_date, days_back):
    """在 stop_date 之前最多 days_back 天内随机"""
    delta = timedelta(days=random.randint(0, days_back),
                     hours=random.randint(0, 23),
                     minutes=random.randint(0, 59))
    return (datetime.strptime(stop_date, "%Y-%m-%d %H:%M:%S") - delta).strftime("%Y-%m-%d %H:%M:%S")

# ── 车牌品牌车型 ───────────────────────────────────────
BRANDS_MODELS = [
    ("特斯拉", "Model Y"), ("特斯拉", "Model 3"),
    ("比亚迪", "汉 EV"), ("比亚迪", "秦 Plus EV"),
    ("小米", "SU7 Pro"), ("小米", "SU7 Max"),
    ("蔚来", "ET5"), ("蔚来", "ES6"),
    ("小鹏", "G6"), ("小鹏", "P7i"),
    ("理想", "L6"), ("理想", "L9"),
    ("极氪", "001"), ("极氪", "007"),
    ("宝马", "i3"), ("宝马", "iX3"),
    ("奔驰", "EQE"), ("奥迪", "Q4 e-tron"),
    ("大众", "ID.4"), ("广汽埃安", "AION Y"),
]

# ── 电站列表（从 stations_data.json 提取 station_id）───
import json, os
station_ids = []
repo_path = os.path.join(os.path.dirname(__file__), "app/repositories/stations_data.json")
try:
    with open(repo_path, "r", encoding="utf-8") as f:
        stations = json.load(f)
        station_ids = [s["station_id"] for s in stations if s.get("station_id")]
except:
    station_ids = [f"WH_{i:05d}" for i in range(1, 983)]

if not station_ids:
    station_ids = [f"WH_{i:05d}" for i in range(1, 983)]

print(f"找到 {len(station_ids)} 个电站")

# ── 清空现有数据（保留 admins）──────────────────────────
cur.execute("DELETE FROM favorites")
cur.execute("DELETE FROM history")
cur.execute("DELETE FROM vehicles")
cur.execute("DELETE FROM users WHERE role = 'user'")
conn.commit()
print("已清空现有用户/车辆/收藏/历史数据")

# ── 生成用户（每天递增，越近越多）──────────────────────
print("生成用户数据...")
users = []
phone_prefixes = ["130", "131", "132", "133", "134", "135", "136", "137", "138", "139",
                  "150", "151", "152", "153", "155", "156", "157", "158", "159",
                  "170", "171", "172", "173", "175", "176", "177", "178", "179",
                  "180", "181", "182", "183", "184", "185", "186", "187", "188", "189"]

nickname_prefixes = ["快乐", "安静", "勇敢", "聪明", "善良", "勤奋", "热情", "冷静",
                     "小", "老", "超级", "无敌", "飞翔", "梦幻", "阳光"]

nickname_suffixes = ["阳光", "星星", "老虎", "小鱼", "小鸟", "狐狸", "兔子", "熊猫",
                     "骑士", "勇者", "天使", "恶魔", "王者", "传说", "幻想"]

# 每天用户数量递增：第1-5天每天5-10个，6-10天每天10-20个，11-20天每天20-40个，21-30天每天40-80个
daily_counts = []
for day in range(30):
    if day < 5:
        daily_counts.append(random.randint(5, 10))
    elif day < 10:
        daily_counts.append(random.randint(10, 20))
    elif day < 20:
        daily_counts.append(random.randint(20, 40))
    else:
        daily_counts.append(random.randint(40, 80))

for day_idx, count in enumerate(daily_counts):
    date = (now - timedelta(days=29 - day_idx)).strftime("%Y-%m-%d")
    for i in range(count):
        uid = len(users) + 1
        phone = f"{random.choice(phone_prefixes)}{random.randint(10000000, 99999999)}"
        nickname = random.choice(nickname_prefixes) + random.choice(nickname_suffixes) + str(random.randint(1, 999))
        created = f"{date} {random.randint(0,23):02d}:{random.randint(0,59):02d}:{random.randint(0,59):02d}"
        cur.execute(
            "INSERT INTO users (username, password_hash, nickname, phone, role, created_at) VALUES (?, ?, ?, ?, 'user', ?)",
            (f"user_{uid:04d}", hash_pw("123456"), nickname, phone, created)
        )
        users.append({"id": uid, "created": created})

print(f"  生成 {len(users)} 个用户")

# ── 生成车辆（约60%用户有车）─────────────────────────
print("生成车辆数据...")
vehicles_created = 0
for u in users:
    if random.random() < 0.6:
        brand, model = random.choice(BRANDS_MODELS)
        battery = round(random.uniform(50.0, 120.0), 1)
        consumption = round(random.uniform(12.0, 20.0), 1)
        cur.execute(
            "INSERT INTO vehicles (user_id, brand, model, battery_capacity, energy_consumption, is_default, created_at) VALUES (?, ?, ?, ?, ?, 1, ?)",
            (u["id"], brand, model, battery, consumption, u["created"])
        )
        vehicles_created += 1
print(f"  生成 {vehicles_created} 辆车辆")

# ── 生成收藏（约40%用户有收藏，防止重复）────────────────
print("生成收藏数据...")
favorites_created = 0
for u in users:
    if random.random() < 0.4:
        count = random.randint(1, 5)
        chosen = set()
        while len(chosen) < count:
            chosen.add(random.choice(station_ids))
        for sid in chosen:
            created = rand_date(30)
            try:
                cur.execute(
                    "INSERT INTO favorites (user_id, station_id, created_at) VALUES (?, ?, ?)",
                    (u["id"], sid, created)
                )
                favorites_created += 1
            except sqlite3.IntegrityError:
                pass
print(f"  生成 {favorites_created} 条收藏")

# ── 生成充电记录（约80%用户有充电记录，分布在近30天）──
print("生成充电记录...")
history_created = 0
for u in users:
    if random.random() < 0.8:
        # 每个用户1-15条充电记录
        count = random.randint(1, 15)
        chosen = set()
        while len(chosen) < count:
            chosen.add(random.choice(station_ids))
        for sid in chosen:
            visited = rand_date(30)
            cur.execute(
                "INSERT INTO history (user_id, station_id, visited_at) VALUES (?, ?, ?)",
                (u["id"], sid, visited)
            )
            history_created += 1
print(f"  生成 {history_created} 条充电记录")

conn.commit()
conn.close()
print("\n[OK] 数据填充完成！")
print(f"   用户: {len(users)} 个")
print(f"   车辆: {vehicles_created} 辆")
print(f"   收藏: {favorites_created} 条")
print(f"   充电记录: {history_created} 条")
