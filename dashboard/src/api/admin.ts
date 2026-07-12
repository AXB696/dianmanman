import api from './index'

// ── 用户管理 ──
export function getUsers(params: any) {
  return api.get('/users', { params })
}
export function deleteUser(id: number) {
  return api.delete(`/admin/users/${id}`)
}
export function getUserVehicles(userId: number) {
  return api.get(`/users/${userId}/vehicles`)
}

// ── 管理员账号 ──
export function getAdminUsers() {
  return api.get('/admin/users')
}
export function createAdminUser(data: any) {
  return api.post('/admin/users', data)
}
export function changePassword(userId: number, password: string) {
  return api.put(`/admin/users/${userId}/password`, { new_password: password })
}
export function deleteAdminUser(id: number) {
  return api.delete(`/admin/users/${id}`)
}

// ── 公告管理 ──
export function getAnnouncements(params?: any) {
  return api.get('/admin/announcements', { params })
}
export function createAnnouncement(data: any) {
  return api.post('/admin/announcements', data)
}
export function updateAnnouncement(id: number, data: any) {
  return api.put(`/admin/announcements/${id}`, data)
}
export function deleteAnnouncement(id: number) {
  return api.delete(`/admin/announcements/${id}`)
}

// ── 电站管理 ──
export function getAdminStations(params?: any) {
  return api.get('/admin/stations', { params })
}

// ── 统计 ──
export { getDashboardStats, getBaseStats, getOverviewStats, getTopStations, getVehicleBrands, getDailyUsers, getChargingByHour } from './dashboard'
