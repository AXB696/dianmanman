<template>
  <div class="alert-ticker" v-if="alerts.length">
    <span class="ticker-label">⚡ 实时告警</span>
    <div class="ticker-track" @mouseenter="pause" @mouseleave="resume">
      <div class="ticker-scroll" ref="scrollRef" :style="{ animationPlayState: playing ? 'running' : 'paused', animationDuration: scrollDuration }">
        <template v-for="(a, i) in displayAlerts" :key="i">
          <span
            class="ticker-item"
            :class="a.level"
            @click="$emit('stationClick', a.station_id)"
          >
            <span class="ticker-dot"></span>
            {{ a.district }} · {{ a.name }} 仅剩 <b>{{ a.available }}/{{ a.total }}</b> 桩
            <span class="ticker-sep">·</span>
          </span>
        </template>
      </div>
    </div>
    <span class="ticker-count">{{ alerts.length }}个告警</span>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { getStationStatus } from '@/api/dashboard'

defineEmits<{ stationClick: [id: string] }>()

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
  background: rgba(239, 68, 68, 0.06);
  border: 1px solid rgba(239, 68, 68, 0.15);
  border-radius: 4px;
  margin: 0 12px;
  overflow: hidden;
  flex-shrink: 0;
  z-index: 2;
}
.ticker-label {
  flex-shrink: 0;
  font-size: 10px; font-weight: 700; color: #f87171;
  padding: 0 10px; letter-spacing: 0.04em;
  background: rgba(239, 68, 68, 0.08);
  height: 100%; display: flex; align-items: center;
  border-right: 1px solid rgba(239, 68, 68, 0.15);
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
  /* animation-duration 由 JS 根据告警数量动态设置 */
}
@keyframes tickerScroll {
  0%   { transform: translateX(0); }
  100% { transform: translateX(-50%); }
}
.ticker-item {
  display: inline-flex; align-items: center; gap: 4px;
  font-size: 11px; color: #e8edf5;
  padding: 0 12px; cursor: pointer;
  transition: color 0.15s; flex-shrink: 0;
}
.ticker-item:hover { color: #fbbf24; }
.ticker-item.warning { color: #fbbf24; }
.ticker-item.critical { color: #f87171; }
.ticker-item.warning .ticker-dot { background: #f59e0b; }
.ticker-item.critical .ticker-dot { background: #ef4444; }
.ticker-dot { width: 5px; height: 5px; border-radius: 50%; flex-shrink: 0; }
.ticker-item b { font-weight: 700; font-family: var(--font-mono); }
.ticker-sep { color: var(--text-dim); margin: 0 2px; font-weight: 300; }
.ticker-count {
  flex-shrink: 0; font-size: 10px; font-weight: 600; color: #f87171;
  padding: 0 10px;
  background: rgba(239, 68, 68, 0.08);
  height: 100%; display: flex; align-items: center;
  border-left: 1px solid rgba(239, 68, 68, 0.15);
}
</style>
