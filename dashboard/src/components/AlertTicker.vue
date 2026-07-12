<template>
  <div class="alert-ticker" v-if="alerts.length">
    <span class="ticker-label">⚡ 实时告警</span>
    <div class="ticker-track" @mouseenter="pause" @mouseleave="resume">
      <div class="ticker-scroll" ref="scrollRef" :style="{ animationPlayState: playing ? 'running' : 'paused', animationDuration: scrollDuration }">
        <template v-for="(a, i) in displayAlerts" :key="i">
          <span
            class="ticker-item"
            :class="a.level"
            @click="emit('stationClick', a.station_id)"
          >
            <span class="ticker-dot"></span>
            {{ a.district }} · {{ a.name }} 仅剩 <b>{{ a.available }}/{{ a.total }}</b> 桩
            <span class="ticker-sep">·</span>
          </span>
        </template>
      </div>
    </div>
    <div class="ticker-summary">
      <span class="ticker-count clickable" @click="openDialog">{{ alerts.length }}个告警</span>
      <span class="ticker-separator">|</span>
      <span class="summary-critical"><span class="summary-dot critical"></span>{{ criticalCount }}严重</span>
      <span class="summary-warning"><span class="summary-dot warning"></span>{{ warningCount }}警告</span>
    </div>

    <!-- 告警站点列表弹窗 -->
    <Teleport to="body">
      <div v-if="showDialog" class="alert-dialog-overlay" @click.self="showDialog = false">
        <div class="alert-dialog">
          <div class="alert-dialog-header">
            <div class="alert-dialog-title">
              <span class="alert-dialog-icon">⚡</span>
              告警站点列表
              <span class="alert-dialog-badge">{{ alerts.length }}</span>
            </div>
            <button class="alert-dialog-close" @click="showDialog = false">✕</button>
          </div>
          <div class="alert-dialog-stats">
            <span class="stat-item critical"><span class="summary-dot critical"></span>{{ criticalCount }} 严重</span>
            <span class="stat-item warning"><span class="summary-dot warning"></span>{{ warningCount }} 警告</span>
          </div>
          <div class="alert-dialog-body">
            <div class="alert-search-bar">
              <svg class="search-icon" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
              <input
                v-model="searchQuery"
                class="search-input"
                type="text"
                placeholder="搜索站点名称或区域..."
              />
              <span v-if="searchQuery" class="search-clear" @click="searchQuery = ''">✕</span>
              <span class="search-count" v-if="searchQuery">{{ filteredAlerts.length }}/{{ alerts.length }}</span>
            </div>
            <div class="alert-table-header">
              <span class="col-idx">#</span>
              <span class="col-name">站点名称</span>
              <span class="col-district">区域</span>
              <span class="col-avail">可用/总数</span>
              <span class="col-rate">可用率</span>
              <span class="col-level">级别</span>
            </div>
            <div class="alert-table-scroll">
              <div
                v-for="(a, i) in filteredAlerts"
                :key="a.station_id"
                class="alert-table-row"
                :class="a.level"
                @click="handleStationClick(a.station_id)"
              >
                <span class="col-idx">{{ i + 1 }}</span>
                <span class="col-name">{{ a.name }}</span>
                <span class="col-district">{{ a.district }}</span>
                <span class="col-avail"><b>{{ a.available }}</b>/{{ a.total }}</span>
                <span class="col-rate">
                  <span class="rate-bar">
                    <span class="rate-fill" :style="{ width: (a.total > 0 ? a.available / a.total * 100 : 0) + '%' }" :class="a.level"></span>
                  </span>
                  {{ a.total > 0 ? (a.available / a.total * 100).toFixed(0) : 0 }}%
                </span>
                <span class="col-level"><span class="level-tag" :class="a.level">{{ a.level === 'critical' ? '严重' : '警告' }}</span></span>
              </div>
              <div v-if="filteredAlerts.length === 0" class="alert-empty">
                未找到匹配的站点
              </div>
            </div>
          </div>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { getStationStatus } from '@/api/dashboard'

const emit = defineEmits<{ stationClick: [id: string] }>()

const showDialog = ref(false)
const searchQuery = ref('')

// 根据搜索关键词过滤告警列表（匹配站点名称或区域）
const filteredAlerts = computed(() => {
  const q = searchQuery.value.trim().toLowerCase()
  if (!q) return alerts.value
  return alerts.value.filter(a =>
    a.name.toLowerCase().includes(q) || a.district.toLowerCase().includes(q)
  )
})

function handleStationClick(stationId: string) {
  showDialog.value = false
  emit('stationClick', stationId)
}

// 打开弹窗时清空搜索
function openDialog() {
  searchQuery.value = ''
  showDialog.value = true
}

interface Alert {
  id: string
  district: string
  name: string
  available: number
  total: number
  level: 'critical' | 'warning'
  station_id: string
}

const alerts = ref<Alert[]>([])
const playing = ref(true)

// 复制一份数据实现无缝滚动
const displayAlerts = computed(() => [...alerts.value, ...alerts.value])

// 告警统计
const criticalCount = computed(() => alerts.value.filter(a => a.level === 'critical').length)
const warningCount = computed(() => alerts.value.filter(a => a.level === 'warning').length)

// 滚动速度根据告警数量动态调整：每条约 3.5 秒（一行展示约 5 个，画面不闪）
const scrollDuration = computed(() => {
  const n = alerts.value.length
  if (n === 0) return '30s'
  return `${Math.max(n * 6, 30)}s`
})

const scrollRef = ref<HTMLElement | null>(null)

function pause() { playing.value = false }
function resume() { playing.value = true }

// 从后端加载站点数据，筛选可用率低的站点作为告警
onMounted(async () => {
  try {
    const data = await getStationStatus()
    const stations = data.stations || []
    const alertList: Alert[] = []

    for (const s of stations) {
      const avail = s.availability || {}
      const total = avail.total || 0
      const available = avail.available || 0
      if (total === 0) continue

      const rate = available / total
      if (rate < 0.3) {
        alertList.push({
          id: s.station_id,
          district: s.district_group || '',
          name: s.name,
          available,
          total,
          level: rate === 0 ? 'critical' : 'warning',
          station_id: s.station_id,
        })
      }
    }

    // 按可用率从低到高排序
    alertList.sort((a, b) => (a.available / a.total) - (b.available / b.total))
    alerts.value = alertList
  } catch (_) {
    // 后端不可用时无告警显示
  }
})
</script>

<style scoped>
.alert-ticker {
  display: flex;
  align-items: center;
  height: 28px;
  background: #fff2f0;
  border: 1px solid #ffccc7;
  border-radius: 4px;
  margin: 0 12px;
  overflow: hidden;
  flex-shrink: 0;
  z-index: 2;
}
.ticker-label {
  flex-shrink: 0;
  font-size: 10px; font-weight: 700; color: #ff4d4f;
  padding: 0 10px; letter-spacing: 0.04em;
  background: #fff1f0;
  height: 100%; display: flex; align-items: center;
  border-right: 1px solid #ffccc7;
}
.ticker-track {
  flex: 1;
  overflow-x: auto; overflow-y: hidden; white-space: nowrap;
  scrollbar-width: none;
  mask-image: linear-gradient(90deg, transparent 0%, black 4%, black 96%, transparent 100%);
}
.ticker-track::-webkit-scrollbar { display: none; }
.ticker-scroll {
  display: inline-flex; align-items: center;
  animation-name: tickerScroll;
  animation-timing-function: linear;
  animation-iteration-count: infinite;
}
@keyframes tickerScroll {
  0%   { transform: translateX(0); }
  100% { transform: translateX(-50%); }
}
.ticker-item {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: 11px; color: #4b5563;
  padding: 0 12px; cursor: pointer;
  transition: color 0.15s; flex-shrink: 0;
}
.ticker-item:hover { color: #faad14; }
.ticker-item.warning { color: #faad14; }
.ticker-item.critical { color: #ff4d4f; }
.ticker-item.warning .ticker-dot { background: #faad14; }
.ticker-item.critical .ticker-dot { background: #ff4d4f; }
.ticker-dot { width: 5px; height: 5px; border-radius: 50%; flex-shrink: 0; }
.ticker-item b { font-weight: 700; font-family: var(--font-mono); }
.ticker-sep { color: #d1d5db; margin: 0 2px; font-weight: 300; }
.ticker-summary {
  flex-shrink: 0;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 0 12px;
  background: #fff1f0;
  height: 100%;
  border-left: 1px solid #ffccc7;
  font-size: 10px;
}

.ticker-count {
  font-weight: 600; color: #ff4d4f;
}

.ticker-separator {
  color: #ffccc7;
}

.summary-critical {
  display: flex;
  align-items: center;
  gap: 4px;
  color: #ff4d4f;
  font-weight: 500;
}

.summary-warning {
  display: flex;
  align-items: center;
  gap: 4px;
  color: #faad14;
  font-weight: 500;
}

.summary-dot {
  width: 6px;
  height: 6px;
  border-radius: 50%;
}

.summary-dot.critical {
  background: #ff4d4f;
}

.summary-dot.warning {
  background: #faad14;
}

.clickable {
  cursor: pointer;
  transition: opacity 0.15s;
}
.clickable:hover {
  opacity: 0.7;
}

/* ── 告警弹窗 ── */
.alert-dialog-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.45);
  z-index: 9999;
  display: flex;
  align-items: center;
  justify-content: center;
  animation: fadeIn 0.15s ease;
}
@keyframes fadeIn {
  from { opacity: 0; }
  to { opacity: 1; }
}
.alert-dialog {
  width: 720px;
  max-height: 75vh;
  background: #fff;
  border-radius: 12px;
  box-shadow: 0 16px 48px rgba(0, 0, 0, 0.2);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  animation: slideUp 0.2s ease;
}
@keyframes slideUp {
  from { opacity: 0; transform: translateY(16px); }
  to { opacity: 1; transform: translateY(0); }
}
.alert-dialog-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 16px 20px;
  border-bottom: 1px solid #f0f0f0;
}
.alert-dialog-title {
  font-size: 16px;
  font-weight: 700;
  color: #1f2937;
  display: flex;
  align-items: center;
  gap: 8px;
}
.alert-dialog-icon { font-size: 18px; }
.alert-dialog-badge {
  background: #ff4d4f;
  color: #fff;
  font-size: 11px;
  font-weight: 700;
  padding: 2px 8px;
  border-radius: 10px;
  line-height: 1.4;
}
.alert-dialog-close {
  background: none;
  border: none;
  font-size: 16px;
  color: #9ca3af;
  cursor: pointer;
  padding: 4px 8px;
  border-radius: 4px;
  transition: all 0.15s;
}
.alert-dialog-close:hover {
  color: #ff4d4f;
  background: #fff2f0;
}
.alert-dialog-stats {
  display: flex;
  gap: 16px;
  padding: 10px 20px;
  background: #fafafa;
  border-bottom: 1px solid #f0f0f0;
  font-size: 12px;
}
.stat-item {
  display: flex;
  align-items: center;
  gap: 5px;
  font-weight: 500;
}
.stat-item.critical { color: #ff4d4f; }
.stat-item.warning { color: #faad14; }
.alert-dialog-body {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
}
.alert-table-header {
  display: flex;
  align-items: center;
  padding: 10px 20px;
  background: #fafafa;
  font-size: 11px;
  font-weight: 600;
  color: #6b7280;
  border-bottom: 1px solid #f0f0f0;
  flex-shrink: 0;
}
.alert-table-scroll {
  flex: 1;
  overflow-y: auto;
  min-height: 0;
}
.alert-table-row {
  display: flex;
  align-items: center;
  padding: 10px 20px;
  font-size: 12px;
  color: #374151;
  border-bottom: 1px solid #f9fafb;
  cursor: pointer;
  transition: background 0.12s;
}
.alert-table-row:hover {
  background: #f0f7ff;
}
.alert-table-row.critical:hover {
  background: #fff1f0;
}
.alert-table-row.warning:hover {
  background: #fffbe6;
}
.col-idx { width: 36px; color: #9ca3af; font-family: var(--font-mono); flex-shrink: 0; }
.col-name { flex: 2; font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.col-district { flex: 1; color: #6b7280; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.col-avail { width: 80px; text-align: center; flex-shrink: 0; }
.col-avail b { color: #1677ff; font-weight: 700; }
.col-rate { width: 100px; display: flex; align-items: center; gap: 6px; font-family: var(--font-mono); font-size: 11px; flex-shrink: 0; }
.rate-bar {
  width: 40px;
  height: 4px;
  background: #f0f0f0;
  border-radius: 2px;
  overflow: hidden;
  flex-shrink: 0;
}
.rate-fill {
  height: 100%;
  border-radius: 2px;
  transition: width 0.3s;
}
.rate-fill.critical { background: #ff4d4f; }
.rate-fill.warning { background: #faad14; }
.col-level { width: 50px; text-align: center; flex-shrink: 0; }
.level-tag {
  font-size: 10px;
  font-weight: 600;
  padding: 2px 8px;
  border-radius: 4px;
}
.level-tag.critical {
  color: #ff4d4f;
  background: #fff1f0;
}
.level-tag.warning {
  color: #faad14;
  background: #fffbe6;
}

/* ── 搜索栏 ── */
.alert-search-bar {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 10px 20px;
  border-bottom: 1px solid #f0f0f0;
  flex-shrink: 0;
}
.search-icon {
  color: #9ca3af;
  flex-shrink: 0;
}
.search-input {
  flex: 1;
  border: none;
  outline: none;
  font-size: 13px;
  color: #1f2937;
  background: transparent;
  font-family: inherit;
}
.search-input::placeholder {
  color: #c0c4cc;
}
.search-clear {
  color: #c0c4cc;
  cursor: pointer;
  font-size: 12px;
  padding: 2px 6px;
  border-radius: 4px;
  transition: all 0.12s;
  flex-shrink: 0;
}
.search-clear:hover {
  color: #ff4d4f;
  background: #fff1f0;
}
.search-count {
  color: #9ca3af;
  font-size: 11px;
  font-family: var(--font-mono);
  flex-shrink: 0;
}
.alert-empty {
  padding: 40px 20px;
  text-align: center;
  color: #c0c4cc;
  font-size: 13px;
}
</style>
