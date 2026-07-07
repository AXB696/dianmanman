# 电满满 Smart Charge v2 — 项目概览

> 基于 AI 多目标优化的新能源汽车智能充电导航系统。
> 面向武汉地区，覆盖 982 个充电站，15+ 品牌 60+ 款车型。
> 参加**智慧交通创新创业大赛**。

---

## 🏗️ 整体架构

```
┌─────────────────────────────────────────────────────────────┐
│  📱 App 端 (Flutter)          🌐 管理后台 (Flutter Web)      │
│  Android/iOS 用户端            PC 浏览器管理端                │
│  ├─ 地图 + 推荐卡片           ├─ Dashboard 图表              │
│  ├─ 收藏 + 历史记录           ├─ 用户管理 + 公告管理          │
│  └─ 车辆配置 + 导航           └─ 电站总览 + 管理员账号        │
└──────────────┬──────────────────┬───────────────────────────┘
               │    HTTP REST     │
               ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│  ⚙️ 后端 (Python FastAPI + SQLite + JWT)                     │
│  ├─ 推荐引擎 (多目标加权评分 + 充电曲线模型)                  │
│  ├─ 三级路径规划 (高德 API → A* OSM → 系数估算)              │
│  ├─ 用户系统 (注册/登录/JWT/游客模式)                        │
│  └─ 管理 API (统计/公告/电站管理)                            │
└──────────────────────────┬──────────────────────────────────┘
                           │
┌──────────────────────────▼──────────────────────────────────┐
│  🌐 外部服务                                                │
│  高德地图 API (定位/导航/搜索)  ·  OSM 路网 (离线兜底)       │
│  Open-Meteo API (天气)                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 📂 项目结构（v2）

| 目录 | 说明 | 关键文件 |
|------|------|----------|
| `app_v2/` | Flutter 移动端 App | `lib/home.dart` (4400+ 行，单文件架构) |
| `admin_v2/` | Flutter Web 管理后台 | `lib/main.dart` + `lib/pages/` 5 个独立页面 |
| `backend_v2/` | Python FastAPI 后端 | `app/main.py` + 模块化 API/模型/Schema |
| `nginx/` | Nginx 反向代理配置 | `nginx.conf` — 转发 `/api/` + 托管 `/admin/` |
| `icon_gen/` | Dart 图标生成工具 | 生成地图标记图标 |

---

## ⚙️ 后端 (FastAPI + SQLite)

### 模块化结构

| 模块 | 说明 |
|------|------|
| `app/api/v1/` | 13 个路由模块 (auth, users, favorites, history, stations, recommend, navigation, admin, announcements 等) |
| `app/models/` | SQLAlchemy ORM (User, Vehicle, Favorite, History, Announcement) |
| `app/schemas/` | Pydantic 请求/响应模型 |
| `app/core/` | 数据库初始化、JWT 安全、权限依赖、配置 |
| `app/repositories/` | 充电站数据仓库 (982 站 JSON) + 车型数据库 (60+ 款) |

### 核心 API 接口

| 方法 | 路径 | 说明 | 认证 |
|------|------|------|------|
| GET | `/api/stations` | 推荐充电站列表 | 公开 |
| POST | `/api/recommend` | 个性化推荐 (用户偏好) | 可选 JWT |
| GET | `/api/station/{id}` | 充电站详情 + 距离计算 | 公开 |
| POST | `/api/auth/register` | 用户注册 | 公开 |
| POST | `/api/auth/login` | 用户登录 → JWT Token | 公开 |
| GET/POST | `/api/favorites` | 收藏管理 | JWT |
| DELETE | `/api/favorites/{station_id}` | 取消收藏 | JWT |
| GET/POST | `/api/history` | 历史记录 | JWT |
| DELETE | `/api/history/{id}` | 删除历史 | JWT |
| GET/POST/PUT/DELETE | `/api/admin/announcements` | 公告 CRUD | Admin |
| GET | `/api/admin/stats/*` | 统计 API | Admin |
| GET | `/api/announcements/latest` | 最新公告 | 公开 |

### 核心算法

1. **三级降级路径规划**：高德 API (真实导航) → A* OSM (本地) → 系数估算 (兜底)
2. **多目标加权评分**：距离 + 价格 + 等待时间 + 充电功率，支持用户自定义权重
3. **充电曲线模型**：按 SOC 区间分段模拟，区分三元锂/磷酸铁锂电池类型
4. **可达性判断**：基于 SOC + 电池容量 + 能耗，保留 30% 安全余量

### 认证体系

- **JWT Bearer Token**：Access Token 7 天 + Refresh Token 30 天
- **角色**：`user` / `admin` / `super_admin`
- **游客模式**：未登录可用全部功能，数据存本地 SharedPreferences，登录后自动合并

### 数据库

- **SQLite**：零配置、文件即数据库 (`backend_v2/data/smart_charge.db`)
- **自动迁移**：启动时检测表结构并补全缺失列

---

## 📱 App 端 (Flutter)

### 技术栈

| 技术 | 说明 |
|------|------|
| 地图 | 高德 Flutter SDK (`amap_flutter_map` 3.0.0) |
| 定位 | 高德定位 SDK + Geolocator 双定位 |
| 网络 | Dio + 自动 Token 刷新拦截器 |
| 存储 | SharedPreferences (游客本地数据) + 云端同步 (登录后) |

### 数据架构

| 服务层 | 文件 | 说明 |
|------|------|------|
| DataRepository | `lib/services/data_repository.dart` | 统一数据仓库，自动切换本地/云端 |
| LocalStorage | `lib/services/local_storage.dart` | SharedPreferences 封装 |
| ApiClient | `lib/services/api_client.dart` | Dio HTTP 客户端 + JWT 拦截器 |
| AuthService | `lib/services/auth_service.dart` | 登录/注册/Token 管理 |
| VehicleData | `lib/services/vehicle_data.dart` | 内置 60+ 款车型参数 |

### 数据流架构

```
用户操作
  ↓
DataRepository (统一入口)
  ├─ 游客 → LocalStorage (SharedPreferences)
  └─ 登录 → ApiClient → 后端 API
               └─ 同时缓存到 LocalStorage

登录时：本地数据 → 上传云端 → 拉取云端 → 合并（取并集不丢数据）
登出时：本地 → 同步云端（含删除） → 本地保留
```

### 页面与功能

| 功能 | 说明 |
|------|------|
| 地图首页 | 高德地图 + 底部推荐卡片 PageView，滑动联动地图镜头 |
| 充电站详情 | 完整信息 + 一键导航 + 收藏切换 + 电话拨打 |
| 收藏站点 | 独立列表，实时从后端拉取完整站点数据 |
| 历史记录 | 自动记录访问，支持批量删除，云端同步 |
| 车辆配置 | 15 品牌 60+ 车型，SOC 滑块调节，实时重新测算 |
| 天气展示 | 基于用户位置的实时天气 |
| 用户系统 | 注册/登录/游客模式，JWT 自动续期 |

---

## 🌐 管理后台 (Flutter Web)

| 页面 | 路由 | 说明 |
|------|------|------|
| Dashboard | `/` | 4 统计卡片 + 折线图 + 柱状图 + 饼图 + Top10 站点 |
| 用户管理 | `/users` | 搜索/分页/删除，展开车辆列表 + 充电记录 |
| 管理员账号 | `/admins` | 仅 super_admin 可见，增删改密码 |
| 站内公告 | `/announcements` | 公告 CRUD，发布后 App 端自动展示 |
| 电站总览 | `/stations` | 筛选/搜索/分页/详情弹窗 |

---

## 🐳 部署

| 文件 | 说明 |
|------|------|
| `backend_v2/Dockerfile` | Python 3.11 + FastAPI + Uvicorn |
| `docker-compose.yml` | 后端 + Nginx 一键编排 |
| `nginx/nginx.conf` | 反向代理 `/api/` + 托管 `/admin/` |
| `deploy.sh` | 一键部署脚本 (兼容 Ubuntu / Alibaba Cloud Linux) |

```bash
git clone https://github.com/AXB696/dianmanman.git
cd dianmanman
# 编辑 .env 填入 AMAP_KEY
chmod +x deploy.sh && ./deploy.sh
```

---

## 🗺️ 数据覆盖

- **地域**：武汉市 (汉口/武昌/汉阳)
- **充电站**：982 个 (超充/快充/慢充/目的地/专用/换电)
- **运营商**：特来电、星星充电等
- **车型**：特斯拉/比亚迪/蔚来/小鹏/理想/广汽埃安/极氪/吉利/大众/宝马/奔驰/奥迪/通用/小米/华为 问界/其他

---

## 🔄 版本历史

| 版本 | 日期 | 主要变更 |
|------|------|----------|
| v1 | 2026-04 | 单文件后端 + Flutter 基础版 |
| v2 | 2026-07 | 模块化后端 + SQLite + JWT + 管理后台 + Docker 部署 |

---

> 最后更新：2026-07-07
