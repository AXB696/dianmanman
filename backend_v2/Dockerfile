# 电满满 后端 Dockerfile
# Python 3.11 + FastAPI + Uvicorn
FROM python:3.11-slim

# 设置工作目录
WORKDIR /app

# 安装系统依赖（osmnx 需要一些 C 库）
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc g++ libgeos-dev libspatialindex-dev \
    && rm -rf /var/lib/apt/lists/*

# 先装依赖（利用 Docker 缓存层）
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

# 复制后端代码
COPY . .

# 暴露端口
EXPOSE 8000

# 启动命令
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "2"]
