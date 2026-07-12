<template>
  <div class="pager-wrap">
    <div class="pager-btns">
      <!-- 首页 -->
      <button :disabled="currentPage <= 0" @click="$emit('change', 0)">«</button>
      <!-- 上一页 -->
      <button :disabled="currentPage <= 0" @click="$emit('change', currentPage - 1)">‹</button>

      <!-- 页码 -->
      <template v-for="p in pages" :key="p">
        <span v-if="p === '...'" class="ellipsis">…</span>
        <button v-else :class="{ active: p - 1 === currentPage }" @click="$emit('change', p - 1)">
          {{ p }}
        </button>
      </template>

      <!-- 下一页 -->
      <button :disabled="currentPage >= totalPages - 1" @click="$emit('change', currentPage + 1)">›</button>
      <!-- 末页 -->
      <button :disabled="currentPage >= totalPages - 1" @click="$emit('change', totalPages - 1)">»</button>
    </div>
    <span class="total-text">共 {{ total }} 条</span>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  currentPage: number   // 0-based
  totalPages: number
  total: number
}>()

defineEmits<{ change: [page: number] }>() // page 也是 0-based

const pages = computed(() => {
  const n = props.totalPages
  if (n <= 7) return Array.from({ length: n }, (_, i) => i + 1)

  const cur = props.currentPage + 1  // 1-based
  const result: (number | string)[] = [1]

  if (cur > 3) result.push('...')

  const start = Math.max(2, cur - 1)
  const end = Math.min(n - 1, cur + 1)
  for (let i = start; i <= end; i++) result.push(i)

  if (cur < n - 2) result.push('...')

  result.push(n)
  return result
})
</script>

<style scoped>
.pager-wrap {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 16px;
  margin-top: 20px;
  user-select: none;
}
.pager-btns {
  display: flex;
  align-items: center;
  gap: 3px;
}
.pager-btns button {
  min-width: 34px;
  height: 34px;
  padding: 0 8px;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
  background: #fff;
  cursor: pointer;
  font-size: 13px;
  color: #475569;
  font-family: inherit;
  transition: all 0.15s;
  display: inline-flex;
  align-items: center;
  justify-content: center;
}
.pager-btns button:hover:not(:disabled):not(.active) {
  border-color: #1a56db;
  color: #1a56db;
  background: #f8faff;
}
.pager-btns button.active {
  background: #1a56db;
  color: #fff;
  border-color: #1a56db;
  font-weight: 600;
}
.pager-btns button:disabled {
  opacity: 0.3;
  cursor: not-allowed;
}
.ellipsis {
  width: 34px;
  text-align: center;
  color: #94a3b8;
  font-size: 14px;
  letter-spacing: 2px;
}
.total-text {
  font-size: 12px;
  color: #94a3b8;
  white-space: nowrap;
}
</style>
