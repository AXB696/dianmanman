<template>
  <div class="kpi-grid">
    <div class="kpi-card" v-for="(item, i) in items" :key="item.label"
         :style="{ animationDelay: staggerDelay(i) }"
         @click="$emit('kpiClick', i)">
      <div class="kpi-icon" :style="{ background: item.color }">
        <span v-html="item.icon"></span>
      </div>
      <div class="kpi-info">
        <span class="kpi-label">{{ item.label }}</span>
        <span class="kpi-value number" :style="{ color: item.glow || 'var(--text-primary)' }">{{ formatNumber(displayValues[i]) }}</span>
        <span class="kpi-sub" v-if="item.sub" v-html="item.sub"></span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { formatNumber } from '@/utils/format'
import { staggerDelay } from '@/utils/animation'
import { getDashboardStats } from '@/api/dashboard'

defineEmits<{ kpiClick: [index: number] }>()

// SVG 图标
const svgStation = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#00d4ff" stroke-width="2" stroke-linecap="round"><rect x="3" y="3" width="18" height="18" rx="3"/><line x1="12" y1="8" x2="12" y2="16"/><polyline points="8,12 12,8 16,12"/></svg>'
const svgGrowth = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#818cf8" stroke-width="2" stroke-linecap="round"><path d="M22 12h-4l-3 9L9 3l-3 9H2"/></svg>'
const svgPile = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#22d3ee" stroke-width="2" stroke-linecap="round"><rect x="2" y="6" width="5" height="14" rx="1"/><rect x="9.5" y="2" width="5" height="18" rx="1"/><rect x="17" y="6" width="5" height="14" rx="1"/></svg>'
const svgAlert = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="#f87171" stroke-width="2" stroke-linecap="round"><path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>'

const items = ref([
  { label: '充电站总数', value: 0, icon: svgStation, color: 'rgba(0,212,255,.15)', sub: '', glow: '#00d4ff' },
  { label: '今日充电次数', value: 0, icon: svgGrowth, color: 'rgba(99,102,241,.15)', sub: '', glow: '#818cf8' },
  { label: '充电桩总数', value: 0, icon: svgPile, color: 'rgba(6,182,212,.15)', sub: '', glow: '#22d3ee' },
  { label: '异常站点', value: 0, icon: svgAlert, color: 'rgba(239,68,68,.15)', sub: '', glow: '#f87171' },
])

const displayValues = ref([0, 0, 0, 0])

function countUp(index: number, to: number, delay: number = 0) {
  if (to === 0) {
    displayValues.value[index] = 0
    return
  }
  const start = performance.now()
  const duration = 1500
  function tick(now: number) {
    const elapsed = now - start
    if (elapsed < delay) { requestAnimationFrame(tick); return }
    const progress = Math.min((elapsed - delay) / duration, 1)
    const eased = progress >= 1 ? 1 : 1 - Math.pow(2, -10 * progress)
    displayValues.value[index] = Math.round(to * eased)
    if (progress < 1) requestAnimationFrame(tick)
  }
  requestAnimationFrame(tick)
}

onMounted(async () => {
  try {
    const stats = await getDashboardStats()
    items.value[0].value = stats.total_stations
    items.value[0].sub = `在线率 <b style="color:#22d3a7">${stats.online_rate}%</b>`
    items.value[1].value = stats.today_charges
    items.value[1].sub = `累计充电 <b style="color:#00d4ff">${formatNumber(stats.total_charges)}</b> 次`
    items.value[2].value = stats.total_piles
    items.value[2].sub = `可用 <b style="color:#22d3a7">${stats.available_piles}</b> 桩`
    items.value[3].value = stats.busy_stations
    items.value[3].sub = `在线站点 <b style="color:#22d3a7">${stats.online_stations}</b>`
  } catch (_) {
    // 后端不可用时显示占位
    items.value[0].sub = `在线率 <b style="color:#22d3a7">--%</b>`
    items.value[1].sub = `累计充电 <b style="color:#00d4ff">--</b> 次`
    items.value[2].sub = `可用 <b style="color:#22d3a7">--</b> 桩`
    items.value[3].sub = `在线站点 <b style="color:#22d3a7">--</b>`
  }

  items.value.forEach((item, i) => {
    countUp(i, item.value, i * 150)
  })
})
</script>

<style scoped>
.kpi-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  grid-template-rows: 1fr 1fr;
  gap: 10px;
  height: 100%;
}

.kpi-card {
  background: var(--bg-card);
  border: 1px solid var(--border-subtle);
  border-radius: var(--radius-md);
  padding: 12px 14px;
  display: flex;
  align-items: center;
  gap: 12px;
  position: relative;
  overflow: hidden;
  cursor: pointer;
  transition: border-color 0.3s, box-shadow 0.3s;
  animation: fadeInUp 0.5s ease backwards;
}

.kpi-card:hover {
  border-color: var(--border-glow);
  box-shadow: var(--shadow-glow), var(--shadow-card);
}

.kpi-icon {
  width: 46px;
  height: 46px;
  border-radius: 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  transition: transform 0.3s;
}

.kpi-card:hover .kpi-icon {
  transform: scale(1.05);
}

.kpi-info {
  display: flex;
  flex-direction: column;
  min-width: 0;
}

.kpi-label {
  font-size: 11px;
  color: var(--text-secondary);
  letter-spacing: 0.03em;
}

.kpi-value {
  font-size: 24px;
  font-weight: 700;
  line-height: 1.2;
  color: var(--text-primary);
}

.kpi-sub {
  font-size: 10px;
  color: var(--text-secondary);
}

@keyframes fadeInUp {
  from { opacity: 0; transform: translateY(12px); }
  to { opacity: 1; transform: translateY(0); }
}
</style>
