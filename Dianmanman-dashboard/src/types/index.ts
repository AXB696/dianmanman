/** 充电站数据结构（来自后端） */
export interface ChargingStation {
  station_id: string
  name: string
  district_group: string
  type: 'ultra' | 'fast' | 'slow' | 'destination' | 'fleet' | 'swap'
  type_name: string
  address: string
  pile_count: number
  power_kw: number
  availability: {
    total: number
    available: number
    occupied: number
  }
  rating: number
  lat: number
  lng: number
  operator?: string
  open_hours?: string
  tel?: string
  facilities?: string[]
  price?: {
    total: number
    unit: string
  }
}

/** 聚合后的 KPI 数据 */
export interface StationKPIs {
  total_stations: number
  quarterly_new: number
  total_piles: number
  abnormal_count: number
  online_rate: number
}

/** 订单&收入 KPI */
export interface OrderKPIs {
  total_orders: number
  total_revenue_wan: number
}

/** 月度营收数据点 */
export interface RevenuePoint {
  month: string
  expected: number
  actual: number
}

/** 渠道项 */
export interface ChannelItem {
  name: string
  percent: number
}

/** 排名项 */
export interface RankItem {
  rank: number
  name: string
  district: string
  value: number
  unit: string
}

/** 电站列表 API 响应 */
export interface StationListResponse {
  total: number
  districts: string[]
  types: string[]
  summary: {
    total: number
    ultra_count: number
    fast_count: number
    avg_rating: number
  }
  stations: ChargingStation[]
}
