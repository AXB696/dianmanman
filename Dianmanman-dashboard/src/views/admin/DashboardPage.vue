<template>
  <div class="page">
    <h1 class="page-title">数据概览</h1>

    <!-- ═══ 第一行：8 个统计卡片 ═══ -->
    <div v-if="loading" class="loading-hint">加载中...</div>
    <div v-else class="stat-grid">
      <div class="stat-card" v-for="s in stats" :key="s.label">
        <div class="stat-icon" :style="{ background: s.color }">{{ s.icon }}</div>
        <div class="stat-info">
          <span class="stat-label">{{ s.label }}</span>
          <span class="stat-value">{{ s.value }}</span>
        </div>
      </div>
    </div>

    <p v-if="error" class="error-msg">{{ error }}</p>

    <!-- ═══ 第二行：用户增长趋势 折线图 ═══ -->
    <div class="chart-section">
      <h2 class="section-title">用户增长趋势（近 30 天）</h2>
      <div ref="lineRef" class="chart-box"></div>
    </div>

    <!-- ═══ 第三行：充电时段 + 车辆品牌（左右并排） ═══ -->
    <div class="chart-row">
      <div class="chart-section" style="flex:6">
        <h2 class="section-title">充电行为分析</h2>
        <div ref="hourRef" class="chart-box" style="height:280px"></div>
      </div>
      <div class="chart-section" style="flex:4">
        <h2 class="section-title">车辆品牌分布</h2>
        <div ref="brandRef" class="chart-box" style="height:280px"></div>
      </div>
    </div>

    <!-- ═══ 第四行：热门站点 TOP 10 柱状图 ═══ -->
    <div class="chart-section">
      <h2 class="section-title">热门充电站点 TOP 10</h2>
      <div ref="topRef" class="chart-box" style="height:320px"></div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import * as echarts from 'echarts/core'
import { LineChart, BarChart, PieChart } from 'echarts/charts'
import { TooltipComponent, GridComponent, LegendComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'
import { getBaseStats, getOverviewStats, getDailyUsers, getChargingByHour, getTopStations, getVehicleBrands } from '@/api/admin'

// ═══════════ 注册 ECharts 组件 ═══════════
echarts.use([LineChart, BarChart, PieChart, TooltipComponent, GridComponent, LegendComponent, CanvasRenderer])

// ═══════════ 响应式数据 ═══════════
const loading = ref(true)
const error = ref('')
const stats = ref([
  { icon: '👥', label: '累计用户', value: 0, color: '#eff6ff' },
  { icon: '✨', label: '今日新增', value: 0, color: '#f0fdf4' },
  { icon: '🚗', label: '累计车辆', value: 0, color: '#fef3c7' },
  { icon: '⭐', label: '累计收藏', value: 0, color: '#fce7f3' },
  { icon: '⚡', label: '累计充电', value: 0, color: '#f5f3ff' },
  { icon: '🔌', label: '今日充电', value: 0, color: '#fff7ed' },
  { icon: '🔥', label: '活跃电站', value: 0, color: '#fef2f2' },
  { icon: '📊', label: '人均充电', value: '0 次' as any, color: '#eef2ff' },
])

// ═══════════ 图表 DOM 引用 ═══════════
const lineRef = ref<HTMLElement | null>(null)
const hourRef = ref<HTMLElement | null>(null)
const brandRef = ref<HTMLElement | null>(null)
const topRef = ref<HTMLElement | null>(null)
const charts: echarts.ECharts[] = []

// ═══════════ 图表辅助函数 ═══════════
function initChart(el: HTMLElement | null): echarts.ECharts | null {
  if (!el) return null
  const c = echarts.init(el)
  charts.push(c)
  return c
}

function emptyOption(msg: string): any {
  return {
    title: { text: msg, left: 'center', top: 'center', textStyle: { color: '#94a3b8', fontSize: 14, fontWeight: 400 } },
  }
}

// ═══════════ 加载数据 + 绑定图表 ═══════════
onMounted(async () => {
  try {
    // 并行请求所有数据
    const [base, overview, daily, hour, top, brand] = await Promise.all([
      getBaseStats(),
      getOverviewStats(),
      getDailyUsers(30),
      getChargingByHour(),
      getTopStations(10),
      getVehicleBrands(),
    ])

    // ── 统计卡片 ──
    stats.value[0].value = base.user_count || 0
    stats.value[1].value = overview.today_new_users || 0
    stats.value[2].value = base.vehicle_count || 0
    stats.value[3].value = base.favorite_count || 0
    stats.value[4].value = base.history_count || 0
    stats.value[5].value = overview.today_charging || 0
    stats.value[6].value = overview.active_stations || 0
    stats.value[7].value = (overview.avg_charging || 0) + ' 次'

    loading.value = false

    // ── 图1：用户增长趋势 折线图 ──
    const lineChart = initChart(lineRef.value)
    if (lineChart && daily.dates?.length && daily.counts?.length && daily.counts.some((c: number) => c > 0)) {
      lineChart.setOption({
        tooltip: { trigger: 'axis' },
        grid: { left: 40, right: 16, top: 12, bottom: 40 },
        xAxis: {
          type: 'category',
          data: daily.dates.map((d: string) => d.slice(5)), // "2026-07-01" → "07-01"
          axisLabel: { rotate: 45, fontSize: 10, color: '#64748b' },
          interval: Math.ceil(daily.dates.length / 10) - 1,
        },
        yAxis: { type: 'value', minInterval: 1, axisLabel: { color: '#64748b', fontSize: 10 } },
        series: [{
          type: 'line', data: daily.counts, smooth: true,
          lineStyle: { color: '#1a56db', width: 2 },
          itemStyle: { color: '#1a56db' },
          areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(26,86,219,0.15)' }, { offset: 1, color: 'rgba(26,86,219,0)' },
          ])},
        }],
      })
    } else if (lineChart) {
      lineChart.setOption(emptyOption('暂无用户增长数据'))
    }

    // ── 图2：充电时段分布 柱状图 ──
    const hourChart = initChart(hourRef.value)
    if (hourChart && hour.periods?.length) {
      hourChart.setOption({
        tooltip: { trigger: 'axis' },
        grid: { left: 50, right: 16, top: 8, bottom: 24 },
        xAxis: { type: 'category', data: hour.periods, axisLabel: { color: '#64748b', fontSize: 10 } },
        yAxis: { type: 'value', minInterval: 1, axisLabel: { color: '#64748b', fontSize: 10 } },
        series: [{
          type: 'bar', data: hour.counts, barWidth: 32,
          itemStyle: {
            borderRadius: [6, 6, 0, 0],
            color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
              { offset: 0, color: '#6366f1' }, { offset: 1, color: '#818cf8' },
            ]),
          },
          label: { show: true, position: 'top', color: '#475569', fontSize: 11 },
        }],
      })
    } else if (hourChart) {
      hourChart.setOption(emptyOption('暂无充电时段数据'))
    }

    // ── 图3：车辆品牌分布 饼图 ──
    const brandChart = initChart(brandRef.value)
    if (brandChart && brand.brands?.length) {
      brandChart.setOption({
        tooltip: { trigger: 'item', formatter: '{b}: {c} 辆 ({d}%)' },
        legend: { orient: 'vertical', right: 8, top: 'center', textStyle: { fontSize: 11, color: '#64748b' }, itemWidth: 10, itemHeight: 6 },
        series: [{
          type: 'pie', radius: ['45%', '72%'], center: ['35%', '52%'],
          label: { show: false },
          emphasis: { label: { show: true, fontSize: 14, fontWeight: 'bold' } },
          data: brand.brands.map((b: any) => ({ name: b.brand, value: b.count })),
          itemStyle: { borderRadius: 4, borderColor: '#fff', borderWidth: 2 },
        }],
      })
    } else if (brandChart) {
      brandChart.setOption(emptyOption('暂无品牌数据'))
    }

    // ── 图4：热门站点 TOP 10 横向柱状图 ──
    const topChart = initChart(topRef.value)
    if (topChart && top.stations?.length) {
      const names = top.stations.map((s: any) => (s.name?.length > 14 ? s.name.slice(0, 14) + '…' : s.name) || s.station_id).reverse()
      const counts = (top.stations as any[]).map((s: any) => s.count).reverse()
      topChart.setOption({
        tooltip: { trigger: 'axis', axisPointer: { type: 'shadow' } },
        grid: { left: 130, right: 40, top: 8, bottom: 16 },
        xAxis: { type: 'value', axisLabel: { color: '#64748b', fontSize: 10 } },
        yAxis: { type: 'category', data: names, axisLabel: { color: '#334155', fontSize: 11, width: 120, overflow: 'truncate' }, inverse: true },
        series: [{
          type: 'bar', data: counts, barWidth: 16,
          label: { show: true, position: 'right', color: '#475569', fontSize: 11, formatter: '{c} 次' },
          itemStyle: {
            borderRadius: [0, 6, 6, 0],
            color: new echarts.graphic.LinearGradient(0, 0, 1, 0, [
              { offset: 0, color: '#1a56db' }, { offset: 1, color: '#38bdf8' },
            ]),
          },
        }],
      })
    } else if (topChart) {
      topChart.setOption(emptyOption('暂无热门站点数据'))
    }
  } catch (e: any) {
    error.value = '加载数据失败: ' + (e?.message || e)
    loading.value = false
  }
})

onUnmounted(() => {
  charts.forEach(c => c.dispose())
})
</script>

<style scoped>
.page { padding: 32px; }
.page-title { margin: 0 0 24px; font-size: 20px; color: #1a1a2e; }

/* ── 统计卡片 ── */
.loading-hint { color: #94a3b8; font-size: 13px; }
.stat-grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 16px; margin-bottom: 32px; }
.stat-card { background: #fff; border-radius: 12px; padding: 20px; display: flex; align-items: center; gap: 16px; box-shadow: 0 1px 8px rgba(0,0,0,0.04); }
.stat-icon { width: 48px; height: 48px; border-radius: 12px; display: flex; align-items: center; justify-content: center; font-size: 22px; flex-shrink: 0; }
.stat-info { display: flex; flex-direction: column; min-width: 0; }
.stat-label { font-size: 12px; color: #94a3b8; }
.stat-value { font-size: 26px; font-weight: 700; color: #1a1a2e; }
.error-msg { color: #ef4444; font-size: 13px; margin-bottom: 16px; }

/* ── 图表区 ── */
.chart-section { margin-bottom: 32px; }
.section-title { font-size: 16px; font-weight: 600; color: #1a1a2e; margin: 0 0 16px; }
.chart-box {
  background: #fff; border-radius: 12px; padding: 16px;
  box-shadow: 0 1px 8px rgba(0,0,0,0.04);
  height: 240px;
}
.chart-row { display: flex; gap: 20px; margin-bottom: 32px; }
.chart-row .chart-section { flex: 1; margin-bottom: 0; }
.chart-row .chart-box { height: 280px; }
</style>
