<template>
  <div class="panel order-kpi">
    <div class="order-header">
      <div class="panel-title">运营数据</div>
      <div class="period-switcher">
        <button
          v-for="p in periods" :key="p.key"
          :class="['period-btn', { active: period === p.key }]"
          @click="period = p.key"
        >{{ p.label }}</button>
      </div>
    </div>
    <div class="order-row">
      <div class="order-item">
        <span class="order-label">订单量</span>
        <span class="order-value number">{{ orders }}</span>
      </div>
      <div class="order-divider"></div>
      <div class="order-item">
        <span class="order-label">销售额(万元)</span>
        <span class="order-value number accent">{{ revenue }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { mockOrderKPIs } from '@/mock/business'

const period = ref<'year' | 'month' | 'day'>('day')

const periods = [
  { key: 'day' as const, label: '日' },
  { key: 'month' as const, label: '月' },
  { key: 'year' as const, label: '年' },
]

// 从 mock 数据计算日/月/年维度
const baseOrders = mockOrderKPIs.total_orders || 0
const baseRevenue = mockOrderKPIs.total_revenue_wan || 0

const kpiMap = {
  year:  { orders: baseOrders, revenue: baseRevenue },
  month: { orders: Math.round(baseOrders / 12), revenue: Math.round(baseRevenue / 12) },
  day:   { orders: Math.round(baseOrders / 365), revenue: Math.round(baseRevenue / 365) },
}

const orders = computed(() => kpiMap[period.value].orders.toLocaleString('zh-CN'))
const revenue = computed(() => kpiMap[period.value].revenue.toLocaleString('zh-CN'))
</script>

<style scoped>
.order-kpi { display: flex; flex-direction: column; }
.order-header {
  display: flex; align-items: center; justify-content: space-between;
  margin-bottom: 8px;
}
.order-header :deep(.panel-title) { margin-bottom: 0; }
.period-switcher {
  display: flex; gap: 2px;
  background: #f3f4f6;
  border-radius: 6px; padding: 2px;
}
.period-btn {
  border: none; background: transparent; color: var(--text-dim);
  font-size: 11px; font-family: var(--font-sans);
  padding: 2px 10px; border-radius: 4px; cursor: pointer; transition: all 0.2s;
}
.period-btn:hover { color: var(--text-primary); }
.period-btn.active {
  background: var(--color-primary); color: #fff; font-weight: 600;
}
.order-row { display: flex; align-items: center; gap: 14px; flex: 1; min-height: 0; }
.order-item { flex: 1; display: flex; flex-direction: column; justify-content: center; min-width: 0; }
.order-label { font-size: 12px; color: var(--text-secondary); line-height: 1.4; }
.order-value { font-size: clamp(16px, 2vw, 26px); font-weight: 700; color: var(--text-primary); line-height: 1.2; white-space: nowrap; }
.order-value.accent { color: var(--color-primary); }
.order-divider { width: 1px; height: 32px; background: #e5e7eb; flex-shrink: 0; }
</style>
