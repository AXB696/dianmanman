import api from './index'

/** 管理员登录 */
export function adminLogin(username: string, password: string): Promise<{
  access_token: string
  refresh_token: string
  token_type: string
}> {
  return api.post('/auth/login', { username, password })
}

/** 检查 token 是否有效（获取当前用户信息） */
export function getCurrentUser(token: string): Promise<{
  id: number; username: string; nickname: string; role: string
}> {
  return api.get('/users/me', {
    headers: { Authorization: `Bearer ${token}` },
  })
}
