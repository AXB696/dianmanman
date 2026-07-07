# Smart Charge 后端运行文档

> 描述后端服务的启动方式、API 接口、部署配置

---

## 1. 环境准备

### 1.1 系统依赖

```
Python ≥ 3.10
uvicorn (ASGI 服务器)
httpx (异步 HTTP 客户端)
fastapi (Web 框架)
pydantic (数据校验)
python-dotenv (环境变量)
Pillow (图像处理)
```

### 1.2 安装依赖

```bash
cd backend_v2
pip install -r requirements.txt
```

### 1.3 环境变量配置

在 `backend_v2/.env` 文件中配置：

```env
AMAP_KEY=你的高德地图API_KEY
API_V1_STR=/api/v1
PROJECT_NAME=SmartCharge
DEBUG=true
```

---

## 2. 启动方式

### 2.1 开发环境（推荐）

```bash
cd backend_v2
python -m app.main
```

启动输出：
```
INFO:     Uvicorn running on http://0.0.0.0:8000
INFO:     Application startup complete.
INFO:     Startup: Loading station data asynchronously...
INFO:     Startup: Station data loaded (XXX stations)
```

### 2.2 生产环境

```bash
cd backend_v2
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```

### 2.3 直接运行

```bash
cd backend_v2
python app/main.py
```

---

## 3. 服务架构

```
启动流程:
    create_app()
      → 注册 CORS 中间件
      → 注册全局异常处理器
      → 注册 API 路由 (/api/v1/*)
      → startup_event: 异步加载电站数据
          └── station_repo.load_data_async()
              └── asyncio.run_in_executor() → JSON 解析

关闭流程:
      shutdown_event:
          └── AMapService.close_client()   (关闭 HTTP 连接池)
          └── recommend_cache.clear()       (清空推荐缓存)

运行时事件循环:
    FastAPI/Uvicorn (asyncio)
      ├── /api/recommend    → 四阶段推荐流水线
      ├── /api/stations     → 站点列表查询
      ├── /api/route        → 高德路线规划
      ├── /api/vehicles     → 车辆管理
      └── /health           → 健康检查
```

---

## 4. API 接口清单

### 4.1 推荐接口（核心）

```
POST /api/v1/recommend
```

请求体 (`SearchRequest`)：
```json
{
  "user_location": { "lat": 30.5, "lng": 114.3 },
  "current_soc": 35,
  "target_soc": 80,
  "battery_capacity": 60,
  "energy_consumption": 15,
  "max_distance": 30.0,
  "district_filter": [],
  "type_filter": [],
  "preference": {}
}
```

响应 (`BaseResponse[data=RecommendResult]`)：
```json
{
  "code": 200,
  "message": "success",
  "data": {
    "total": 128,
    "recommendations": [
      {
        "station": { ... },
        "score": 85.3,
        "distance": 8.2,
        "duration": 18,
        "estimated_charging_time": 42,
        "estimated_cost": 28.56,
        "insight": "🌟 谷时低价推荐(0.86元/kWh)",
        "reachable": true,
        "route": {
          "distance": 8.2,
          "duration": 18,
          "path": [[30.5, 114.3], ...],
          "method": "amap_route",
          "steps": [...]
        },
        "_score_detail": {
          "S_dist": 72.1,
          "S_price": 88.5,
          "S_wait": 95.0,
          "S_power": 80.0,
          "S_fatigue": 65.0,
          "S_parking": 100.0,
          "S_avail": 75.0,
          "bonus": 6.0,
          "penalty": 0.0
        }
      }
    ]
  }
}
```

### 4.2 路线规划接口

```
POST /api/v1/route
```

请求体：
```json
{
  "origin_lat": 30.5,
  "origin_lng": 114.3,
  "dest_lat": 30.6,
  "dest_lng": 114.5
}
```

### 4.3 站点列表接口

```
GET /api/v1/stations?offset=0&limit=20
```

### 4.4 健康检查

```
GET /health
```

响应：
```json
{ "code": 200, "message": "success", "data": { "status": "ok" } }
```

---

## 5. 数据流详解

### 5.1 推荐接口完整数据流

```
请求进入
    │
    ▼
┌─────────────────────────────────────┐
│ 缓存查询 (阶段0)                     │
│ recommend_cache.get(cache_key)       │
└─────────────────────────────────────┘
    │ [未命中]
    ▼
┌─────────────────────────────────────┐
│ 快速初筛 (阶段1)                     │
│ station_repo.get_all()               │
│   → district/type 过滤               │
│   → bounding_box 过滤                │
│   → haversine 直线距离过滤           │
│   → 粗估路线距离排序                 │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ 高德路线 (阶段2)                     │
│ 取 Top-5 candidates                  │
│ asyncio.gather(                     │
│   AMapService.get_driving_route × 5 │
│ )                                    │
│ 其余候选用 haversine×1.35 fallback  │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ 综合评分 (阶段3)                     │
│ WeatherService.get_current_temperature_async()
│ BatteryService.estimate_cost()        │
│ BatteryService.can_reach()            │
│ BatteryService.estimate_charging_time()│
│ calculate_score() 七维度             │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ 排序 → 取 Top-20                     │
│ 按 reachable↓ score↓ 排序            │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ 周边生态 (阶段4)                     │
│ 取 Top-5 recommendations             │
│ asyncio.gather(                      │
│   AMapService.get_amenities_around ×5│
│ ) → bonus_score, insight 追加        │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│ 写入缓存 (阶段0 补写)                │
│ recommend_cache.set(cache_key, data) │
└─────────────────────────────────────┘
    │
    ▼
响应返回
```

---

## 6. 外部 API 依赖

| 服务 | 用途 | 费用 | 配置 |
|---|---|---|---|
| 高德地图 REST API v3 | 路线规划、POI 周边 | 按量计费 | `AMAP_KEY` 环境变量 |
| Open-Meteo | 实时气温 | 免费 | 无需 KEY |

### 6.1 高德 API 配额说明

- **驾车路线规划**：每个 KEY 每日 5000 次配额
- **周边搜索**：每个 KEY 每日 10000 次配额
- **本系统优化**：缓存复用（60s TTL）+ 两阶段快筛，实际 API 消耗降低约 70%

### 6.2 降级策略

当高德 API 不可用时：
- 路线距离：`haversine(user, station) × 1.35` 估算
- 周边生态：`bonus_score = 0`（不影响评分排序）

---

## 7. 缓存机制

```
缓存键 (MD5 哈希):
    key = MD5(sorted([
        ("lat", round(user_lat, 4)),
        ("lng", round(user_lng, 4)),
        ("soc", current_soc),
        ("target_soc", target_soc),
        ("capacity", battery_capacity),
        ("consumption", energy_consumption),
        ("district", tuple(sorted(district_filter))),
        ("type", tuple(sorted(type_filter))),
        ("max_dist", max_distance),
    ]))

TTL: 60 秒
最大条目数: 200
淘汰策略: LRU-like（清理最老 20%）
关闭时清理: 是（shutdown_event 调用 clear()）
```

---

## 8. 端口与连接

```
后端服务: http://localhost:8000
API 根路径: http://localhost:8000/api
OpenAPI 文档: http://localhost:8000/api/v1/openapi.json
Swagger UI: http://localhost:8000/api/docs

前端连接: http://localhost:8001 (开发环境 proxy 或直连)
```

---

## 9. 日志与调试

### 9.1 查看日志

启动时 uvicorn 会输出访问日志：

```
INFO:     127.0.0.1:XXXX - "POST /api/v1/recommend HTTP/1.1" 200
```

### 9.2 缓存状态调试

```python
from app.services.cache import recommend_cache
stats = recommend_cache.stats()
print(stats)
# {'total_entries': 5, 'active_entries': 3, 'ttl_seconds': 60.0, 'max_entries': 200}
```

### 9.3 关闭时输出

```
INFO:     Shutdown: Closing AMap HTTP client pool...
INFO:     Shutdown: Clearing recommend cache (200 entries)...
INFO:     Shutdown complete.
```

---

## 10. 常见问题

**Q: 启动报 `AMAP_KEY` 错误？**
A: 检查 `.env` 文件是否存在且 `AMAP_KEY=xxx` 已配置。

**Q: 推荐响应很慢（>10s）？**
A: 首次请求无缓存，高德 API 响应慢属正常。后续相同位置请求（60s内）走缓存，约 0ms。

**Q: 高德 API 配额耗尽？**
A: 等待次日配额重置，或申请更多配额。本系统有 fallback 降级，路线规划自动切换为 haversine 估算。

**Q: 气温数据获取失败？**
A: Open-Meteo API 不可用时，`weather.py` fallback 返回 20°C 默认值，不影响评分。
