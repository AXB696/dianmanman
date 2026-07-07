<template>
  <div class="panel" style="display:flex;flex-direction:column;height:100%;position:relative">
    <div class="panel-title">充电站状态监控</div>

    <template v-if="!selectedStation">
      <div class="section">
        <div class="section-title section-title--busy">⚠️ 最紧张站点</div>
        <div class="table-scroll-wrap" @mouseenter="pause" @mouseleave="resume">
          <div class="table-scroll-inner" :style="{ animationPlayState: playing ? 'running' : 'paused' }">
            <table class="data-table">
              <thead><tr><th>站点名称</th><th>区域</th><th>可用/总桩</th><th>评分</th><th>状态</th></tr></thead>
              <tbody>
                <tr v-for="(s, i) in busyStations" :key="s.station_id"
                    :style="{ animationDelay: staggerDelay(i, 0.03) }"
                    class="table-row clickable" @click="openDetail(s)">
                  <td class="station-name" :title="s.name">{{ truncate(s.name, 8) }}</td>
                  <td>{{ s.district_group }}</td>
                  <td><span :style="{ color: availabilityColor(s) }">{{ s.availability.available }}/{{ s.availability.total }}</span></td>
                  <td class="number">{{ formatRating(s.rating) }}</td>
                  <td><span :class="statusTag(s)">{{ statusText(s) }}</span></td>
                </tr>
              </tbody>
            </table>
            <table class="data-table">
              <tbody>
                <tr v-for="s in busyStations" :key="'copy-busy-' + s.station_id"
                    class="table-row clickable" @click="openDetail(s)">
                  <td class="station-name" :title="s.name">{{ truncate(s.name, 8) }}</td>
                  <td>{{ s.district_group }}</td>
                  <td><span :style="{ color: availabilityColor(s) }">{{ s.availability.available }}/{{ s.availability.total }}</span></td>
                  <td class="number">{{ formatRating(s.rating) }}</td>
                  <td><span :class="statusTag(s)">{{ statusText(s) }}</span></td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div class="section">
        <div class="section-title section-title--idle">✅ 最空闲站点</div>
        <div class="table-scroll-wrap" @mouseenter="pause" @mouseleave="resume">
          <div class="table-scroll-inner" :style="{ animationPlayState: playing ? 'running' : 'paused' }">
            <table class="data-table">
              <thead><tr><th>站点名称</th><th>区域</th><th>可用/总桩</th><th>评分</th><th>状态</th></tr></thead>
              <tbody>
                <tr v-for="(s, i) in idleStations" :key="s.station_id"
                    :style="{ animationDelay: staggerDelay(i, 0.03) }"
                    class="table-row clickable" @click="openDetail(s)">
                  <td class="station-name" :title="s.name">{{ truncate(s.name, 8) }}</td>
                  <td>{{ s.district_group }}</td>
                  <td><span :style="{ color: availabilityColor(s) }">{{ s.availability.available }}/{{ s.availability.total }}</span></td>
                  <td class="number">{{ formatRating(s.rating) }}</td>
                  <td><span :class="statusTag(s)">{{ statusText(s) }}</span></td>
                </tr>
              </tbody>
            </table>
            <table class="data-table">
              <tbody>
                <tr v-for="s in idleStations" :key="'copy-idle-' + s.station_id"
                    class="table-row clickable" @click="openDetail(s)">
                  <td class="station-name" :title="s.name">{{ truncate(s.name, 8) }}</td>
                  <td>{{ s.district_group }}</td>
                  <td><span :style="{ color: availabilityColor(s) }">{{ s.availability.available }}/{{ s.availability.total }}</span></td>
                  <td class="number">{{ formatRating(s.rating) }}</td>
                  <td><span :class="statusTag(s)">{{ statusText(s) }}</span></td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </template>

    <div v-if="selectedStation" class="detail-panel">
      <div class="detail-header">
        <span class="detail-back" @click="closeDetail">← 返回</span>
        <span class="detail-close" @click="closeDetail">✕</span>
      </div>
      <div class="detail-body">
        <div class="detail-name">{{ selectedStation.name }}</div>
        <div class="detail-tags">
          <span class="detail-tag">{{ selectedStation.district_group }}</span>
          <span class="detail-tag detail-tag--type">{{ selectedStation.type_name || selectedStation.type }}</span>
          <span class="detail-tag detail-tag--rating">★ {{ formatRating(selectedStation.rating) }}</span>
        </div>
        <div class="detail-avail">
          <div class="detail-avail-header">
            <span>桩位占用</span>
            <span class="number">{{ selectedStation.availability.occupied }}/{{ selectedStation.availability.total }}</span>
          </div>
          <div class="detail-avail-bar">
            <div class="detail-avail-fill" :style="{
              width: availPercent + '%',
              background: availPercent > 80 ? 'var(--color-danger)' : availPercent > 50 ? 'var(--color-warning)' : 'var(--color-primary)'
            }"></div>
          </div>
          <div class="detail-avail-stats">
            <span>空闲 <b :style="{ color: 'var(--color-primary)' }">{{ selectedStation.availability.available }}</b></span>
            <span>占用 <b :style="{ color: 'var(--color-warning)' }">{{ selectedStation.availability.occupied }}</b></span>
          </div>
        </div>
        <div class="detail-info-grid">
          <div class="detail-info-item" v-if="selectedStation.address">
            <span class="detail-label">地址</span>
            <span class="detail-value">{{ selectedStation.address }}</span>
          </div>
          <div class="detail-info-item">
            <span class="detail-label">运营商</span>
            <span class="detail-value">{{ (selectedStation as any).operator || '未知' }}</span>
          </div>
          <div class="detail-info-item">
            <span class="detail-label">充电桩数</span>
            <span class="detail-value">{{ selectedStation.pile_count }} 个</span>
          </div>
          <div class="detail-info-item">
            <span class="detail-label">单桩功率</span>
            <span class="detail-value">{{ selectedStation.power_kw }} kW</span>
          </div>
          <div class="detail-info-item" v-if="selectedStation.price">
            <span class="detail-label">电价</span>
            <span class="detail-value" style="color:#fbbf24">{{ selectedStation.price.total }}{{ selectedStation.price.unit }}</span>
          </div>
          <div class="detail-info-item" v-if="(selectedStation as any).tel">
            <span class="detail-label">电话</span>
            <span class="detail-value">📞 {{ (selectedStation as any).tel }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { formatRating } from '@/utils/format'
import { staggerDelay } from '@/utils/animation'
import { getStationStatus, type StationStatus } from '@/api/dashboard'

const busyStations = ref<StationStatus[]>([])
const idleStations = ref<StationStatus[]>([])
const playing = ref(true)
const selectedStation = ref<StationStatus | null>(null)

const availPercent = computed(() => {
  if (!selectedStation.value) return 0
  const { total, occupied } = selectedStation.value.availability
  return total > 0 ? Math.round((occupied / total) * 100) : 0
})

function pause() { playing.value = false }
function resume() { playing.value = true }
function openDetail(s: StationStatus) { selectedStation.value = s; playing.value = false }
function closeDetail() { selectedStation.value = null; playing.value = true }

// 从后端加载站点数据，按可用率排序分紧张/空闲
onMounted(async () => {
  try {
    const data = await getStationStatus()
    const all = data.stations || []
    // 按可用率从低到高排序
    const sorted = [...all].sort((a, b) => {
      const rateA = a.availability.total > 0 ? a.availability.available / a.availability.total : 1
      const rateB = b.availability.total > 0 ? b.availability.available / b.availability.total : 1
      return rateA - rateB
    })
    busyStations.value = sorted.slice(0, 10)  // 最紧张10个
    idleStations.value = sorted.reverse().slice(0, 10)  // 最空闲10个
  } catch (_) {}
})

function truncate(name: string, max: number): string {
  return name.length > max ? name.slice(0, max) + '…' : name
}
function availabilityColor(s: StationStatus): string {
  const rate = s.availability.total > 0 ? s.availability.available / s.availability.total : 0
  if (rate < 0.2) return 'var(--color-danger)'
  if (rate < 0.5) return 'var(--color-warning)'
  return 'var(--color-primary)'
}
function statusTag(s: StationStatus): string {
  const rate = s.availability.total > 0 ? s.availability.available / s.availability.total : 0
  if (rate < 0.2) return 'tag tag--red'
  if (rate < 0.5) return 'tag tag--yellow'
  return 'tag tag--green'
}
function statusText(s: StationStatus): string {
  const rate = s.availability.total > 0 ? s.availability.available / s.availability.total : 0
  if (rate < 0.2) return '紧张'
  if (rate < 0.5) return '较忙'
  return '空闲'
}
</script>

<style scoped>
.section { display: flex; flex-direction: column; flex: 1; min-height: 0; overflow: hidden; }
.section-title { font-size: 11px; font-weight: 600; padding: 4px 0 6px; flex-shrink: 0; }
.section-title--busy { color: #f87171; }
.section-title--idle { color: #22d3a7; }
.table-scroll-wrap { flex: 1; min-height: 0; overflow: hidden; position: relative; }
.table-scroll-inner { animation: scrollUp 20s linear infinite; display: flex; flex-direction: column; }
.clickable { cursor: pointer; transition: background 0.15s; }
.clickable:hover { background: rgba(0, 212, 255, 0.06) !important; }
.station-name { max-width: 90px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.table-row { animation: fadeInUp 0.4s ease backwards; }

/* 固定列宽确保紧张/空闲两表对齐 */
.data-table { table-layout: fixed; }
.data-table th:nth-child(1), .data-table td:nth-child(1) { width: 40%; }
.data-table th:nth-child(2), .data-table td:nth-child(2) { width: 12%; }
.data-table th:nth-child(3), .data-table td:nth-child(3) { width: 18%; text-align: center; }
.data-table th:nth-child(4), .data-table td:nth-child(4) { width: 12%; text-align: right; }
.data-table th:nth-child(5), .data-table td:nth-child(5) { width: 18%; text-align: center; }

.detail-panel { flex: 1; display: flex; flex-direction: column; min-height: 0; animation: slideIn 0.25s ease; }
.detail-header { display: flex; justify-content: space-between; align-items: center; padding: 2px 0 8px; flex-shrink: 0; }
.detail-back { font-size: 12px; color: var(--color-primary); cursor: pointer; }
.detail-back:hover { opacity: 0.7; }
.detail-close { font-size: 14px; color: #64748b; cursor: pointer; }
.detail-close:hover { color: #ef4444; }
.detail-body { flex: 1; overflow-y: auto; min-height: 0; padding-right: 4px; }
.detail-name { font-size: 14px; font-weight: 700; color: var(--text-primary); line-height: 1.4; margin-bottom: 8px; }
.detail-tags { display: flex; gap: 6px; margin-bottom: 12px; flex-wrap: wrap; }
.detail-tag { font-size: 10px; padding: 2px 8px; border-radius: 10px; background: rgba(0, 212, 255, 0.1); color: var(--text-accent); }
.detail-tag--type { background: rgba(6, 182, 212, 0.15); color: #06b6d4; }
.detail-tag--rating { background: rgba(245, 158, 11, 0.12); color: #fbbf24; }
.detail-avail { margin-bottom: 12px; }
.detail-avail-header { display: flex; justify-content: space-between; font-size: 11px; color: var(--text-dim); margin-bottom: 4px; }
.detail-avail-bar { height: 6px; background: rgba(0, 212, 255, 0.08); border-radius: 3px; overflow: hidden; margin-bottom: 4px; }
.detail-avail-fill { height: 100%; border-radius: 3px; transition: width 0.6s ease; }
.detail-avail-stats { display: flex; justify-content: space-between; font-size: 10px; color: var(--text-dim); }
.detail-avail-stats b { font-weight: 600; }
.detail-info-grid { display: flex; flex-direction: column; gap: 8px; }
.detail-info-item { display: flex; flex-direction: column; gap: 2px; }
.detail-label { font-size: 10px; color: var(--text-dim); text-transform: uppercase; letter-spacing: 0.04em; }
.detail-value { font-size: 12px; color: var(--text-secondary); }

@keyframes slideIn { from { opacity: 0; transform: translateX(12px); } to { opacity: 1; transform: translateX(0); } }
@keyframes scrollUp { 0% { transform: translateY(0); } 100% { transform: translateY(-50%); } }
</style>
