<template>
  <!-- 未登录时显示登录页 -->
  <AdminLogin v-if="!loggedIn" @login="loggedIn = true" @selectAdmin="loggedIn = true" />

  <!-- 管理后台（由 vue-router 控制，AdminLayout 作为 layout 组件渲染子页面） -->
  <router-view v-else-if="isAdminRoute" @logout="handleLogout" />

  <!-- 数据大屏 -->
  <div v-else class="dashboard" :style="dashboardStyle">
    <!-- 顶部标题栏 -->
    <header class="header">
      <div class="header-left">
        <img :src="logoUrl" alt="电满满" class="logo-icon" />
      </div>
      <div class="header-center">
        <h1 class="title">电满满 · 智能充电运营看板</h1>
        <p class="subtitle">DianManMan Operations Dashboard</p>
      </div>
      <div class="header-right">
        <button class="op-btn" @click="showOperators = true">运营商</button>
        <button class="op-btn" @click="opMode = 4; showOperators = true">营收排行</button>
        <!-- 管理后台入口仅超级管理员可见（普通管理员在 chooser 阶段已直接跳转管理后台） -->
        <button v-if="isSuperAdmin" class="op-btn" @click="goToAdmin">管理后台</button>
        <button class="op-btn logout-btn" @click="handleLogout">退出</button>
        <span class="time">{{ currentTime }}</span>
      </div>
    </header>

    <AlertTicker @station-click="focusMapStation" />

    <!-- 主体三列 -->
    <main class="main-grid">
      <!-- 左列：运维监控 -->
      <section class="col-left" v-show="showLeftPanel">
        <KpiCards @kpi-click="handleKpiClick" />
        <StationTable />
        <HourlyCharging />
      </section>

      <!-- 中间：地图 -->
      <section class="col-center">
        <button class="panel-toggle toggle-left" @click="showLeftPanel = !showLeftPanel"
          :title="showLeftPanel ? '收起左侧' : '展开左侧'">
          {{ showLeftPanel ? '◀' : '▶' }}
        </button>
        <ChinaMap ref="mapRef" />
        <button class="panel-toggle toggle-right" @click="showRightPanel = !showRightPanel"
          :title="showRightPanel ? '收起右侧' : '展开右侧'">
          {{ showRightPanel ? '▶' : '◀' }}
        </button>
      </section>

      <!-- 右列：业务运营 -->
      <section class="col-right" v-show="showRightPanel">
        <OrderKpi />
        <RevenueTrend />
        <ChannelProgress />
        <HotRanking />
      </section>
    </main>
    <canvas ref="particleCanvas" class="particle-canvas"></canvas>
    <OperatorPanel :visible="showOperators" :mode="opMode" @close="showOperators = false" />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import KpiCards from './components/KpiCards.vue'
import StationTable from './components/StationTable.vue'
import HourlyCharging from './components/HourlyCharging.vue'
import AlertTicker from './components/AlertTicker.vue'
import ChinaMap from './components/ChinaMap.vue'
import OrderKpi from './components/OrderKpi.vue'
import RevenueTrend from './components/RevenueTrend.vue'
import ChannelProgress from './components/ChannelProgress.vue'
import HotRanking from './components/HotRanking.vue'
import OperatorPanel from './components/OperatorPanel.vue'
import AdminLogin from './components/AdminLogin.vue'
import logoUrl from '@/assets/app_icon.png'

// ── 路由集成 ──
const route = useRoute()
const router = useRouter()

// 当前是否在管理后台路由下（/admin/*）
const isAdminRoute = computed(() => route.path.startsWith('/admin'))

function goToAdmin() {
  router.push('/admin/dashboard')
}

const loggedIn = ref(!!localStorage.getItem('admin_token'))
const adminUser = ref({
  username: localStorage.getItem('admin_user') || '',
  role: localStorage.getItem('admin_role') || 'admin',
  nickname: '',
})

// 普通管理员不能访问数据大屏，自动重定向到管理后台
watch([isAdminRoute, loggedIn], ([admin, logged]) => {
  if (logged && !admin) {
    const role = localStorage.getItem('admin_role')
    if (role !== 'super_admin') {
      router.replace('/admin/dashboard')
    }
  }
}, { immediate: true })

// 当前用户是否为超级管理员（控制数据大屏顶部"管理后台"按钮显隐）
const isSuperAdmin = computed(() => localStorage.getItem('admin_role') === 'super_admin')

// 管理后台模式时切换 body / #app 主题（深色 → 浅色）
watch(isAdminRoute, (admin) => {
  const appEl = document.getElementById('app')
  if (admin) {
    document.body.style.background = '#f0f2f5'
    appEl?.classList.add('admin-mode')
  } else {
    document.body.style.background = ''
    appEl?.classList.remove('admin-mode')
  }
}, { immediate: true })
const currentTime = ref('')
const showOperators = ref(false)
const opMode = ref(0)
const mapRef = ref<InstanceType<typeof ChinaMap> | null>(null)
const showLeftPanel = ref(true)
const showRightPanel = ref(true)

function focusMapStation(stationId: string) {
  mapRef.value?.focusStation(stationId)
}

function handleKpiClick(index: number) {
  opMode.value = index
  showOperators.value = true
}
const particleCanvas = ref<HTMLCanvasElement | null>(null)

// ── 大屏自适应缩放：设计稿 1920×1080 ──
const viewW = ref(window.innerWidth)
const viewH = ref(window.innerHeight)
const scale = computed(() => Math.min(viewW.value / 1920, viewH.value / 1080))
const dashboardStyle = computed(() => ({
  transform: `translate(-50%, -50%) scale(${scale.value})`,
  width: '1920px',
  height: '1080px',
}))

function handleLogout() {
  localStorage.removeItem('admin_token')
  localStorage.removeItem('admin_user')
  localStorage.removeItem('admin_role')
  loggedIn.value = false
  router.push('/')
}

function onResize() {
  viewW.value = window.innerWidth
  viewH.value = window.innerHeight
}

let timer: ReturnType<typeof setInterval> | null = null

onMounted(() => {
  window.addEventListener('resize', onResize)
  const update = () => {
    const now = new Date()
    currentTime.value = now.toLocaleString('zh-CN', {
      year: 'numeric', month: '2-digit', day: '2-digit',
      hour: '2-digit', minute: '2-digit', second: '2-digit',
    })
  }
  update()
  timer = setInterval(update, 1000)

  // Particle canvas animation
  const canvas = particleCanvas.value
  if (canvas) {
    const ctx = canvas.getContext('2d', { willReadFrequently: true })
    if (ctx) {
      canvas.width = canvas.offsetWidth
      canvas.height = canvas.offsetHeight
      const w = canvas.width
      const h = canvas.height

      const particles: { x: number; y: number; r: number; vx: number; vy: number; alpha: number }[] = []
      for (let i = 0; i < 50; i++) {
        particles.push({
          x: Math.random() * w,
          y: Math.random() * h,
          r: Math.random() * 1.5 + 0.5,
          vx: (Math.random() - 0.5) * 0.3,
          vy: (Math.random() - 0.5) * 0.3,
          alpha: Math.random() * 0.4 + 0.1,
        })
      }

      function draw() {
        if (!ctx || !canvas) return
        ctx.clearRect(0, 0, canvas.width, canvas.height)
        particles.forEach(p => {
          p.x += p.vx
          p.y += p.vy
          if (p.x < 0) p.x = w
          if (p.x > w) p.x = 0
          if (p.y < 0) p.y = h
          if (p.y > h) p.y = 0
          ctx.beginPath()
          ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2)
          ctx.fillStyle = `rgba(0, 212, 255, ${p.alpha})`
          ctx.fill()
        })
        requestAnimationFrame(draw)
      }
      draw()
    }
  }
})

onUnmounted(() => {
  window.removeEventListener('resize', onResize)
  if (timer) clearInterval(timer)
})
</script>

<style scoped>
.dashboard {
  position: absolute;
  left: 50%;
  top: 50%;
  display: flex;
  flex-direction: column;
  padding: 12px 20px 16px;
}

/* ═══════════ 标题栏 ═══════════ */
.header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  height: 60px;
  padding: 0 12px;
  z-index: 2;
  position: relative;
}

.header-left {
  width: 30px;
  flex-shrink: 0;
  z-index: 1;
}

.logo-icon {
  width: 45px; height: 45px;
  filter: drop-shadow(0 0 8px rgba(0, 212, 255,0.4));
  color: #00d4ff;
}

/* 标题居中：相对父容器绝对定位，无论左右内容宽度如何变化都始终居中 */
.header-center {
  position: absolute;
  left: 50%;
  transform: translateX(-50%);
  text-align: center;
  pointer-events: none;
  z-index: 0;
}

.title {
  font-size: 24px;
  font-weight: 700;
  background: linear-gradient(90deg, #00d4ff, #818cf8, #22d3ee);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
  letter-spacing: 0.06em;
  white-space: nowrap;
}

.subtitle {
  font-size: 10px;
  color: var(--text-dim);
  letter-spacing: 0.15em;
  text-transform: uppercase;
}

.header-right {
  display: flex;
  align-items: center;
  gap: 12px;
  z-index: 1;
}

.op-btn {
  border: 1px solid var(--border-subtle);
  background: rgba(0, 212, 255, 0.06);
  color: var(--text-accent);
  font-size: 12px; font-family: var(--font-sans);
  padding: 4px 14px;
  border-radius: var(--radius-sm);
  cursor: pointer;
  transition: all 0.2s;
}
.op-btn:hover {
  border-color: var(--border-glow);
  background: rgba(0, 212, 255, 0.12);
}
.logout-btn {
  background: rgba(239, 68, 68, 0.06);
  border-color: rgba(239, 68, 68, 0.2);
  color: #f87171;
}
.logout-btn:hover {
  background: rgba(239, 68, 68, 0.15);
  border-color: #f87171;
}

.time {
  font-size: 11px;
  color: var(--text-dim);
  font-family: var(--font-mono);
}

/* ═══════════ 主体三列 ═══════════ */
.main-grid {
  flex: 1;
  display: flex;
  gap: 14px;
  min-height: 0;
  z-index: 2;
}

.col-left {
  width: 22%;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.col-left > :nth-child(1) { height: 160px; }
.col-left > :nth-child(2) { flex: 1; min-height: 0; }
.col-left > :nth-child(3) { height: 160px; }

.col-center {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-width: 0;
  position: relative;
}

/* ── 左右面板折叠按钮 ── */
.panel-toggle {
  position: absolute;
  top: 50%;
  transform: translateY(-50%);
  z-index: 10;
  background: rgba(0, 212, 255, 0.08);
  border: 1px solid var(--border-subtle);
  color: var(--text-accent);
  cursor: pointer;
  width: 20px;
  height: 48px;
  border-radius: 4px;
  font-size: 10px;
  padding: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: background 0.2s, border-color 0.2s;
  backdrop-filter: blur(4px);
}
.panel-toggle:hover {
  background: rgba(0, 212, 255, 0.18);
  border-color: var(--border-glow);
}
.toggle-left  { left: 0;  border-radius: 0 4px 4px 0; }
.toggle-right { right: 0; border-radius: 4px 0 0 4px; }

.col-right {
  width: 23%;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.col-right > :nth-child(1) { height: 78px; flex-shrink: 0; }
.col-right > :nth-child(2) { flex: 5; min-height: 0; }
.col-right > :nth-child(3) { height: 120px; flex-shrink: 0; }
.col-right > :nth-child(4) { flex: 4; min-height: 0; }

.particle-canvas {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  pointer-events: none;
  z-index: 0;
}
</style>
