<template>
  <div class="page">
    <h1 class="page-title">电站总览</h1>

    <!-- ═══ 搜索栏 ═══ -->
    <div class="toolbar">
      <select v-model="district" class="fil"><option value="">全部区域</option><option>汉口</option><option>武昌</option><option>汉阳</option></select>
      <select v-model="stype" class="fil"><option value="">全部类型</option><option value="ultra">超充</option><option value="fast">快充</option><option value="slow">慢充</option><option value="destination">目的地</option><option value="fleet">专用</option><option value="swap">换电</option></select>
      <input v-model="keyword" class="fil search" placeholder="搜索站名/地址..." @keydown.enter="doSearch" />
      <button class="btn btn-primary" @click="doSearch">搜索</button>
      <div class="refresh-info">
        <span class="refresh-time" v-if="lastRefresh">更新于 {{ lastRefresh }}</span>
        <button class="btn btn-refresh" @click="doFetch(); refreshTick()">🔄 刷新</button>
      </div>
    </div>

    <!-- ═══ 表格 ═══ -->
    <div class="table-wrap"><table class="table">
      <thead><tr><th>ID</th><th>名称</th><th>区域</th><th>类型</th><th>总桩</th><th>功率</th><th>地址</th><th style="width:50px"></th></tr></thead>
      <tbody>
        <template v-for="s in stations" :key="s.station_id">
          <!-- 行：点击展开 -->
          <tr :class="{ 'row-expanded': expandedId === s.station_id }" @click="toggleExpand(s)">
            <td class="mono">{{ s.station_id }}</td>
            <td class="bold">{{ s.name }}</td>
            <td>{{ s.district_group }}</td>
            <td><span class="type-tag">{{ s.type_name || s.type }}</span></td>
            <td>{{ s.pile_count }}</td>
            <td>{{ s.power_kw }}kW</td>
            <td class="addr-cell">{{ s.address }}</td>
            <td class="center">{{ expandedId === s.station_id ? '▲' : '▼' }}</td>
          </tr>
          <!-- 展开详情 -->
          <tr v-if="expandedId === s.station_id" class="detail-row">
            <td colspan="8">
              <div class="detail-panel">
                <div class="detail-cols">
                  <!-- 基本信息 -->
                  <div class="detail-card">
                    <h3 class="detail-card-title">⚡ {{ s.name }}</h3>
                    <div class="info-grid">
                      <div class="info-item"><span class="info-label">站点 ID</span><span class="mono">{{ s.station_id }}</span></div>
                      <div class="info-item"><span class="info-label">区域</span><span>{{ s.district_group }}</span></div>
                      <div class="info-item"><span class="info-label">类型</span><span class="type-tag">{{ s.type_name || s.type }}</span></div>
                      <div class="info-item"><span class="info-label">运营商</span><span>{{ s.operator || '未知' }}</span></div>
                      <div class="info-item"><span class="info-label">电话</span><span>{{ s.tel || '-' }}</span></div>
                      <div class="info-item"><span class="info-label">地址</span><span style="white-space:normal">{{ s.address }}</span></div>
                      <div class="info-item" v-if="s.lat"><span class="info-label">坐标</span><span class="mono">{{ s.lat }}, {{ s.lng }}</span></div>
                    </div>
                  </div>
                  <!-- 运营数据 -->
                  <div class="detail-card">
                    <h3 class="detail-card-title">📊 运营数据</h3>
                    <div class="info-grid">
                      <div class="info-item"><span class="info-label">总桩数</span><span class="stat-val">{{ s.pile_count }} 个</span></div>
                      <div class="info-item"><span class="info-label">单桩功率</span><span class="stat-val">{{ s.power_kw }} kW</span></div>
                      <div class="info-item"><span class="info-label">可用 / 占用</span>
                        <span class="stat-val">{{ (s.availability||{}).available||0 }} / {{ (s.availability||{}).occupied||0 }}</span>
                      </div>
                      <div class="info-item"><span class="info-label">利用率</span>
                        <span class="stat-val" :style="{ color: availPercent(s) > 75 ? '#ef4444' : '#059669' }">{{ availPercent(s) }}%</span>
                      </div>
                      <div class="info-item"><span class="info-label">评分</span><span class="stat-val">★ {{ s.rating || '-' }}</span></div>
                      <div class="info-item" v-if="s.price"><span class="info-label">电价</span><span class="stat-val" style="color:#f59e0b">{{ s.price.total }}{{ s.price.unit }}</span></div>
                      <div class="info-item" v-if="s.open_hours"><span class="info-label">营业时间</span><span>{{ s.open_hours }}</span></div>
                      <div class="info-item revenue-item"><span class="info-label"><span class="live-dot"></span>日盈收</span>
                        <span class="stat-val revenue-val">¥ {{ calcDailyRevenue(s) }}</span>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </td>
          </tr>
        </template>
        <tr v-if="stations.length === 0">
          <td colspan="8" class="empty-hint">暂无电站数据</td>
        </tr>
      </tbody>
    </table></div>

    <!-- ═══ 分页 ═══ -->
    <Pagination
      v-if="total > 0"
      :currentPage="page"
      :totalPages="totalPages"
      :total="total"
      @change="goPage"
    />

    <p v-if="error" class="error-msg">{{ error }}</p>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from "vue"
import { getAdminStations } from "@/api/admin"
import Pagination from "@/components/Pagination.vue"
const stations=ref<any[]>([]); const total=ref(0); const offset=ref(0); const limit=20
const district=ref(""); const stype=ref(""); const keyword=ref(""); const error=ref("")
const lastRefresh = ref('')
let refreshTimer: ReturnType<typeof setInterval> | null = null

// 展开详情（同用户管理风格）
const expandedId = ref<string | null>(null)

// 分页
const page = computed(() => Math.floor(offset.value / limit))
const totalPages = computed(() => Math.max(1, Math.ceil(total.value / limit)))

function availPercent(s: any) {
  const a = s.availability || {}
  return a.total > 0 ? Math.round((a.occupied || 0) / a.total * 100) : 0
}

// 计算实时日盈收
function calcDailyRevenue(s: any): string {
  const price = s.price?.total || 1.5  // 电价（元/kWh），默认1.5
  const piles = s.pile_count || 0       // 充电桩数量
  const a = s.availability || {}
  const occupied = a.occupied || 0      // 占用桩数
  const total = a.total || piles        // 总桩数

  // 基于利用率计算，假设每个在用桩每天平均充电8次，每次30kWh
  const utilizationRate = total > 0 ? occupied / total : 0
  const avgSessionsPerPile = 8          // 每桩每天平均充电次数
  const avgKwhPerSession = 30           // 每次平均充电量(kWh)

  // 日盈收 = 占用桩数 × 每桩日均充电次数 × 每次充电量 × 电价
  const dailyRevenue = occupied * avgSessionsPerPile * avgKwhPerSession * price

  // 格式化输出
  if (dailyRevenue >= 10000) {
    return (dailyRevenue / 10000).toFixed(2) + ' 万'
  }
  return dailyRevenue.toFixed(0)
}

async function doFetch(n?:number){if(n!==undefined)offset.value=n
  try{const params:any={offset:offset.value,limit};if(district.value)params.district=district.value;if(stype.value)params.station_type=stype.value;if(keyword.value)params.keyword=keyword.value
  const data:any=await getAdminStations(params);stations.value=data.stations||[];total.value=data.total||0}catch(e){}}
function goPage(p: number) { expandedId.value = null; offset.value = Math.max(0, p) * limit; doFetch() }
function toggleExpand(s: any) { expandedId.value = expandedId.value === s.station_id ? null : s.station_id }
function doSearch() { expandedId.value = null; offset.value = 0; doFetch() }

// 刷新时间显示
function refreshTick() {
  const now = new Date()
  lastRefresh.value = now.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

// 启动自动刷新（每30秒刷新一次数据）
function startAutoRefresh() {
  stopAutoRefresh()
  refreshTick()
  refreshTimer = setInterval(() => {
    doFetch()
    refreshTick()
  }, 30 * 1000) // 30秒刷新一次
}

function stopAutoRefresh() {
  if (refreshTimer) { clearInterval(refreshTimer); refreshTimer = null }
}

onMounted(() => {
  doFetch()
  startAutoRefresh()
})

onUnmounted(() => {
  stopAutoRefresh()
})
</script>

<style scoped>
.page{padding:32px}.page-title{margin:0 0 20px;font-size:20px;color:#1a1a2e}

/* ── 搜索栏 ── */
.toolbar{display:flex;gap:10px;margin-bottom:16px;flex-wrap:wrap;align-items:center}
.fil,.search{padding:8px 12px;border:1px solid #e2e8f0;border-radius:8px;font-size:13px;outline:none;background:#fff;color:#334155;transition:border-color .15s;height:38px;box-sizing:border-box;line-height:1.4;font-family:inherit}
select.fil{padding-right:32px;appearance:none;-webkit-appearance:none;cursor:pointer;background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath d='M3 4.5l3 3 3-3' stroke='%2394a3b8' stroke-width='1.5' fill='none' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E");background-repeat:no-repeat;background-position:right 10px center}
.fil:focus,.search:focus{border-color:#1a56db;box-shadow:0 0 0 3px rgba(26,86,219,.08)}
.fil:hover,.search:hover{border-color:#94a3b8}
.search{width:180px}
.toolbar .btn{height:38px;box-sizing:border-box;line-height:1}
.refresh-info{display:flex;align-items:center;gap:10px;margin-left:auto}
.refresh-time{font-size:11px;color:#94a3b8;white-space:nowrap}
.btn-refresh{background:#f0fdf4;color:#059669;border-color:#bbf7d0;font-size:12px;padding:6px 12px}
.btn-refresh:hover{background:#dcfce7;border-color:#86efac}

/* ── 表格 ── */
.table-wrap{background:#fff;border-radius:12px;overflow:auto;box-shadow:0 1px 8px rgba(0,0,0,0.04)}
.table{width:100%;border-collapse:collapse;font-size:13px}
.table th{text-align:left;padding:14px 12px;background:#f8fafc;color:#64748b;font-weight:600;border-bottom:1px solid #e2e8f0;white-space:nowrap}
.table td{padding:10px 12px;border-bottom:1px solid #f1f5f9;color:#334155;vertical-align:middle}
.table tr:not(.detail-row){cursor:pointer;transition:background .12s}
.table tr:not(.detail-row):hover td{background:#f0f7ff}
.table tr.row-expanded:not(.detail-row) td{background:#eff6ff}
.bold{font-weight:600}
.mono{font-family:"JetBrains Mono",monospace;font-size:11px}
.center{text-align:center;color:#94a3b8;font-size:11px}
.addr-cell{max-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.type-tag{font-size:11px;padding:2px 8px;border-radius:10px;background:#f1f5f9;color:#475569;white-space:nowrap}
.empty-hint{text-align:center;padding:40px 0;color:#94a3b8}

/* ── 展开详情 ── */
.detail-row td{padding:0;background:#f8faff;border-bottom:2px solid #e2e8f0}
.detail-panel{padding:16px 20px}
.detail-cols{display:flex;gap:20px}
.detail-card{flex:1;background:#fff;border-radius:10px;padding:16px;border:1px solid #e8edf3;min-width:0}
.detail-card-title{font-size:13px;font-weight:600;color:#1a1a2e;margin:0 0 12px}
.info-grid{display:flex;flex-direction:column;gap:6px}
.info-item{display:flex;gap:8px;font-size:12px;align-items:baseline}
.info-label{color:#94a3b8;min-width:56px;flex-shrink:0}
.stat-val{font-weight:600;color:#1a1a2e}
.revenue-item{margin-top:8px;padding-top:8px;border-top:1px dashed #e2e8f0}
.revenue-val{color:#059669 !important;font-size:16px;font-weight:700}
.live-dot{display:inline-block;width:6px;height:6px;background:#22c55e;border-radius:50%;margin-right:6px;animation:pulse 2s infinite}
@keyframes pulse{0%,100%{opacity:1;transform:scale(1)}50%{opacity:0.5;transform:scale(0.8)}}

/* ── 通用 ── */
.btn{padding:8px 16px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;cursor:pointer;font-size:13px}.btn-primary{background:#1a56db;color:#fff;border-color:#1a56db}
.error-msg{color:#ef4444;font-size:13px;margin-top:12px}
</style>
