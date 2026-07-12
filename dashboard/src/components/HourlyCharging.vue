<template>
  <div class="panel" style="display:flex;flex-direction:column;">
    <div class="panel-title">时段充电分布</div>
    <div ref="chartRef" style="flex:1;min-height:0"></div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import * as echarts from 'echarts/core'
import { BarChart } from 'echarts/charts'
import { TooltipComponent, GridComponent } from 'echarts/components'
import { CanvasRenderer } from 'echarts/renderers'
import { getChargingByHour } from '@/api/dashboard'

echarts.use([BarChart, TooltipComponent, GridComponent, CanvasRenderer])

const chartRef = ref<HTMLElement | null>(null)
let chart: echarts.ECharts | null = null

const BAR_COLORS = [
  ['#6366f1', '#818cf8'],
  ['#06b6d4', '#22d3ee'],
  ['#f59e0b', '#fbbf24'],
  ['#00d4ff', '#38bdf8'],
]

onMounted(async () => {
  if (!chartRef.value) return
  chart = echarts.init(chartRef.value)

  // 从后端加载时段充电数据
  let periods = ['0-6时', '6-12时', '12-18时', '18-24时']
  let counts = [0, 0, 0, 0]
  try {
    const data = await getChargingByHour()
    periods = data.periods
    counts = data.counts
  } catch (_) {}

  const max = Math.max(...counts, 1)

  chart.setOption({
    tooltip: {
      trigger: 'axis',
      backgroundColor: '#fff',
      borderColor: '#e5e7eb',
      textStyle: { color: '#1f2937', fontSize: 11 },
      formatter: (p: any) => {
        const item = p[0]
        return `${item.name} 充电次数：<b>${item.value}</b>`
      },
    },
    grid: {
      top: 4,
      bottom: 2,
      left: 68,
      right: 48,
    },
    xAxis: {
      type: 'value',
      show: false,
      max,
    },
    yAxis: {
      type: 'category',
      inverse: true,
      data: periods,
      axisLine: { show: false },
      axisTick: { show: false },
      axisLabel: {
        color: '#6b7280',
        fontSize: 10,
        margin: 8,
      },
    },
    series: [
      {
        type: 'bar',
        barWidth: 10,
        data: counts.map((v, i) => ({
          value: v,
          itemStyle: {
            borderRadius: [0, 4, 4, 0],
            color: new echarts.graphic.LinearGradient(0, 0, 1, 0, [
              { offset: 0, color: BAR_COLORS[i][0] },
              { offset: 0.6, color: BAR_COLORS[i][1] },
              { offset: 1, color: 'transparent' },
            ]),
          },
        })),
        label: {
          show: true,
          position: 'right',
          color: '#4b5563',
          fontSize: 10,
          fontFamily: "'JetBrains Mono', monospace",
          formatter: '{c} 次',
          distance: 6,
        },
      },
    ],
  })
})

onUnmounted(() => { chart?.dispose() })
</script>
