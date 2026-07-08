"""
SQLAlchemy ORM 数据库连接 + Session 管理
"""
import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base

DATABASE_URL = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "data", "smart_charge.db")
DATABASE_URL = f"sqlite:///{DATABASE_URL.replace('\\', '/')}"

engine = create_engine(
    DATABASE_URL,
    connect_args={"check_same_thread": False},
    echo=False,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


def get_db():
    """依赖注入：每个请求获取一个 DB Session"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """启动时调用：确保 data 目录存在并创建所有表"""
    # 确保 data 目录存在
    db_path = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "data")
    os.makedirs(db_path, exist_ok=True)
    # 导入模型以触发 Base.metadata 注册
    from app.models import user, vehicle, favorite, history, announcement  # noqa: F401
    Base.metadata.create_all(bind=engine)
    # 迁移
    _migrate_users_table()
    _migrate_history_table()
    _migrate_announcements_table()


def _migrate_users_table():
    """迁移：为 users 表添加 last_login_at 列（若不存在）"""
    from sqlalchemy import text
    try:
        with engine.connect() as conn:
            result = conn.execute(text("PRAGMA table_info(users)"))
            columns = [row[1] for row in result.fetchall()]
            if "last_login_at" not in columns:
                conn.execute(text("ALTER TABLE users ADD COLUMN last_login_at DATETIME"))
                conn.commit()
    except Exception:
        pass


def _migrate_history_table():
    """迁移：为 history 表添加新列（若不存在）"""
    from sqlalchemy import text
    try:
        with engine.connect() as conn:
            result = conn.execute(text("PRAGMA table_info(history)"))
            columns = [row[1] for row in result.fetchall()]
            migrations = {
                "station_name": "ALTER TABLE history ADD COLUMN station_name VARCHAR(200) DEFAULT ''",
                "duration_min": "ALTER TABLE history ADD COLUMN duration_min INTEGER DEFAULT 0",
                "cost_yuan":   "ALTER TABLE history ADD COLUMN cost_yuan FLOAT DEFAULT 0.0",
                "energy_kwh":  "ALTER TABLE history ADD COLUMN energy_kwh FLOAT DEFAULT 0.0",
            }
            for col, sql in migrations.items():
                if col not in columns:
                    conn.execute(text(sql))
                    conn.commit()
    except Exception:
        pass


def _migrate_announcements_table():
    """迁移：为 announcements 表添加 display_until 列（若不存在）"""
    from sqlalchemy import text
    try:
        with engine.connect() as conn:
            result = conn.execute(text("PRAGMA table_info(announcements)"))
            columns = [row[1] for row in result.fetchall()]
            if "display_until" not in columns:
                conn.execute(text("ALTER TABLE announcements ADD COLUMN display_until DATETIME"))
                conn.commit()
    except Exception:
        pass
