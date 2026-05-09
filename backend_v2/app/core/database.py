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
    # 迁移：确保 last_login_at 列存在于 users 表（已有表不会自动 ALTER）
    _migrate_users_table()


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
