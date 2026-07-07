import api from './index'

/** 数据大屏 KPI 概览 */
export interface DashboardStats {
  total_stations: number
  total_piles: number
  available_piles: number
  busy_stations: number
  online_stations: number
  online_rate: number
  total_charges: number
  total_users: number
  today_charges: number
}

/** 站点实时状态 */
export interface StationStatus {
  station_id: string
  name: string
  district_group: string
  type: string
  type_name: string
  address: string
  pile_count: number
  power_kw: number
  rating: number
  operator: string
  availability: { total: number; available: number; occupied: number }
  price: { electricity: number; service_fee: number; total: number; unit: string }
  location: { lat: number; lng: number }
  tel: string
}

/** 热门站点排行 */
export interface TopStation {
  station_id: string
  name: string
  count: number
}

/** 车辆品牌分布 */
export interface BrandItem {
  brand: string
  count: number
  percent: number
}

/** 每日新增用户 */
export interface DailyUsers {
  dates: string[]
  counts: number[]
}

/** 充电时段分布 */
export interface HourlyCharging {
  periods: string[]
  counts: number[]
}

// ── API 函数 ──

/** 获取数据大屏 KPI 概览 */
export function getDashboardStats(): Promise<any> {
  return api.get('/admin/stats/dashboard')
}

/** 获取所有站点实时状态 */
export function getStationStatus(): Promise<any> {
  return api.get('/admin/stats/station-status')
}

/** 获取热门站点排行 */
export function getTopStations(limit = 10): Promise<any> {
  return api.get('/admin/stats/top-stations', { params: { limit } })
}

/** 获取车辆品牌分布 */
export function getVehicleBrands(): Promise<any> {
  return api.get('/admin/stats/vehicle-brands')
}

/** 获取每日新增用户趋势 */
export function getDailyUsers(days = 30): Promise<any> {
  return api.get('/admin/stats/daily-users', { params: { days } })
}

/** 获取充电时段分布 */
export function getChargingByHour(): Promise<any> {
  return api.get('/admin/stats/charging-by-hour')
}

/** 获取全局基础统计（用户/车辆/收藏/历史数量） */
export function getBaseStats(): Promise<any> {
  return api.get('/admin/stats')
}

/** 获取综合概览统计（今日新增/充电、活跃电站、人均充电等） */
export function getOverviewStats(): Promise<any> {
  return api.get('/admin/stats/overview')
}
