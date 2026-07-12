<template>
  <div class="page">
    <h1 class="page-title">运营商与营收</h1>

    <!-- ═══ 视图切换标签 ═══ -->
    <div class="view-tabs">
      <button
        v-for="tab in tabs"
        :key="tab.key"
        :class="['tab-btn', { active: activeTab === tab.key }]"
        @click="activeTab = tab.key"
      >
        {{ tab.label }}
      </button>
    </div>

    <!-- ═══ 运营商总览 ═══ -->
    <div v-if="activeTab === 'operators'">
      <div v-if="loading" class="loading-hint">加载中...</div>
      <div v-else-if="loadError" class="error-msg">⚠️ {{ loadError }}</div>
      <div v-else>
        <!-- 统计卡片 -->
        <div class="stat-grid">
          <div class="stat-card">
            <div class="stat-icon" style="background: #eff6ff">🏢</div>
            <div class="stat-info">
              <span class="stat-label">运营商总数</span>
              <span class="stat-value">{{ operators.length }}</span>
            </div>
          </div>
          <div class="stat-card">
            <div class="stat-icon" style="background: #f0fdf4">🔌</div>
            <div class="stat-info">
              <span class="stat-label">电站总数</span>
              <span class="stat-value">{{ totalStations }}</span>
            </div>
          </div>
          <div class="stat-card">
            <div class="stat-icon" style="background: #fef3c7">⭐</div>
            <div class="stat-info">
              <span class="stat-label">平均评分</span>
              <span class="stat-value">{{ avgRating }}</span>
            </div>
          </div>
        </div>

        <!-- 运营商卡片网格 -->
        <div class="op-grid">
          <div
            v-for="op in operators"
            :key="op.name"
            class="op-card"
            @click="selectedOp = op.name; opPage = 1"
          >
            <div class="op-card-top">
              <span class="op-name">{{ op.name }}</span>
              <span class="op-total">{{ op.count }} 站</span>
            </div>
            <div class="op-types">
              <span
                v-for="t in op.topTypes"
                :key="t.name"
                class="op-type-tag"
                :style="{ background: typeColor(t.name) }"
              >
                {{ typeLabel(t.name) }} {{ t.count }}
              </span>
            </div>
            <div class="op-footer">
              <span>覆盖 {{ op.districts.length }} 区</span>
              <span>均分 {{ op.avgRating }}</span>
            </div>
          </div>
        </div>

        <!-- 选中运营商的站点列表 -->
        <div v-if="selectedOp" class="op-detail">
          <div class="detail-header">
            <h2 class="detail-title">{{ selectedOp }} - 站点列表</h2>
            <span class="detail-count">共 {{ opAllStations.length }} 个站点</span>
            <button class="back-btn" @click="selectedOp = null">← 返回</button>
          </div>
          <div class="detail-table-wrap">
            <table class="data-table">
              <thead>
                <tr>
                  <th>站点名称</th>
                  <th>区域</th>
                  <th>桩数</th>
                  <th>评分</th>
                  <th>状态</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="s in filteredStations" :key="s.station_id">
                  <td class="detail-name" :title="s.name">{{ truncate(s.name, 20) }}</td>
                  <td>{{ s.district_group }}</td>
                  <td class="number">{{ s.availability?.available || 0 }}/{{ s.availability?.total || 0 }}</td>
                  <td class="number">{{ s.rating || '-' }}</td>
                  <td>
                    <span :class="statusTag(s)">{{ statusText(s) }}</span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <!-- 分页控件 -->
          <div class="op-pagination" v-if="opTotalPages > 1">
            <button
              class="page-btn"
              :disabled="opPage <= 1"
              @click="opPage = 1"
            >首页</button>
            <button
              class="page-btn"
              :disabled="opPage <= 1"
              @click="opPage--"
            >上一页</button>
            <span class="page-info">{{ opPage }} / {{ opTotalPages }}</span>
            <button
              class="page-btn"
              :disabled="opPage >= opTotalPages"
              @click="opPage++"
            >下一页</button>
            <button
              class="page-btn"
              :disabled="opPage >= opTotalPages"
              @click="opPage = opTotalPages"
            >末页</button>
          </div>
        </div>
      </div>
    </div>

    <!-- ═══ 营收排行 ═══ -->
    <div v-if="activeTab === 'revenue'">
      <div v-if="loading" class="loading-hint">加载中...</div>
      <div v-else-if="loadError" class="error-msg">⚠️ {{ loadError }}</div>
      <div v-else>
        <!-- 时段切换 -->
        <div class="revenue-controls">
          <div class="period-switch">
            <button
              v-for="p in periods"
              :key="p.key"
              :class="['period-btn', { active: revenuePeriod === p.key }]"
              @click="revenuePeriod = p.key as RevenuePeriod"
            >
              {{ p.label }}
            </button>
          </div>
          <div class="refresh-info">
            <span class="refresh-interval">
              <span class="live-dot"></span>
              {{ revenuePeriod === 'day' ? '30秒' : revenuePeriod === 'month' ? '5分钟' : '10分钟' }}刷新
            </span>
            <span class="refresh-countdown" v-if="nextRefresh">{{ nextRefresh }}</span>
            <span class="refresh-time" v-if="lastRefresh">更新于 {{ lastRefresh }}</span>
          </div>
        </div>

        <!-- 营收统计卡片 -->
        <div class="stat-grid">
          <div class="stat-card">
            <div class="stat-icon" style="background: #f5f3ff">💰</div>
            <div class="stat-info">
              <span class="stat-label">总营收</span>
              <span class="stat-value">{{ totalRevenue }}</span>
            </div>
          </div>
          <div class="stat-card">
            <div class="stat-icon" style="background: #fef2f2">🏆</div>
            <div class="stat-info">
              <span class="stat-label">最高营收站点</span>
              <span class="stat-value" style="font-size: 16px">{{ topStation }}</span>
            </div>
          </div>
          <div class="stat-card">
            <div class="stat-icon" style="background: #ecfdf5">📊</div>
            <div class="stat-info">
              <span class="stat-label">平均营收</span>
              <span class="stat-value">{{ avgRevenue }}</span>
            </div>
          </div>
        </div>

        <!-- 营收排行表格 -->
        <div class="revenue-table-wrap">
          <table class="data-table">
            <thead>
              <tr>
                <th>排名</th>
                <th>站点名称</th>
                <th>区域</th>
                <th>运营商</th>
                <th>桩数</th>
                <th>评分</th>
                <th>营收</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="(s, i) in revenueList" :key="s.station_id" class="revenue-row">
                <td class="rank-cell">
                  <span :class="['rank-badge', `rank-${i + 1}`]">{{ i + 1 }}</span>
                </td>
                <td class="detail-name" :title="s.name">{{ truncate(s.name, 18) }}</td>
                <td>{{ s.district_group }}</td>
                <td>{{ s.operator || '未知' }}</td>
                <td class="number">{{ s.availability?.total || 0 }}</td>
                <td class="number">{{ s.rating || '-' }}</td>
                <td class="number revenue-value">{{ formatRevenue(s._revenue) }}</td>
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { fetchAdminStations } from '@/api/stations'

// ═══════════ 视图切换 ═══════════
const tabs = [
  { key: 'operators', label: '运营商总览' },
  { key: 'revenue', label: '营收排行' },
]
const activeTab = ref('operators')

// ═══════════ 运营商数据 ═══════════
const loading = ref(true)
const loadError = ref('')
const operators = ref<any[]>([])
const totalStations = ref(0)
const allStations = ref<any[]>([])
const selectedOp = ref<string | null>(null)

// ═══════════ 分页状态 ═══════════
const opPage = ref(1)
const opPageSize = 20

// ═══════════ 营收数据 ═══════════
type RevenuePeriod = 'day' | 'month' | 'year'
const revenuePeriod = ref<RevenuePeriod>('month')
const lastRefresh = ref('')
const nextRefresh = ref('')
let clockTimer: ReturnType<typeof setInterval> | null = null
let revenueTimer: ReturnType<typeof setInterval> | null = null
let nextRefreshTime = 0

// 不同周期的刷新间隔（毫秒）
const REFRESH_INTERVALS: Record<RevenuePeriod, number> = {
  day: 30 * 1000,      // 日营收：30秒
  month: 5 * 60 * 1000, // 月营收：5分钟
  year: 10 * 60 * 1000, // 年营收：10分钟
}

const periods = [
  { key: 'day', label: '日营收' },
  { key: 'month', label: '月营收' },
  { key: 'year', label: '年营收' },
]

// ═══════════ 计算属性 ═══════════
const avgRating = computed(() => {
  if (!operators.value.length) return '-'
  const ratings = operators.value.filter((op: any) => op.avgRating !== '-').map((op: any) => parseFloat(op.avgRating))
  return ratings.length ? (ratings.reduce((a: number, b: number) => a + b, 0) / ratings.length).toFixed(1) : '-'
})

// 运营商下的所有站点（用于分页总数）
const opAllStations = computed(() => {
  if (!selectedOp.value) return []
  return allStations.value.filter((s: any) => (s.operator || '未知') === selectedOp.value)
})

// 分页后的站点列表
const filteredStations = computed(() => {
  const start = (opPage.value - 1) * opPageSize
  return opAllStations.value.slice(start, start + opPageSize)
})

// 总页数
const opTotalPages = computed(() => Math.max(1, Math.ceil(opAllStations.value.length / opPageSize)))

const revenueList = computed(() => {
  const multiplier = revenuePeriod.value === 'day' ? 1 : revenuePeriod.value === 'month' ? 30 : 365
  return [...allStations.value]
    .map((s: any) => {
      const price = s.price?.total || 1.5
      const piles = s.pile_count || 4
      const rating = s.rating || 4
      const sessions = Math.floor(piles * 8 * (0.4 + Math.random() * 0.6))
      return { ...s, _revenue: Math.round(sessions * price * multiplier * (0.7 + rating / 20)) }
    })
    .sort((a, b) => b._revenue - a._revenue)
    .slice(0, 50)
})

const totalRevenue = computed(() => {
  const total = revenueList.value.reduce((sum, s) => sum + s._revenue, 0)
  return formatRevenue(total)
})

const topStation = computed(() => {
  if (!revenueList.value.length) return '-'
  return truncate(revenueList.value[0].name, 12)
})

const avgRevenue = computed(() => {
  if (!revenueList.value.length) return '-'
  const avg = revenueList.value.reduce((sum, s) => sum + s._revenue, 0) / revenueList.value.length
  return formatRevenue(Math.round(avg))
})

// ═══════════ 辅助函数 ═══════════
const TYPE_LABELS: Record<string, string> = {
  ultra: '超充', fast: '快充', slow: '慢充', destination: '目的地', fleet: '车队', swap: '换电',
}
const TYPE_COLORS: Record<string, string> = {
  ultra: 'rgba(0,212,255,.15)', fast: 'rgba(6,182,212,.15)', slow: 'rgba(99,102,241,.15)',
  destination: 'rgba(245,158,11,.15)', fleet: 'rgba(139,92,246,.15)', swap: 'rgba(236,72,153,.15)',
}

function typeLabel(k: string) { return TYPE_LABELS[k] || k }
function typeColor(k: string) { return TYPE_COLORS[k] || 'rgba(100,116,139,.15)' }
function truncate(n: string, max: number) { return n.length > max ? n.slice(0, max) + '…' : n }

function statusTag(s: any): string {
  const a = s.availability || {}
  const rate = (a.total || 0) > 0 ? (a.available || 0) / a.total : 0
  if (rate < 0.2) return 'tag tag--red'
  if (rate < 0.5) return 'tag tag--yellow'
  return 'tag tag--green'
}

function statusText(s: any): string {
  const a = s.availability || {}
  const rate = (a.total || 0) > 0 ? (a.available || 0) / a.total : 0
  if (rate < 0.2) return '紧张'
  if (rate < 0.5) return '较忙'
  return '空闲'
}

function formatRevenue(value: number): string {
  if (value >= 10000) {
    return (value / 10000).toFixed(1) + '万'
  }
  return value.toLocaleString() + '元'
}

function refreshTick() {
  const now = new Date()
  lastRefresh.value = now.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
  updateNextRefresh()
}

// 计算下次刷新时间
function updateNextRefresh() {
  if (nextRefreshTime <= 0) {
    nextRefresh.value = ''
    return
  }
  const remaining = Math.max(0, nextRefreshTime - Date.now())
  const seconds = Math.ceil(remaining / 1000)
  if (seconds > 60) {
    const minutes = Math.floor(seconds / 60)
    const secs = seconds % 60
    nextRefresh.value = `${minutes}分${secs}秒后刷新`
  } else {
    nextRefresh.value = `${seconds}秒后刷新`
  }
}

// 启动营收数据定时刷新
function startRevenueRefresh() {
  stopRevenueRefresh()
  const interval = REFRESH_INTERVALS[revenuePeriod.value]
  nextRefreshTime = Date.now() + interval

  revenueTimer = setInterval(() => {
    load()
    nextRefreshTime = Date.now() + interval
    refreshTick()
  }, interval)
}

function stopRevenueRefresh() {
  if (revenueTimer) { clearInterval(revenueTimer); revenueTimer = null }
  nextRefreshTime = 0
  nextRefresh.value = ''
}

// ═══════════ 加载数据（分页获取所有电站） ═══════════
async function load() {
  loading.value = true
  loadError.value = ''
  try {
    // 先获取第一页，了解总数
    const firstPage = await fetchAdminStations({ limit: 100, offset: 0 })
    totalStations.value = firstPage.total
    let allData = [...(firstPage.stations || [])]

    // 计算总页数，获取剩余页
    const totalPages = Math.ceil(firstPage.total / 100)
    if (totalPages > 1) {
      const promises = []
      for (let page = 1; page < totalPages; page++) {
        promises.push(fetchAdminStations({ limit: 100, offset: page * 100 }))
      }
      const results = await Promise.all(promises)
      results.forEach(result => {
        if (result.stations) {
          allData = allData.concat(result.stations)
        }
      })
    }

    allStations.value = allData

    const map = new Map<string, any>()
    allData.forEach((s: any) => {
      const op = s.operator || '未知'
      if (!map.has(op)) {
        map.set(op, { name: op, count: 0, types: {} as Record<string, number>, ratings: [] as number[], districts: new Set<string>() })
      }
      const entry = map.get(op)!
      entry.count++
      entry.types[s.type] = (entry.types[s.type] || 0) + 1
      if (s.rating) entry.ratings.push(s.rating)
      if (s.district_group) entry.districts.add(s.district_group)
    })

    operators.value = Array.from(map.values())
      .map(op => ({
        ...op,
        topTypes: (Object.entries(op.types) as [string, number][]).sort((a, b) => b[1] - a[1]).slice(0, 3).map(([name, count]) => ({ name, count })),
        avgRating: op.ratings.length ? (op.ratings.reduce((a: number, b: number) => a + b, 0) / op.ratings.length).toFixed(1) : '-',
        districts: Array.from(op.districts),
      }))
      .sort((a, b) => b.count - a.count)

    loading.value = false
    refreshTick()
  } catch (e: any) {
    loadError.value = e?.response?.data?.detail || e?.message || '加载失败'
    loading.value = false
    console.error('[OperatorsPage]', e)
  }
}

// ═══════════ 监听营收周期变化 ═══════════
watch(revenuePeriod, () => {
  startRevenueRefresh()
})

// ═══════════ 生命周期 ═══════════
onMounted(() => {
  load()
  clockTimer = setInterval(refreshTick, 1000)
  startRevenueRefresh()
})

onUnmounted(() => {
  if (clockTimer) { clearInterval(clockTimer); clockTimer = null }
  stopRevenueRefresh()
})
</script>

<style scoped>
.page { padding: 32px; }
.page-title { margin: 0 0 24px; font-size: 20px; color: #1a1a2e; }

/* ── 视图切换标签 ── */
.view-tabs {
  display: flex;
  gap: 8px;
  margin-bottom: 24px;
  background: #f1f5f9;
  border-radius: 8px;
  padding: 4px;
  width: fit-content;
}
.tab-btn {
  border: none;
  background: transparent;
  padding: 8px 20px;
  border-radius: 6px;
  font-size: 14px;
  color: #64748b;
  cursor: pointer;
  transition: all 0.2s;
}
.tab-btn:hover { color: #1a1a2e; }
.tab-btn.active { background: #fff; color: #1a56db; font-weight: 600; box-shadow: 0 1px 4px rgba(0,0,0,0.08); }

/* ── 统计卡片 ── */
.loading-hint { color: #94a3b8; font-size: 13px; }
.error-msg { color: #ef4444; font-size: 13px; margin-bottom: 16px; }
.stat-grid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px; margin-bottom: 24px; }
.stat-card { background: #fff; border-radius: 12px; padding: 20px; display: flex; align-items: center; gap: 16px; box-shadow: 0 1px 8px rgba(0,0,0,0.04); }
.stat-icon { width: 48px; height: 48px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 22px; flex-shrink: 0; }
.stat-info { display: flex; flex-direction: column; min-width: 0; }
.stat-label { font-size: 12px; color: #94a3b8; }
.stat-value { font-size: 26px; font-weight: 700; color: #1a1a2e; }

/* ── 运营商卡片网格 ── */
.op-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 16px;
  margin-bottom: 32px;
}
.op-card {
  background: #fff;
  border: 1px solid #e2e8f0;
  border-radius: 12px;
  padding: 16px;
  cursor: pointer;
  transition: all 0.2s;
}
.op-card:hover {
  border-color: #1a56db;
  box-shadow: 0 4px 12px rgba(26, 86, 219, 0.1);
}
.op-card-top {
  display: flex; justify-content: space-between; align-items: center;
  margin-bottom: 8px;
}
.op-name { font-size: 14px; font-weight: 600; color: #1a1a2e; }
.op-total { font-size: 12px; color: #1a56db; font-family: 'Monaco', monospace; }
.op-types { display: flex; gap: 4px; flex-wrap: wrap; margin-bottom: 8px; }
.op-type-tag {
  font-size: 10px; padding: 2px 8px; border-radius: 4px;
  color: #475569;
}
.op-footer {
  display: flex; justify-content: space-between;
  font-size: 11px; color: #94a3b8;
}

/* ── 站点详情 ── */
.op-detail {
  background: #fff;
  border-radius: 12px;
  padding: 24px;
  box-shadow: 0 1px 8px rgba(0,0,0,0.04);
}
.detail-header {
  display: flex;
  align-items: center;
  gap: 12px;
  margin-bottom: 16px;
}
.detail-title { font-size: 16px; font-weight: 600; color: #1a1a2e; }
.detail-count { font-size: 12px; color: #94a3b8; margin-left: 4px; }
.back-btn {
  border: 1px solid #e2e8f0;
  background: #f8fafc;
  padding: 6px 12px;
  border-radius: 6px;
  font-size: 12px;
  color: #475569;
  cursor: pointer;
  transition: all 0.2s;
}
.back-btn:hover { border-color: #1a56db; color: #1a56db; }

.detail-table-wrap { overflow-x: auto; }
.data-table { width: 100%; border-collapse: collapse; }
.data-table th { text-align: left; padding: 10px 12px; font-size: 12px; color: #64748b; border-bottom: 1px solid #e2e8f0; background: #fff; }
.data-table td { padding: 12px; font-size: 13px; color: #1a1a2e; border-bottom: 1px solid #f1f5f9; background: #fff; }
.data-table tr { transition: background-color 0.15s; }
.data-table tr:hover { background-color: #f0f7ff !important; }
.data-table tr:hover td { background-color: #f0f7ff !important; color: #1a1a2e !important; }
.detail-name { max-width: 200px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.number { font-family: 'Monaco', monospace; }

.tag { padding: 2px 8px; border-radius: 4px; font-size: 11px; }
.tag--green { background: #f0fdf4; color: #16a34a; }
.tag--yellow { background: #fefce8; color: #ca8a04; }
.tag--red { background: #fef2f2; color: #dc2626; }

/* ── 分页控件 ── */
.op-pagination {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  margin-top: 20px;
  padding-top: 16px;
  border-top: 1px solid #f1f5f9;
}
.page-btn {
  padding: 6px 14px;
  border: 1px solid #e2e8f0;
  background: #fff;
  border-radius: 6px;
  font-size: 12px;
  color: #475569;
  cursor: pointer;
  transition: all 0.15s;
}
.page-btn:hover:not(:disabled) {
  border-color: #1a56db;
  color: #1a56db;
}
.page-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}
.page-info {
  font-size: 12px;
  color: #64748b;
  margin: 0 8px;
  font-family: 'Monaco', monospace;
}

/* ── 营收控制栏 ── */
.revenue-controls {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 24px;
}
.period-switch {
  display: flex;
  gap: 4px;
  background: #f1f5f9;
  border-radius: 8px;
  padding: 4px;
}
.period-btn {
  border: none;
  background: transparent;
  padding: 8px 16px;
  border-radius: 6px;
  font-size: 13px;
  color: #64748b;
  cursor: pointer;
  transition: all 0.2s;
}
.period-btn:hover { color: #1a1a2e; }
.period-btn.active { background: #fff; color: #1a56db; font-weight: 600; box-shadow: 0 1px 4px rgba(0,0,0,0.08); }
.refresh-info { display: flex; align-items: center; gap: 12px; }
.refresh-interval { display: flex; align-items: center; gap: 4px; font-size: 11px; color: #059669; background: #f0fdf4; padding: 4px 10px; border-radius: 12px; }
.refresh-countdown { font-size: 11px; color: #64748b; font-family: 'Monaco', monospace; }
.refresh-time { font-size: 11px; color: #94a3b8; }
.live-dot { display: inline-block; width: 6px; height: 6px; background: #22c55e; border-radius: 50%; animation: pulse 2s infinite; }
@keyframes pulse { 0%, 100% { opacity: 1; transform: scale(1); } 50% { opacity: 0.5; transform: scale(0.8); } }

/* ── 营收排行表格 ── */
.revenue-table-wrap {
  background: #fff;
  border-radius: 12px;
  padding: 24px;
  box-shadow: 0 1px 8px rgba(0,0,0,0.04);
}
.revenue-row { transition: background 0.15s; }
.revenue-row:hover { background: #f0f7ff !important; }
.revenue-row:hover td { background: #f0f7ff !important; color: #1a1a2e !important; }
.rank-cell { width: 60px; text-align: center; }
.rank-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  border-radius: 50%;
  font-size: 12px;
  font-weight: 600;
  background: #f1f5f9;
  color: #64748b;
}
.rank-1 { background: #fef3c7; color: #b45309; }
.rank-2 { background: #e2e8f0; color: #475569; }
.rank-3 { background: #fed7aa; color: #c2410c; }
.revenue-value { color: #1a56db; font-weight: 600; }
</style>
