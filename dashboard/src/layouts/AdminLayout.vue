<template>
  <div class="admin-app">
    <!-- 侧边栏 -->
    <aside class="sidebar">
      <div class="sidebar-brand">
        <img :src="logoUrl" alt="电满满" class="brand-icon" />
        <span class="brand-text">电满满</span>
      </div>
      <nav class="sidebar-nav">
        <a v-for="item in navItems" :key="item.key"
          :class="['nav-item', { active: activePage === item.key }]"
          @click="navigateTo(item.key)">
          <span v-html="item.icon"></span>
          <span>{{ item.label }}</span>
        </a>
      </nav>
      <div class="sidebar-footer">
        <!-- 数据大屏入口仅超级管理员可见 -->
        <a v-if="isSuper" class="nav-item" @click="router.push('/')">
          <span>📊</span><span>数据大屏</span>
        </a>
        <a class="nav-item logout" @click="handleLogout">
          <span>↩️</span><span>退出登录</span>
        </a>
      </div>
    </aside>

    <!-- 内容区：由 vue-router 根据 URL 自动渲染对应的管理页面 -->
    <main class="main-content">
      <router-view />
    </main>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import logoUrl from '@/assets/app_icon.png'

const route = useRoute()
const router = useRouter()

const emit = defineEmits<{ logout: [] }>()

// 根据当前路由路径推导活跃的侧边栏项
const activePage = computed(() => {
  const path = route.path
  if (path.includes('/users')) return 'users'
  if (path.includes('/admins')) return 'admins'
  if (path.includes('/announcements')) return 'announcements'
  if (path.includes('/stations')) return 'stations'
  return 'dashboard'
})

// 读取用户角色判断是否为超级管理员（控制"管理员账号"菜单显隐）
const isSuper = computed(() => localStorage.getItem('admin_role') === 'super_admin')

const navItems = computed(() => {
  const items: any[] = [
    { key: 'dashboard', label: 'Dashboard', icon: '📈' },
    { key: 'users', label: '用户管理', icon: '👥' },
  ]
  if (isSuper.value) {
    items.push({ key: 'admins', label: '管理员账号', icon: '🔑' })
  }
  items.push({ key: 'announcements', label: '站内公告', icon: '📢' })
  items.push({ key: 'stations', label: '电站总览', icon: '📍' })
  return items
})

// 点击侧边栏导航 → 改变 URL → router-view 自动更新
function navigateTo(key: string) {
  router.push(`/admin/${key === 'dashboard' ? 'dashboard' : key}`)
}

function handleLogout() {
  localStorage.removeItem('admin_token')
  localStorage.removeItem('admin_user')
  localStorage.removeItem('admin_role')
  emit('logout')
}
</script>

<style scoped>
.admin-app { display: flex; height: 100vh; background: #f0f2f5; }
.sidebar {
  width: 220px; background: #fff; display: flex; flex-direction: column;
  border-right: 1px solid #e2e8f0; flex-shrink: 0;
}
.sidebar-brand {
  padding: 20px; display: flex; align-items: center; gap: 10px;
  border-bottom: 1px solid #f1f5f9;
}
.brand-icon { width: 42px; height: 42px; color: #1a56db; }
.brand-text { font-size: 18px; font-weight: 700; color: #1a1a2e; }
.sidebar-nav { flex: 1; padding: 12px 8px; display: flex; flex-direction: column; gap: 2px; }
.nav-item {
  display: flex; align-items: center; gap: 10px; padding: 10px 14px;
  border-radius: 8px; color: #475569; font-size: 14px; cursor: pointer;
  transition: all 0.15s; text-decoration: none;
}
.nav-item:hover { background: #f1f5f9; color: #1a1a2e; }
.nav-item.active { background: #eff6ff; color: #1a56db; font-weight: 600; }
.sidebar-footer {
  padding: 12px 8px; border-top: 1px solid #f1f5f9;
  display: flex; flex-direction: column; gap: 2px;
}
.logout:hover { color: #ef4444 !important; background: #fef2f2 !important; }
.main-content { flex: 1; overflow-y: auto; }
</style>
