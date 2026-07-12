import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    // 管理后台路由（由 AdminLayout 承载，子页面通过 <router-view> 渲染）
    {
      path: '/admin',
      component: () => import('@/layouts/AdminLayout.vue'),
      children: [
        // 访问 /admin 时自动跳转到 dashboard
        { path: '', redirect: '/admin/dashboard' },
        { path: 'dashboard', name: 'dashboard', component: () => import('@/views/admin/DashboardPage.vue') },
        { path: 'users', name: 'users', component: () => import('@/views/admin/UsersPage.vue') },
        { path: 'admins', name: 'admins', component: () => import('@/views/admin/AdminsPage.vue') },
        { path: 'announcements', name: 'announcements', component: () => import('@/views/admin/AnnouncementsPage.vue') },
        { path: 'stations', name: 'stations', component: () => import('@/views/admin/StationsPage.vue') },
        { path: 'operators', name: 'operators', component: () => import('@/views/admin/OperatorsPage.vue') },
      ],
    },
    // 注意：数据大屏（/）由 App.vue 直接渲染，不需要路由组件
    // 不设置 catch-all redirect，避免重定向循环干扰 App.vue 的路由判断
  ],
})

// 路由守卫：未登录用户访问 /admin/* 时重定向到首页
router.beforeEach((to, _from, next) => {
  const token = localStorage.getItem('admin_token')
  if (to.path.startsWith('/admin') && !token) {
    // 未登录 → 回到首页显示登录框
    next('/')
  } else {
    next()
  }
})

export default router