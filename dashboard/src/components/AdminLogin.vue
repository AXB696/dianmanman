<template>
  <div class="login-wrapper">
    <!-- 登录表单 -->
    <div v-if="!showChooser" class="login-container">
      <div class="login-left">
        <!-- 装饰圆 -->
        <div class="deco-circle c1"></div>
        <div class="deco-circle c2"></div>
        <div class="deco-circle c3"></div>
        <div class="deco-circle c4"></div>

        <!-- 品牌区 -->
        <div class="brand">
          <div class="brand-icon-wrap">
            <img :src="logoUrl" alt="电满满" class="brand-svg" />
          </div>
          <h1>电满满</h1>
          <p class="brand-sub">DianManMan · 智能充电运营平台</p>
        </div>

        <!-- 数据展示 -->
        <div class="stats-row">
          <div class="stat-item">
            <span class="stat-num">982</span>
            <span class="stat-label">充电站</span>
          </div>
          <div class="stat-divider"></div>
          <div class="stat-item">
            <span class="stat-num">15+</span>
            <span class="stat-label">品牌车型</span>
          </div>
          <div class="stat-divider"></div>
          <div class="stat-item">
            <span class="stat-num">24h</span>
            <span class="stat-label">实时监控</span>
          </div>
        </div>

        <!-- 功能列表 -->
        <div class="feature-list">
          <div class="feature-item">
            <div class="feature-icon">📊</div>
            <div>
              <div class="feature-title">数据大屏</div>
              <div class="feature-desc">全平台实时运营监控</div>
            </div>
          </div>
          <div class="feature-item">
            <div class="feature-icon">⚙️</div>
            <div>
              <div class="feature-title">管理后台</div>
              <div class="feature-desc">用户 · 公告 · 电站一站式管理</div>
            </div>
          </div>
          <div class="feature-item">
            <div class="feature-icon">🤖</div>
            <div>
              <div class="feature-title">AI 推荐引擎</div>
              <div class="feature-desc">多目标加权智能充电推荐</div>
            </div>
          </div>
        </div>

        <p class="brand-footer">© 2026 Smart Charge Team</p>
      </div>
      <div class="login-right">
        <div class="login-card">
          <h2>管理员登录</h2>
          <form @submit.prevent="handleLogin">
            <div class="field">
              <label>用户名</label>
              <input v-model="username" type="text" placeholder="请输入用户名" autofocus />
            </div>
            <div class="field">
              <label>密码</label>
              <input v-model="password" type="password" placeholder="请输入密码" @keydown.enter="handleLogin" />
            </div>
            <p v-if="error" class="error">{{ error }}</p>
            <button type="submit" class="btn" :disabled="loading">
              {{ loading ? '登录中...' : '登 录' }}
            </button>
          </form>
        </div>
      </div>
    </div>

    <!-- 平台选择（仅超级管理员可选择数据大屏 + 管理后台，普通管理员直接进管理后台） -->
    <div v-else class="chooser-container">
      <div class="chooser-card">
        <div class="chooser-user">
          <div class="avatar">{{ userDisplay[0] }}</div>
          <div>
            <div class="welcome">欢迎回来</div>
            <div class="name">{{ userDisplay }} <span class="role-tag" :class="roleTagClass">{{ roleLabel }}</span></div>
          </div>
          <button class="logout-btn" @click="logout">退出</button>
        </div>
        <p class="chooser-hint">
          <template v-if="isSuperAdmin">请选择要进入的系统</template>
          <template v-else>您当前为管理员，仅可访问管理后台</template>
        </p>
        <div class="chooser-grid">
          <!-- 数据大屏：仅超级管理员可见 -->
          <button v-if="isSuperAdmin" class="chooser-item" @click="goDashboard">
            <div class="chooser-icon-wrap bg-cyan">📊</div>
            <div>
              <div class="chooser-name">数据大屏</div>
              <div class="chooser-desc">实时运营监控看板 · 全平台数据概览</div>
            </div>
            <span class="arrow">→</span>
          </button>
          <!-- 管理后台：所有管理员可见 -->
          <button class="chooser-item" @click="goAdmin">
            <div class="chooser-icon-wrap bg-blue">⚙️</div>
            <div>
              <div class="chooser-name">管理后台</div>
              <div class="chooser-desc">用户管理 · 站内公告 · 电站总览 · 管理员账号</div>
            </div>
            <span class="arrow">→</span>
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { useRouter } from 'vue-router'
import { adminLogin, getCurrentUser } from '@/api/auth'
import logoUrl from '@/assets/app_icon.png'

const emit = defineEmits<{ login: []; selectAdmin: [] }>()
const router = useRouter()

const username = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')
const showChooser = ref(false)
const userRole = ref('')
const userNickname = ref('')

const userDisplay = computed(() => userNickname.value || username.value || '管理员')
const roleLabel = computed(() => {
  if (userRole.value === 'super_admin') return '超级管理员'
  if (userRole.value === 'admin') return '管理员'
  return ''
})
// 权限判断
const isSuperAdmin = computed(() => userRole.value === 'super_admin')
// 角色标签样式
const roleTagClass = computed(() => isSuperAdmin.value ? 'role-super' : 'role-admin')

async function handleLogin() {
  error.value = ''
  if (!username.value || !password.value) {
    error.value = '请输入用户名和密码'
    return
  }
  loading.value = true
  try {
    const res: any = await adminLogin(username.value, password.value)
    const token = res.access_token
    if (!token) { error.value = '登录失败'; return }

    localStorage.setItem('admin_token', token)
    localStorage.setItem('admin_user', username.value)

    try {
      const user: any = await getCurrentUser(token)
      userRole.value = user.role || ''
      userNickname.value = user.nickname || ''
      localStorage.setItem('admin_role', userRole.value)

      if (userRole.value !== 'admin' && userRole.value !== 'super_admin') {
        error.value = '此账号无管理权限'
        localStorage.removeItem('admin_token')
        return
      }
    } catch (_) {
      userRole.value = 'admin'
    }

    showChooser.value = true
  } catch (e: any) {
    error.value = e?.response?.data?.detail || e?.message || '登录失败'
  } finally {
    loading.value = false
  }
}

function goDashboard() {
  // emit 触发 loggedIn=true → App.vue 自动渲染数据大屏（当前已在 / 路径）
  emit('login')
}
function goAdmin() {
  // emit 触发 loggedIn=true，同时导航到管理后台路由
  emit('selectAdmin')
  router.push('/admin/dashboard')
}

function logout() {
  localStorage.removeItem('admin_token')
  localStorage.removeItem('admin_user')
  localStorage.removeItem('admin_role')
  showChooser.value = false
  username.value = ''
  password.value = ''
}
</script>

<style scoped>
/* ── 整体布局 ── */
.login-wrapper {
  position: absolute; top: 0; left: 0; width: 100%; height: 100%;
  z-index: 999;
}

/* ── 登录页：左右分栏 ── */
.login-container { display: flex; height: 100%; background: #f0f2f5; }

/* ═══════ 左侧品牌区 ═══════ */
.login-left {
  flex: 0 0 500px;
  background: linear-gradient(160deg, #0f172a 0%, #1e3a5f 35%, #1a56db 100%);
  display: flex; flex-direction: column; justify-content: center;
  padding: 60px 56px; color: #fff;
  position: relative; overflow: hidden;
}

/* 装饰圆 */
.deco-circle {
  position: absolute; border-radius: 50%;
  background: rgba(255,255,255,0.03);
}
.deco-circle.c1 { width: 360px; height: 360px; top: -120px; right: -100px; }
.deco-circle.c2 { width: 200px; height: 200px; bottom: -60px; left: -40px; }
.deco-circle.c3 { width: 80px; height: 80px; top: 35%; right: 60px; background: rgba(255,255,255,0.04); }
.deco-circle.c4 { width: 140px; height: 140px; bottom: 30%; left: 50px; background: rgba(255,255,255,0.025); }

/* 品牌 */
.brand { margin-bottom: 40px; }
.brand-icon-wrap { margin-bottom: 20px; }
.brand-svg { width: 96px; height: 96px; }
.brand h1 { font-size: 34px; font-weight: 800; margin: 0 0 6px; letter-spacing: 0.04em; }
.brand-sub { font-size: 13px; opacity: 0.55; margin: 0; letter-spacing: 0.06em; }

/* 数据统计 */
.stats-row { display: flex; align-items: center; gap: 0; margin-bottom: 40px; padding: 16px 0; border-top: 1px solid rgba(255,255,255,0.08); border-bottom: 1px solid rgba(255,255,255,0.08); }
.stat-item { flex: 1; text-align: center; }
.stat-num { display: block; font-size: 22px; font-weight: 800; letter-spacing: 0.02em; }
.stat-label { display: block; font-size: 11px; opacity: 0.5; margin-top: 2px; letter-spacing: 0.05em; }
.stat-divider { width: 1px; height: 32px; background: rgba(255,255,255,0.1); flex-shrink: 0; }

/* 功能列表 */
.feature-list { display: flex; flex-direction: column; gap: 14px; margin-bottom: auto; }
.feature-item { display: flex; align-items: flex-start; gap: 14px; }
.feature-icon { width: 40px; height: 40px; border-radius: 10px; background: rgba(255,255,255,0.08); display: flex; align-items: center; justify-content: center; font-size: 18px; flex-shrink: 0; }
.feature-title { font-size: 13px; font-weight: 600; }
.feature-desc { font-size: 11px; opacity: 0.45; margin-top: 2px; }

/* 底部 */
.brand-footer { font-size: 11px; opacity: 0.25; text-align: center; margin-top: 48px; }

.login-right {
  flex: 1; display: flex; align-items: center; justify-content: center;
}
.login-card {
  background: #fff; border-radius: 12px; padding: 40px;
  width: 380px; box-shadow: 0 2px 16px rgba(0,0,0,0.06);
}
.login-card h2 { margin: 0 0 32px; font-size: 22px; color: #1a1a2e; text-align: center; }
.field { margin-bottom: 20px; }
.field label { display: block; font-size: 13px; color: #64748b; margin-bottom: 6px; }
.field input {
  width: 100%; padding: 10px 14px; border: 1px solid #e2e8f0;
  border-radius: 8px; font-size: 14px; outline: none;
  transition: border-color 0.2s; box-sizing: border-box;
}
.field input:focus { border-color: #1a56db; }
.error { color: #ef4444; font-size: 12px; margin: 0 0 12px; }
.btn {
  width: 100%; padding: 12px; background: #1a56db; color: #fff;
  border: none; border-radius: 8px; font-size: 15px; font-weight: 600;
  cursor: pointer; transition: background 0.2s;
}
.btn:hover { background: #1e40af; }
.btn:disabled { opacity: 0.6; cursor: not-allowed; }

/* ── 平台选择页 ── */
.chooser-container {
  height: 100%; background: #f0f2f5;
  display: flex; align-items: center; justify-content: center;
}
.chooser-card {
  background: #fff; border-radius: 16px; padding: 40px;
  width: 520px; box-shadow: 0 2px 24px rgba(0,0,0,0.06);
}
.chooser-user {
  display: flex; align-items: center; gap: 14px;
  padding-bottom: 24px; border-bottom: 1px solid #f1f5f9; margin-bottom: 24px;
}
.avatar {
  width: 48px; height: 48px; border-radius: 50%;
  background: linear-gradient(135deg, #1a56db, #7c3aed);
  color: #fff; display: flex; align-items: center; justify-content: center;
  font-size: 20px; font-weight: 700; flex-shrink: 0;
}
.welcome { font-size: 12px; color: #94a3b8; }
.name { font-size: 16px; font-weight: 600; color: #1a1a2e; }
.role-tag {
  font-size: 11px; background: #eff6ff; color: #1a56db;
  padding: 1px 8px; border-radius: 10px; margin-left: 6px;
}
.logout-btn {
  margin-left: auto; background: none; border: 1px solid #e2e8f0;
  border-radius: 6px; padding: 6px 14px; font-size: 12px;
  color: #64748b; cursor: pointer;
}
.logout-btn:hover { color: #ef4444; border-color: #fca5a5; }
.chooser-hint {
  font-size: 14px; color: #64748b; margin: 0 0 20px; text-align: center;
}
.chooser-grid { display: flex; flex-direction: column; gap: 12px; }
.chooser-item {
  display: flex; align-items: center; gap: 16px;
  padding: 20px; border: 1px solid #e2e8f0; border-radius: 12px;
  background: #fff; cursor: pointer; transition: all 0.2s; text-align: left;
}
.chooser-item:hover {
  border-color: #1a56db; background: #f8fafc;
  transform: translateX(4px);
}
.chooser-icon-wrap {
  width: 48px; height: 48px; border-radius: 12px;
  display: flex; align-items: center; justify-content: center;
  font-size: 24px; flex-shrink: 0;
}
.bg-cyan { background: #ecfeff; }
.bg-blue { background: #eff6ff; }
.chooser-name { font-size: 15px; font-weight: 600; color: #1a1a2e; }
.chooser-desc { font-size: 12px; color: #94a3b8; margin-top: 2px; }
.arrow { margin-left: auto; color: #94a3b8; font-size: 18px; }
</style>
