import api from './index'
import type { StationListResponse } from '@/types'

/**
 * 获取充电站列表（管理端，用于 KPI 统计、表格、饼图）
 */
export async function fetchAdminStations(params?: {
  district?: string
  station_type?: string
  limit?: number
  offset?: number
  sort?: string
  order?: string
}): Promise<StationListResponse> {
  return await api.get('/admin/stations', { params }) as any
}
