<template>
  <div class="panel" style="display:flex;flex-direction:column;flex:1">
    <div class="trend-header">
      <div class="panel-title">营收趋势</div>
      <div class="view-switcher">
        <button :class="['sw-btn', { active: view === 'year' }]" @click="view = 'year'">年</button>
        <button :class="['sw-btn', { active: view === 'month' }]" @click="view = 'month'">月</button>
      </div>
      <span class="unit-hint">单位：万元</span>
    </div>

    <!-- 月份选择器 -->
    <div v-if="view === 'month'" class="month-picker">
      <button
        v-for="m in months" :key="m"
        :class="['m-btn', { active: selectedMonth === m }]"
        @click="selectedMonth = m; updateChart()"
      >{{ m }}月</button>
    </div>

    <div ref="chartRef" style="flex:1;min-height:0"></div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch, onMounted, onUnmounted, nextTick } from 'vue'
import * as echarts from 'echarts/core'
import { LineChart } from 'echarts/charts'
import { TooltipComponent, GridComponent, LegendComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'
import { mockRevenueTrend } from '@/mock/business'

// 使用 mock 数据（实际项目接入后端 API 后替换为真实数据）
const revenueData = mockRevenueTrend.length > 0 ? mockRevenueTrend : Array.from({length: 12}, (_, i) => ({
  month: `${i + 1}月`, expected: 0, actual: 0,
}))

echarts.use([LineChart, TooltipComponent, GridComponent, LegendComponent, CanvasRenderer])

const chartRef = ref<HTMLElement | null>(null)
const view = ref<'year' | 'month'>('year')
const selectedMonth = ref(new Date().getMonth() + 1)
const months = Array.from({ length: 12 }, (_, i) => i + 1)
let chart: echarts.ECharts | null = null

// 按月的每日模拟数据
function dailyData(month: number): { expected: number[]; actual: (number | null)[] } {
  const baseExpected = revenueData[month - 1]?.expected ?? 8000
  const baseActual = revenueData[month - 1]?.actual ?? 8000
  const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
  const now = new Date()
  const currentMonth = now.getMonth() + 1
  const currentDay = now.getDate()
  const expected: number[] = []
  const actual: (number | null)[] = []
  for (let d = 0; d < days; d++) {
    const e = Math.round(baseExpected / days * (0.7 + Math.random() * 0.6))
    expected.push(e)
    // 当前月及之前有实际数据，当月只到今天
    if (month < currentMonth) {
      actual.push(Math.round(baseActual / days * (0.7 + Math.random() * 0.6)))
    } else if (month === currentMonth && d < currentDay) {
      actual.push(Math.round(baseActual / days * (0.7 + Math.random() * 0.6)))
    } else {
      actual.push(null)
    }
  }
  return { expected, actual }
}

function buildOption(): any {
  if (view.value === 'year') {
    const yearMax = Math.max(
      ...revenueData.map(d => d.expected),
      ...revenueData.map(d => d.actual || 0),
    )
    const yMaxYear = Math.ceil(yearMax * 1.2 / 500) * 500

    return {
      tooltip: {
        trigger: 'axis',
        backgroundColor: '#fff',
        borderColor: '#e5e7eb',
        textStyle: { color: '#1f2937', fontSize: 11 },
      },
      legend: {
        top: -2,
        textStyle: { color: '#6b7280', fontSize: 11 },
        itemWidth: 10, itemHeight: 6,
        itemGap: 14,
      },
      grid: { left: 8, right: 18, top: 18, bottom: 8 },
      xAxis: {
        type: 'category',
        data: revenueData.map(d => d.month),
        axisLine: { lineStyle: { color: '#e5e7eb' } },
        axisLabel: { color: '#6b7280', fontSize: 10 },
      },
      yAxis: {
        type: 'value',
        min: 4000,
        max: yMaxYear,
        splitLine: { lineStyle: { color: '#f3f4f6' } },
        axisLabel: { color: '#6b7280', fontSize: 9, formatter: '{value}' },
      },
      series: [
        {
          name: '预期', type: 'line',
          data: revenueData.map(d => d.expected),
          smooth: true,
          lineStyle: { color: '#9ca3af', width: 2, type: 'dashed' },
          itemStyle: { color: '#9ca3af' },
          symbol: 'none',
          label: { show: true, position: 'top', color: '#9ca3af', fontSize: 9, formatter: '{c}' },
          areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(156,163,175,0.08)' }, { offset: 1, color: 'rgba(156,163,175,0)' },
          ])},
        },
        {
          name: '实际', type: 'line',
          data: revenueData.map(d => d.actual || null),
          smooth: true,
          lineStyle: { color: '#1677ff', width: 2.5 },
          itemStyle: { color: '#1677ff', borderColor: 'rgba(22,119,255,0.4)', borderWidth: 2 },
          symbol: 'circle', symbolSize: 7,
          label: { show: true, position: 'top', color: '#1677ff', fontSize: 9, formatter: '{c}' },
          areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(22, 119, 255,0.15)' }, { offset: 1, color: 'rgba(22, 119, 255,0)' },
          ])},
        },
      ],
    }
  }

  // 月视图 — 每日数据
  const { expected, actual } = dailyData(selectedMonth.value)
  const days = expected.length
  const xData = Array.from({ length: days }, (_, i) => (i + 1) + '日')

  // 动态 Y 轴上限：数据最大值 +20% 余量
  const allVals = [...expected, ...actual.filter(v => v !== null)] as number[]
  const dataMax = Math.max(...allVals, 0)
  const yMax = Math.ceil(dataMax * 1.25 / 50) * 50

  return {
    tooltip: {
      trigger: 'axis',
      backgroundColor: '#fff',
      borderColor: '#e5e7eb',
      textStyle: { color: '#1f2937', fontSize: 11 },
    },
    legend: {
      top: -2,
      textStyle: { color: '#6b7280', fontSize: 11 },
      itemWidth: 10, itemHeight: 6,
      itemGap: 14,
    },
    grid: { left: 8, right: 18, top: 18, bottom: 8 },
    xAxis: {
      type: 'category',
      data: xData,
      axisLine: { lineStyle: { color: '#e5e7eb' } },
      axisLabel: { color: '#6b7280', fontSize: 9, interval: Math.floor(days / 6) },
    },
    yAxis: {
      type: 'value',
      max: yMax,
      splitLine: { lineStyle: { color: '#f3f4f6' } },
      axisLabel: { color: '#6b7280', fontSize: 9, formatter: '{value}' },
    },
    series: [
      {
        name: '预期', type: 'line',
        data: expected,
        smooth: true,
        lineStyle: { color: '#9ca3af', width: 1.5, type: 'dashed' },
        itemStyle: { color: '#9ca3af' },
        symbol: 'none',
        areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
          { offset: 0, color: 'rgba(156,163,175,0.08)' }, { offset: 1, color: 'rgba(156,163,175,0)' },
        ])},
      },
      {
        name: '实际', type: 'line',
        data: actual,
        smooth: true,
        lineStyle: { color: '#1677ff', width: 2.5 },
        itemStyle: { color: '#1677ff', borderColor: 'rgba(22,119,255,0.4)', borderWidth: 2 },
        symbol: 'circle', symbolSize: 5,
        label: { show: true, position: 'top', color: '#1677ff', fontSize: 8, formatter: '{c}' },
        areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
          { offset: 0, color: 'rgba(22, 119, 255,0.15)' }, { offset: 1, color: 'rgba(22, 119, 255,0)' },
        ])},
      },
    ],
  }
}

function updateChart() {
  if (!chart) return
  chart.setOption(buildOption(), true)
}

watch(view, () => nextTick(updateChart))

onMounted(() => {
  if (!chartRef.value) return
  chart = echarts.init(chartRef.value)
  updateChart()
})

onUnmounted(() => { chart?.dispose() })
</script>

<style scoped>
.trend-header {
  display: flex;
  align-items: center;
  gap: 8px;
}

.trend-header :deep(.panel-title) {
  margin-bottom: 0;
  flex-shrink: 0;
}

.unit-hint {
  font-size: 10px;
  color: var(--text-dim);
  margin-left: auto;
}

.view-switcher {
  display: flex;
  gap: 2px;
  background: #f3f4f6;
  border-radius: 6px;
  padding: 2px;
}

.sw-btn {
  border: none;
  background: transparent;
  color: var(--text-dim);
  font-size: 11px;
  font-family: var(--font-sans);
  padding: 2px 10px;
  border-radius: 4px;
  cursor: pointer;
  transition: all 0.2s;
}

.sw-btn:hover { color: var(--text-primary); }

.sw-btn.active {
  background: var(--color-primary);
  color: #fff;
  font-weight: 600;
}

.month-picker {
  display: flex;
  gap: 1px;
  flex-wrap: wrap;
  padding: 0;
  flex-shrink: 0;
  line-height: 1;
}

.m-btn {
  border: 1px solid #e5e7eb;
  background: transparent;
  color: var(--text-dim);
  font-size: 9px;
  font-family: var(--font-sans);
  padding: 0 5px;
  border-radius: 3px;
  cursor: pointer;
  transition: all 0.15s;
  line-height: 1.6;
}

.m-btn:hover {
  border-color: #91caff;
  color: var(--color-primary);
}

.m-btn.active {
  background: #e6f4ff;
  border-color: var(--color-primary);
  color: var(--color-primary);
  font-weight: 600;
}
</style>
