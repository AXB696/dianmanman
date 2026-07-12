<template>
  <div class="panel" style="display:flex;flex-direction:column;flex:1;overflow:hidden">
    <div class="panel-title">热门站点排行 <span style="font-size:10px;color:var(--text-dim)">近30日充电量</span></div>
    <div class="rank-list">
      <div class="rank-item" v-for="item in rankings" :key="item.rank"
           :style="{ animationDelay: staggerDelay(item.rank - 1, 0.06) }">
        <span class="rank-num" :class="'rank-' + (item.rank <= 3 ? item.rank : 'other')">
          {{ item.rank <= 3 ? ['🥇','🥈','🥉'][item.rank - 1] : item.rank }}
        </span>
        <div class="rank-info">
          <span class="rank-name">{{ item.name }}</span>
          <span class="rank-district">{{ item.district }}</span>
        </div>
        <span class="rank-value number">{{ formatWan(item.value) }}{{ item.unit }}</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { formatWan } from '@/utils/format'
import { staggerDelay } from '@/utils/animation'
import { getTopStations } from '@/api/dashboard'

interface RankItem { rank: number; name: string; district: string; value: number; unit: string }

const rankings = ref<RankItem[]>([])

onMounted(async () => {
  try {
    const data = await getTopStations(10)
    rankings.value = (data.stations || []).map((s: any, i: number) => ({
      rank: i + 1,
      name: s.name,
      district: '',
      value: s.count,
      unit: ' 次',
    }))
  } catch (_) {}
})
</script>

<style scoped>
.rank-list { display: flex; flex-direction: column; gap: 6px; overflow-y: auto; flex: 1; }
.rank-item {
  display: flex;
  align-items: center;
  gap: 10px;
  padding: 6px 8px;
  border-radius: var(--radius-sm);
  background: #f9fafb;
  animation: fadeInRight 0.4s ease backwards;
}
.rank-num { font-size: 16px; width: 24px; text-align: center; flex-shrink: 0; }
.rank-other { font-size: 12px; color: var(--text-dim); font-weight: 700; }
.rank-info { flex: 1; min-width: 0; display: flex; flex-direction: column; }
.rank-name { font-size: 12px; color: var(--text-primary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.rank-district { font-size: 10px; color: var(--text-secondary); }
.rank-value { font-size: 12px; font-weight: 600; color: var(--color-primary); flex-shrink: 0; }

@keyframes fadeInRight {
  from { opacity: 0; transform: translateX(16px); }
  to { opacity: 1; transform: translateX(0); }
}
</style>
