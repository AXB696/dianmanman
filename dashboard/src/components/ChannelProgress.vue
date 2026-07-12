<template>
  <div class="panel" style="display:flex;gap:16px">
    <!-- 渠道分布 -->
    <div style="flex:1;display:flex;flex-direction:column;min-height:0;overflow:hidden">
      <div class="panel-title" style="flex-shrink:0">渠道分布</div>
      <div class="channel-list">
        <div class="channel-bar" v-for="ch in channels" :key="ch.name">
          <span class="channel-name">{{ ch.name }}</span>
          <div class="channel-track">
            <div class="channel-fill" :style="{ width: ch.percent + '%' }"></div>
          </div>
          <span class="channel-pct number">{{ ch.percent }}%</span>
        </div>
      </div>
    </div>

    <!-- 季度进度 -->
    <div style="width:120px;text-align:center;padding:0 4px">
      <div class="panel-title">一季度进度</div>
      <div class="ring-container">
        <svg viewBox="2 2 96 96" width="86" height="86">
          <circle cx="50" cy="50" r="42" fill="none"
                  stroke="#f3f4f6" stroke-width="6" />
          <circle cx="50" cy="50" r="42" fill="none"
                  stroke="#1677ff" stroke-width="6" stroke-linecap="round"
                  :stroke-dasharray="2 * Math.PI * 42"
                  :stroke-dashoffset="2 * Math.PI * 42 * (1 - quarterProgress / 100)"
                  transform="rotate(-90 50 50)"
                  style="transition: stroke-dashoffset 1.5s ease" />
          <text x="50" y="46" text-anchor="middle" fill="#1f2937"
                font-size="20" font-weight="700" class="number">{{ quarterProgress }}%</text>
          <text x="50" y="62" text-anchor="middle" fill="#6b7280" font-size="9">完成度</text>
        </svg>
      </div>
      <div style="font-size:10px;color:var(--text-dim);margin-top:4px">
        销售额 {{ quarterRevenue }}万 · 同比 <span style="color:var(--color-primary)">+{{ (yoYGrowth * 100).toFixed(0) }}%</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import { mockChannels, mockQuarterProgress, mockQuarterRevenue, mockYoYGrowth } from '@/mock/business'

const channels = ref(mockChannels)
const quarterProgress = ref(mockQuarterProgress)
const quarterRevenue = ref(mockQuarterRevenue)
const yoYGrowth = ref(mockYoYGrowth)
</script>

<style scoped>
.channel-list { display: flex; flex-direction: column; gap: 10px; overflow-y: auto; flex: 1; min-height: 0; padding-right: 4px; }
.channel-bar { display: flex; align-items: center; gap: 8px; }
.channel-name { font-size: 11px; color: var(--text-secondary); width: 70px; flex-shrink: 0; }
.channel-track { flex: 1; height: 6px; background: #f3f4f6; border-radius: 3px; overflow: hidden; }
.channel-fill { height: 100%; background: linear-gradient(90deg, #1677ff, #4096ff); border-radius: 3px; transition: width 1s ease; }
.channel-pct { font-size: 11px; color: var(--color-primary); width: 32px; text-align: right; }
.ring-container {
  display: flex;
  justify-content: center;
  overflow: visible;
}

.ring-container svg {
  overflow: visible;
}
</style>
