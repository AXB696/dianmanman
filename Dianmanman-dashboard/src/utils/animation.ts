import { ref, onMounted, type Ref } from 'vue'

/**
 * 数字滚动动画 composable
 * 从 0 缓动到目标值，持续 duration ms
 */
export function useCountUp(target: Ref<number>, duration: number = 1200) {
  const display = ref(0)

  onMounted(() => {
    const start = performance.now()
    const from = 0
    const to = target.value

    function tick(now: number) {
      const elapsed = now - start
      const progress = Math.min(elapsed / duration, 1)
      // easeOutCubic
      const eased = 1 - Math.pow(1 - progress, 3)
      display.value = Math.round(from + (to - from) * eased)
      if (progress < 1) {
        requestAnimationFrame(tick)
      }
    }

    requestAnimationFrame(tick)
  })

  return display
}

/**
 * 逐行渐显 stagger 工具
 * 返回延迟秒数，配合 CSS animation-delay 使用
 */
export function staggerDelay(index: number, base: number = 0.08): string {
  return `${index * base}s`
}
