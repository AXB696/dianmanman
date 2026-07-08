import type { OrderKPIs, RevenuePoint, ChannelItem } from '@/types'

/** 模拟：订单&收入 KPI */
export const mockOrderKPIs: OrderKPIs = {
  total_orders: 20301987,
  total_revenue_wan: 99834,
}

/** 模拟：月度营收趋势（1-12月，单位：万元） */
export const mockRevenueTrend: RevenuePoint[] = [
  { month: '1月', expected: 6200, actual: 5800 },
  { month: '2月', expected: 5800, actual: 5100 },
  { month: '3月', expected: 7100, actual: 7300 },
  { month: '4月', expected: 7500, actual: 7800 },
  { month: '5月', expected: 8000, actual: 8200 },
  { month: '6月', expected: 8200, actual: 7900 },
  { month: '7月', expected: 8500, actual: 8800 },
  { month: '8月', expected: 8600, actual: 9100 },
  { month: '9月', expected: 8800, actual: 8400 },
  { month: '10月', expected: 9000, actual: 9300 },
  { month: '11月', expected: 9200, actual: 9600 },
  { month: '12月', expected: 9500, actual: 0 }, // 尚未结束
]

/** 模拟：渠道分布 */
export const mockChannels: ChannelItem[] = [
  { name: 'App直充', percent: 42 },
  { name: '场站扫码', percent: 28 },
  { name: '小程序', percent: 19 },
  { name: '第三方平台', percent: 11 },
  { name: '企业合作', percent: 8 },
  { name: '政府项目', percent: 6 },
  { name: '分销渠道', percent: 4 },
]

/** 模拟：季度进度 */
export const mockQuarterProgress: number = 75
export const mockQuarterRevenue: number = 1321
export const mockYoYGrowth: number = 1.50
