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
const selectedMonth = ref(6)
const months = Array.from({ length: 12 }, (_, i) => i + 1)
let chart: echarts.ECharts | null = null

// 按月的每日模拟数据
function dailyData(month: number): { expected: number[]; actual: (number | null)[] } {
  const baseExpected = revenueData[month - 1]?.expected ?? 8000
  const baseActual = revenueData[month - 1]?.actual ?? 8000
  const days = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31][month - 1]
  const expected: number[] = []
  const actual: (number | null)[] = []
  for (let d = 0; d < days; d++) {
    const e = Math.round(baseExpected / days * (0.7 + Math.random() * 0.6))
    expected.push(e)
    // 当前月及之前有实际数据
    if (month <= 6) {
      actual.push(Math.round(baseActual / days * (0.7 + Math.random() * 0.6)))
    } else if (month === 7 && d < 3) {
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
        backgroundColor: 'rgba(12,25,40,0.9)',
        borderColor: 'rgba(0, 212, 255,0.3)',
        textStyle: { color: '#e2e8f0', fontSize: 11 },
      },
      legend: {
        top: -2,
        textStyle: { color: '#bcc9dc', fontSize: 11 },
        itemWidth: 10, itemHeight: 6,
        itemGap: 14,
      },
      grid: { left: 8, right: 18, top: 18, bottom: 8 },
      xAxis: {
        type: 'category',
        data: revenueData.map(d => d.month),
        axisLine: { lineStyle: { color: 'rgba(0, 212, 255,0.15)' } },
        axisLabel: { color: '#64748b', fontSize: 10 },
      },
      yAxis: {
        type: 'value',
        min: 4000,
        max: yMaxYear,
        splitLine: { lineStyle: { color: 'rgba(0, 212, 255,0.08)' } },
        axisLabel: { color: '#64748b', fontSize: 9, formatter: '{value}' },
      },
      series: [
        {
          name: '预期', type: 'line',
          data: revenueData.map(d => d.expected),
          smooth: true,
          lineStyle: { color: '#6366f1', width: 2, type: 'dashed' },
          itemStyle: { color: '#6366f1' },
          symbol: 'none',
          label: { show: true, position: 'top', color: '#818cf8', fontSize: 9, formatter: '{c}' },
          areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(99,102,241,0.08)' }, { offset: 1, color: 'rgba(99,102,241,0)' },
          ])},
        },
        {
          name: '实际', type: 'line',
          data: revenueData.map(d => d.actual || null),
          smooth: true,
          lineStyle: { color: '#00d4ff', width: 2.5 },
          itemStyle: { color: '#00d4ff', borderColor: 'rgba(0,212,255,0.4)', borderWidth: 2 },
          symbol: 'circle', symbolSize: 7,
          label: { show: true, position: 'top', color: '#00d4ff', fontSize: 9, formatter: '{c}' },
          areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(0, 212, 255,0.15)' }, { offset: 1, color: 'rgba(0, 212, 255,0)' },
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
      backgroundColor: 'rgba(12,25,40,0.9)',
      borderColor: 'rgba(0, 212, 255,0.3)',
      textStyle: { color: '#e2e8f0', fontSize: 11 },
    },
    legend: {
      top: -2,
      textStyle: { color: '#bcc9dc', fontSize: 11 },
      itemWidth: 10, itemHeight: 6,
      itemGap: 14,
    },
    grid: { left: 8, right: 18, top: 18, bottom: 8 },
    xAxis: {
      type: 'category',
      data: xData,
      axisLine: { lineStyle: { color: 'rgba(0, 212, 255,0.15)' } },
      axisLabel: { color: '#64748b', fontSize: 9, interval: Math.floor(days / 6) },
    },
    yAxis: {
      type: 'value',
      max: yMax,
      splitLine: { lineStyle: { color: 'rgba(0, 212, 255,0.08)' } },
      axisLabel: { color: '#64748b', fontSize: 9, formatter: '{value}' },
    },
    series: [
      {
        name: '预期', type: 'line',
        data: expected,
        smooth: true,
        lineStyle: { color: '#6366f1', width: 1.5, type: 'dashed' },
        itemStyle: { color: '#6366f1' },
        symbol: 'none',
        areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
          { offset: 0, color: 'rgba(99,102,241,0.08)' }, { offset: 1, color: 'rgba(99,102,241,0)' },
        ])},
      },
      {
        name: '实际', type: 'line',
        data: actual,
        smooth: true,
        lineStyle: { color: '#00d4ff', width: 2.5 },
        itemStyle: { color: '#00d4ff', borderColor: 'rgba(0,212,255,0.4)', borderWidth: 2 },
        symbol: 'circle', symbolSize: 5,
        label: { show: true, position: 'top', color: '#00d4ff', fontSize: 8, formatter: '{c}' },
        areaStyle: { color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
          { offset: 0, color: 'rgba(0, 212, 255,0.15)' }, { offset: 1, color: 'rgba(0, 212, 255,0)' },
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
  background: rgba(0, 212, 255, 0.06);
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

.sw-btn:hover { color: var(--text-accent); }

.sw-btn.active {
  background: var(--color-primary);
  color: #070c14;
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
  border: 1px solid var(--border-subtle);
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
  border-color: rgba(0, 212, 255, 0.3);
  color: var(--text-accent);
}

.m-btn.active {
  background: rgba(0, 212, 255, 0.15);
  border-color: var(--color-primary);
  color: var(--color-primary);
  font-weight: 600;
}
</style>
