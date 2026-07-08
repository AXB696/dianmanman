import axios from 'axios'

// 后端 API 地址（相对路径，开发时 vite proxy 转发到 localhost:8000，生产时 nginx 代理）
const API_BASE = '/api'

const api = axios.create({
  baseURL: API_BASE,
  timeout: 10000,
  headers: { 'Content-Type': 'application/json' },
})

// 请求拦截：自动附加 admin token
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('admin_token')
  if (token) {
    config.headers.Authorization = `Bearer ${token}`
  }
  return config
})

// 响应拦截：提取 data 字段
api.interceptors.response.use(
  (res) => res.data,
  (err) => {
    if (err.response?.status === 401) {
      localStorage.removeItem('admin_token')
      localStorage.removeItem('admin_user')
      localStorage.removeItem('admin_role')
      // 401 时跳转到首页显示登录框（仅在非登录接口时触发）
      if (!err.config.url?.includes('/auth/login')) {
        window.location.href = '/'
      }
    }
    console.error('[API Error]', err.message)
    return Promise.reject(err)
  }
)

export default api
