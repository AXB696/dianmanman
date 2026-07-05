#!/bin/bash
# ============================================
#  电满满 一键部署脚本
#  兼容：Ubuntu 22.04 / Alibaba Cloud Linux 4 / CentOS
#       支持 OpenClaw 等应用镜像
#  使用方法：
#    1. 上传项目到服务器 或 AI 助手执行
#    2. chmod +x deploy.sh && ./deploy.sh
# ============================================
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  电满满 Smart Charge v2  一键部署脚本  ${NC}"
echo -e "${GREEN}========================================${NC}"

# 自动检测包管理器（兼容 Ubuntu / Alibaba Cloud Linux / CentOS）
if command -v apt-get &> /dev/null; then
    PKG_MGR="apt-get"
elif command -v dnf &> /dev/null; then
    PKG_MGR="dnf"
elif command -v yum &> /dev/null; then
    PKG_MGR="yum"
else
    echo -e "${RED}无法检测包管理器，请手动安装 Docker${NC}"
    exit 1
fi
echo -e "${GREEN}检测到包管理器: ${PKG_MGR}${NC}"

# 0. 检查 Docker
echo -e "\n${YELLOW}[1/5] 检查 Docker 环境...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker 未安装，正在安装...${NC}"
    curl -fsSL https://get.docker.com | bash
    systemctl enable docker 2>/dev/null || true
    systemctl start docker 2>/dev/null || true
fi
if ! command -v docker compose &> /dev/null; then
    echo -e "${YELLOW}安装 Docker Compose 插件...${NC}"
    $PKG_MGR install -y docker-compose-plugin 2>/dev/null || \
    $PKG_MGR install -y docker-compose 2>/dev/null || \
    (curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose) || true
fi
# 最终检查
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Docker 安装失败，请手动安装后重试${NC}"
    exit 1
fi
echo -e "${GREEN}  Docker $(docker --version)${NC}"
echo -e "${GREEN}  $(docker compose version 2>/dev/null || docker-compose --version)${NC}"

# 2. 生成 JWT 密钥（如果没有设置）
echo -e "\n${YELLOW}[2/5] 配置环境变量...${NC}"
if [ ! -f .env ]; then
    JWT_KEY=$(python3 -c "import secrets; print(secrets.token_hex(32))" 2>/dev/null || openssl rand -hex 32)
    cat > .env <<EOF
JWT_SECRET_KEY=$JWT_KEY
AMAP_KEY=你的高德Key
EOF
    echo -e "${YELLOW}  已自动生成 JWT 密钥，请编辑 .env 填入高德 Key${NC}"
else
    echo -e "${GREEN}  .env 已存在，跳过 ✓${NC}"
fi

# 3. 检查数据目录
echo -e "\n${YELLOW}[3/5] 创建数据目录...${NC}"
mkdir -p backend_v2/data
echo -e "${GREEN}  数据目录已就绪 ✓${NC}"

# 4. 构建镜像
echo -e "\n${YELLOW}[4/5] 构建 Docker 镜像...${NC}"
docker compose build
echo -e "${GREEN}  镜像构建完成 ✓${NC}"

# 5. 启动服务
echo -e "\n${YELLOW}[5/5] 启动服务...${NC}"
docker compose up -d
echo -e "${GREEN}  服务已启动 ✓${NC}"

# 检查状态
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  部署完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "  管理后台: http://$(curl -s ifconfig.me 2>/dev/null || echo '你的IP')/admin/"
echo "  API 文档: http://$(curl -s ifconfig.me 2>/dev/null || echo '你的IP')/docs/"
echo ""
echo "  常用命令："
echo "    查看日志: docker compose logs -f"
echo "    重启服务: docker compose restart"
echo "    停止服务: docker compose down"
echo "    更新代码: git pull && docker compose up -d --build"
