/**
 * 大数字格式化：20301987 → "20,301,987"
 */
export function formatNumber(n: number): string {
  return n.toLocaleString('zh-CN')
}

/**
 * 缩写大数字：20301987 → "2030.2万"
 */
export function formatWan(n: number): string {
  if (n >= 10000) {
    return (n / 10000).toFixed(1) + '万'
  }
  return String(n)
}

/**
 * 保留1位小数
 */
export function formatDecimal(n: number): string {
  return n.toFixed(1)
}

/**
 * 百分比
 */
export function formatPercent(n: number): string {
  return (n * 100).toFixed(0) + '%'
}

/**
 * 温度/评分等
 */
export function formatRating(n: number): string {
  return n.toFixed(1)
}
