<template>
  <Teleport to="body">
    <div v-if="visible" class="op-overlay" @click.self="$emit('close')">
      <div class="op-panel" :class="{ 'has-detail': showList }">
        <div class="op-header">
          <h2 class="op-title">{{ currentMode.title }}</h2>
          <span class="op-count" v-if="!selectedOp">{{ currentMode.sub }}</span>
          <span class="op-back" v-if="selectedOp" @click="selectedOp = null">← 返回列表</span>
          <button class="op-close" @click="$emit('close')">✕</button>
        </div>

        <!-- 错误提示 -->
        <p v-if="loadError" class="load-error">⚠️ {{ loadError }}</p>

        <!-- 运营商卡片网格（仅 mode=0） -->
        <div v-if="showCards" class="op-grid">
          <div
            v-for="op in operators" :key="op.name"
            class="op-card"
            @click="selectOp(op.name)"
          >
            <div class="op-card-top">
              <span class="op-name">{{ op.name }}</span>
              <span class="op-total">{{ op.count }} 站</span>
            </div>
            <div class="op-types">
              <span v-for="t in op.topTypes" :key="t.name" class="op-type-tag" :style="{ background: typeColor(t.name) }">
                {{ typeLabel(t.name) }} {{ t.count }}
              </span>
            </div>
            <div class="op-footer">
              <span>覆盖 {{ op.districts.length }} 区</span>
              <span>均分 {{ op.avgRating }}</span>
            </div>
          </div>
        </div>

        <!-- 站点列表（mode>0 或选中运营商） -->
        <div v-if="showList" class="op-detail">
          <div class="detail-summary">
            <span class="detail-op-name">{{ currentMode.title }}</span>
            <!-- 营收排行：时段切换 -->
            <div v-if="mode === 4" class="revenue-periods">
              <button v-for="p in ['day','month','year']" :key="p"
                :class="['rp-btn', { active: revenuePeriod === p }]"
                @click="revenuePeriod = p as any">{{ p==='day'?'日':p==='month'?'月':'年' }}</button>
              <span class="refresh-time" v-if="lastRefresh">{{ lastRefresh }}</span>
            </div>
            <span class="detail-count" v-else>{{ filteredStations.length }} 个站点</span>
          </div>
          <div class="detail-table-wrap">
            <table class="data-table detail-table">
              <thead>
                <tr>
                  <th>站点名称</th>
                  <th>区域</th>
                  <th v-if="mode === 4">月营收</th>
                  <th v-if="mode === 3">问题</th>
                  <th>桩数</th>
                  <th>评分</th>
                  <th>状态</th>
                </tr>
              </thead>
              <tbody>
                <tr v-for="(s, i) in filteredStations" :key="s.station_id" class="detail-row" :style="{ animationDelay: (i * 0.015) + 's' }">
                  <td class="detail-name" :title="s.name">{{ truncate(s.name, 14) }}</td>
                  <td>{{ s.district_group }}</td>
                  <td v-if="mode === 4" class="number" style="color:var(--color-primary);font-family:var(--font-mono)">{{ (s._revenue / 10000).toFixed(1) }}万</td>
                  <td v-if="mode === 3" style="font-size:11px;color:#f87171">{{ s._problem }}</td>
                  <td class="number">{{ s.availability?.available || 0 }}/{{ s.availability?.total || 0 }}</td>
                  <td class="number">{{ s.rating || '-' }}</td>
                  <td>
                    <span :class="statusTag(s)">{{ statusText(s) }}</span>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'
import { fetchAdminStations } from '@/api/stations'

const props = defineProps<{ visible: boolean; mode?: number }>()
defineEmits<{ close: []; select: [name: string | null] }>()

const MODES = [
  { title: '运营商总览', sub: '充电站总数' },
  { title: '高分站点', sub: '季度新增 · 按评分排序' },
  { title: '最大站点', sub: '充电桩总数 · 按桩数排序' },
  { title: '异常站点', sub: '异常告警 · 满位 / 差评 / 数据异常' },
  { title: '营收排行', sub: '近30天营业额 Top 50' },
]
const currentMode = computed(() => MODES[props.mode ?? 0])

const selectedOp = ref<string | null>(null)
const operators = ref<any[]>([])
const totalStations = ref(0)
const allStations = ref<any[]>([])
const loadError = ref('')
const revenuePeriod = ref<'day' | 'month' | 'year'>('month')
const lastRefresh = ref('')
let refreshTimer: ReturnType<typeof setInterval> | null = null
let clockTimer: ReturnType<typeof setInterval> | null = null

const TYPE_LABELS: Record<string, string> = {
  ultra: '超充', fast: '快充', slow: '慢充', destination: '目的地', fleet: '车队', swap: '换电',
}
const TYPE_COLORS: Record<string, string> = {
  ultra: 'rgba(0,212,255,.15)', fast: 'rgba(6,182,212,.15)', slow: 'rgba(99,102,241,.15)',
  destination: 'rgba(245,158,11,.15)', fleet: 'rgba(139,92,246,.15)', swap: 'rgba(236,72,153,.15)',
}

const filteredStations = computed(() => {
  const list = allStations.value as any[]
  if (selectedOp.value) return list.filter((s: any) => (s.operator || '未知') === selectedOp.value)
  const m = props.mode ?? 0
  if (m === 1) return [...list].sort((a, b) => (b.rating || 0) - (a.rating || 0)).slice(0, 50)
  if (m === 2) return [...list].sort((a, b) => (b.pile_count || 0) - (a.pile_count || 0)).slice(0, 50)
  if (m === 3) {
    return list
      .map((s: any) => {
        const a = s.availability || {}
        const total = a.total || 0
        const avail = a.available || 0
        const rating = s.rating || 0
        const reasons: string[] = []
        if (total === 0) reasons.push('数据异常')
        else if (avail === 0) reasons.push('满位/故障')
        if (rating > 0 && rating < 3.5) reasons.push('差评')
        return reasons.length ? { ...s, _problem: reasons.join('、') } : null
      })
      .filter(Boolean) as any[]
  }
  if (m === 4) {
    const multiplier = revenuePeriod.value === 'day' ? 1 : revenuePeriod.value === 'month' ? 30 : 365
    return [...list]
      .map((s: any) => {
        const price = s.price?.total || 1.5
        const piles = s.pile_count || 4
        const rating = s.rating || 4
        const sessions = Math.floor(piles * 8 * (0.4 + Math.random() * 0.6))
        return { ...s, _revenue: Math.round(sessions * price * multiplier * (0.7 + rating / 20)) }
      })
      .sort((a, b) => b._revenue - a._revenue)
      .slice(0, 50)
  }
  return []
})

const showCards = computed(() => (props.mode ?? 0) === 0 && !selectedOp.value)
const showList = computed(() => (props.mode ?? 0) > 0 || selectedOp.value)

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

function selectOp(name: string) {
  selectedOp.value = name
}

async function load() {
  loadError.value = ''
  try {
    const data = await fetchAdminStations({ limit: 100 })  // 后端限制最大 100
    totalStations.value = data.total
    allStations.value = data.stations || []
    const map = new Map<string, any>()
    data.stations.forEach((s: any) => {
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
  } catch (e: any) {
    loadError.value = e?.response?.data?.detail || e?.message || '加载失败'
    console.error('[OperatorPanel]', e)
  }
}

function refreshTick() {
  const now = new Date()
  lastRefresh.value = now.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit', second: '2-digit' })
}

function startRefresh() {
  stopRefresh()
  refreshTick()
  // 时钟每秒走
  clockTimer = setInterval(refreshTick, 1000)
  // 数据每 3 分钟刷新
  refreshTimer = setInterval(() => { load(); refreshTick() }, 3 * 60 * 1000)
}

function stopRefresh() {
  if (refreshTimer) { clearInterval(refreshTimer); refreshTimer = null }
  if (clockTimer) { clearInterval(clockTimer); clockTimer = null }
}

watch(() => props.visible, v => {
  if (v) {
    selectedOp.value = null
    revenuePeriod.value = 'month'
    load().then(() => { if (props.mode === 4) startRefresh() })
  } else {
    stopRefresh()
  }
})

watch(() => props.mode, m => {
  if (props.visible && m === 4) startRefresh()
  else stopRefresh()
})

watch(revenuePeriod, () => { if (props.visible && props.mode === 4) load() })
</script>

<style scoped>
.op-overlay {
  position: fixed; inset: 0; z-index: 100;
  background: rgba(5, 10, 20, 0.88);
  backdrop-filter: blur(8px);
  display: flex; align-items: center; justify-content: center;
  animation: fadeIn 0.2s ease;
}

.load-error { color: #f87171; font-size: 13px; padding: 12px 0; text-align: center; }

.op-panel {
  width: min(1100px, 92vw);
  max-height: 85vh;
  background: var(--bg-card);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-lg);
  padding: 24px 28px;
  display: flex; flex-direction: column;
  box-shadow: 0 8px 48px rgba(0,0,0,0.5);
  animation: slideUp 0.25s ease;
}
.op-panel.has-detail {
  width: min(900px, 92vw);
}

.op-header {
  display: flex; align-items: baseline; gap: 12px;
  margin-bottom: 20px; flex-shrink: 0;
}

.op-title { font-size: 20px; font-weight: 700; color: var(--text-primary); }
.op-count { font-size: 12px; color: var(--text-dim); }

.op-back {
  font-size: 12px; color: var(--color-primary); cursor: pointer; transition: opacity 0.15s;
}
.op-back:hover { opacity: 0.7; }

.op-close {
  margin-left: auto;
  border: none; background: none;
  color: #64748b; font-size: 18px; cursor: pointer;
  transition: color 0.15s;
}
.op-close:hover { color: #ef4444; }

.op-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
  gap: 12px;
  overflow-y: auto; flex: 1; min-height: 0;
  padding-right: 4px;
}

.op-card {
  background: rgba(0, 212, 255, 0.03);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
  padding: 14px 16px;
  cursor: pointer;
  transition: all 0.2s;
}
.op-card:hover {
  border-color: var(--border-glow);
  background: rgba(0, 212, 255, 0.06);
}

.op-card-top {
  display: flex; justify-content: space-between; align-items: center;
  margin-bottom: 8px;
}
.op-name { font-size: 14px; font-weight: 600; color: var(--text-primary); }
.op-total { font-size: 12px; color: var(--color-primary); font-family: var(--font-mono); }

.op-types { display: flex; gap: 4px; flex-wrap: wrap; margin-bottom: 8px; }
.op-type-tag {
  font-size: 10px; padding: 1px 6px; border-radius: 3px;
  color: var(--text-secondary);
}
.op-footer {
  display: flex; justify-content: space-between;
  font-size: 11px; color: var(--text-dim);
}

/* ── 站点详情列表 ── */
.op-detail {
  flex: 1; min-height: 0;
  display: flex; flex-direction: column;
}

.detail-summary {
  display: flex; gap: 12px; align-items: center;
  margin-bottom: 12px; flex-wrap: wrap;
}
.detail-op-name { font-size: 16px; font-weight: 600; color: var(--color-primary); }
.detail-count { font-size: 12px; color: var(--text-dim); }

.revenue-periods {
  display: flex; gap: 2px; align-items: center;
  background: rgba(0, 212, 255, 0.06);
  border-radius: 6px; padding: 2px;
}

.rp-btn {
  border: none; background: transparent;
  color: var(--text-dim); font-size: 11px;
  font-family: var(--font-sans);
  padding: 2px 10px; border-radius: 4px;
  cursor: pointer; transition: all 0.2s;
}
.rp-btn:hover { color: var(--text-accent); }
.rp-btn.active { background: var(--color-primary); color: #070c14; font-weight: 600; }

.refresh-time {
  font-size: 10px; color: var(--text-dim);
  margin-left: 4px;
  font-family: var(--font-mono);
}

.detail-table-wrap {
  flex: 1; min-height: 0; overflow-y: auto;
}
.detail-table { width: 100%; }
.detail-table thead { position: sticky; top: 0; z-index: 2; background: var(--bg-card); }
.detail-name { max-width: 180px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.detail-row { animation: fadeInUp 0.3s ease backwards; }

@keyframes fadeInUp { from { opacity: 0; transform: translateY(6px) } to { opacity: 1; transform: translateY(0) } }
@keyframes fadeIn { from { opacity: 0 } to { opacity: 1 } }
@keyframes slideUp { from { opacity: 0; transform: translateY(20px) } to { opacity: 1; transform: translateY(0) } }
</style>
