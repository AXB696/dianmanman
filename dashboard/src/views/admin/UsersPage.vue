<template>
  <div class="page">
    <h1 class="page-title">用户管理</h1>

    <!-- ═══ 搜索栏 ═══ -->
    <div class="toolbar">
      <input v-model="searchUser" placeholder="搜索用户名..." class="search-input" @keydown.enter="search" />
      <input v-model="searchPhone" placeholder="搜索手机号..." class="search-input" @keydown.enter="search" />
      <button class="btn btn-primary" @click="search">搜索</button>
      <button class="btn" @click="refresh" title="刷新">🔄</button>
    </div>

    <!-- ═══ 加载中 ═══ -->
    <p v-if="loading" class="hint">加载中...</p>

    <!-- ═══ 用户表格 ═══ -->
    <div v-else class="table-wrap">
      <table class="table">
        <thead>
          <tr>
            <th style="width:50px">ID</th>
            <th>用户名</th>
            <th>昵称</th>
            <th>手机号</th>
            <th>角色</th>
            <th>注册时间</th>
            <th style="width:60px">车辆数</th>
            <th style="width:80px">操作</th>
          </tr>
        </thead>
        <tbody>
          <template v-for="u in users" :key="u.id">
            <!-- 用户行 -->
            <tr :class="{ 'row-expanded': expandedId === u.id }" @click="toggleExpand(u)">
              <td>{{ u.id }}</td>
              <td class="bold">{{ u.username }}</td>
              <td>{{ u.nickname || '-' }}</td>
              <td>{{ u.phone || '-' }}</td>
              <td><span :class="roleClass(u.role)">{{ roleLabel(u.role) }}</span></td>
              <td class="date-cell">{{ fmtDate(u.created_at) }}</td>
              <td class="center">
                <span v-if="expandedId === u.id && vehiclesLoading" class="loading-dots">···</span>
                <span v-else-if="expandedId === u.id && expandedVehicles !== null" class="vehicle-count">{{ expandedVehicles.length }}</span>
                <span v-else class="vehicle-count dim">-</span>
              </td>
              <td class="center" @click.stop>
                <button
                  class="btn btn-sm btn-danger"
                  @click="confirmDelete(u)"
                  :disabled="u.role === 'super_admin'"
                >删除</button>
              </td>
            </tr>
            <!-- 展开详情 -->
            <tr v-if="expandedId === u.id" class="detail-row">
              <td colspan="8">
                <div class="detail-panel">
                  <div class="detail-cols">
                    <!-- 基本信息 -->
                    <div class="detail-card">
                      <h3 class="detail-card-title">👤 {{ u.username }} 的详情信息</h3>
                      <div class="info-grid">
                        <div class="info-item"><span class="info-label">ID</span><span>{{ u.id }}</span></div>
                        <div class="info-item"><span class="info-label">用户名</span><span>{{ u.username }}</span></div>
                        <div class="info-item"><span class="info-label">昵称</span><span>{{ u.nickname || '-' }}</span></div>
                        <div class="info-item"><span class="info-label">手机号</span><span>{{ u.phone || '-' }}</span></div>
                        <div class="info-item"><span class="info-label">角色</span><span :class="roleClass(u.role)">{{ roleLabel(u.role) }}</span></div>
                        <div class="info-item"><span class="info-label">注册时间</span><span>{{ fmtFullDate(u.created_at) }}</span></div>
                      </div>
                    </div>
                    <!-- 车辆列表 -->
                    <div class="detail-card">
                      <h3 class="detail-card-title">🚗 车辆列表</h3>
                      <div v-if="vehiclesLoading" class="hint">加载中...</div>
                      <div v-else-if="vehiclesError" class="hint" style="color:#ef4444">{{ vehiclesError }}</div>
                      <div v-else-if="expandedVehicles && expandedVehicles.length === 0" class="hint">暂无车辆</div>
                      <div v-else class="vehicle-list">
                        <div v-for="v in expandedVehicles" :key="v.id" class="vehicle-item">
                          <span class="v-icon">{{ v.is_default ? '🚙' : '🚗' }}</span>
                          <span class="v-name">{{ v.brand }} {{ v.model }}</span>
                          <span v-if="v.is_default" class="v-default-tag">默认</span>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </td>
            </tr>
          </template>
          <!-- 空数据 -->
          <tr v-if="users.length === 0">
            <td colspan="8" class="empty-hint">暂无用户数据</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- ═══ 分页 ═══ -->
    <Pagination
      v-if="total > 0"
      :currentPage="page"
      :totalPages="totalPages"
      :total="total"
      @change="goPage"
    />

    <p v-if="error" class="error-msg">{{ error }}</p>

    <!-- ═══ 删除确认弹窗 ═══ -->
    <div v-if="deleteTarget" class="modal-overlay" @click.self="deleteTarget = null">
      <div class="modal">
        <p>确定删除用户 <b>{{ deleteTarget.username }}</b> ？该操作不可恢复！</p>
        <div class="modal-actions">
          <button class="btn" @click="deleteTarget = null">取消</button>
          <button class="btn btn-danger" @click="doDelete">确认删除</button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue'
import { getUsers, deleteUser, getUserVehicles } from '@/api/admin'
import Pagination from '@/components/Pagination.vue'

// ═══════ 数据 ═══════
const users = ref<any[]>([])
const total = ref(0)
const offset = ref(0)
const limit = 20
const searchUser = ref('')
const searchPhone = ref('')
const error = ref('')
const loading = ref(true)

// ═══════ 展开详情 ═══════
const expandedId = ref<number | null>(null)
const expandedVehicles = ref<any[] | null>(null)
const vehiclesLoading = ref(false)
const vehiclesError = ref('')

// ═══════ 删除 ═══════
const deleteTarget = ref<any>(null)

// ═══════ 分页 ═══════
const totalPages = computed(() => Math.max(1, Math.ceil(total.value / limit)))
const page = computed(() => Math.floor(offset.value / limit))

// ═══════ 工具函数 ═══════
function fmtDate(d: string) { return d ? new Date(d).toLocaleDateString('zh-CN') : '-' }
function fmtFullDate(d: string) { return d ? new Date(d).toLocaleString('zh-CN') : '-' }

function roleClass(r: string) {
  if (r === 'super_admin') return 'tag tag-red'
  if (r === 'admin') return 'tag tag-orange'
  return 'tag tag-blue'
}
function roleLabel(r: string) {
  if (r === 'super_admin') return '超级管理员'
  if (r === 'admin') return '管理员'
  return '用户'
}

// ═══════ 数据加载 ═══════
async function fetchUsers() {
  loading.value = true
  error.value = ''
  try {
    const params: any = { offset: offset.value, limit }
    if (searchUser.value) params.username = searchUser.value
    if (searchPhone.value) params.phone = searchPhone.value
    const data: any = await getUsers(params)
    users.value = data.users || data.data?.users || []
    total.value = data.total || data.data?.total || 0
  } catch (e: any) {
    error.value = '加载失败: ' + (e?.message || e)
  } finally {
    loading.value = false
  }
}

function search() { goPage(0) }
function refresh() { expandedId.value = null; fetchUsers() }
function goPage(p: number) { offset.value = Math.max(0, p) * limit; expandedId.value = null; fetchUsers() }

// ═══════ 展开 / 收起 ═══════
async function toggleExpand(u: any) {
  if (expandedId.value === u.id) {
    // 收起
    expandedId.value = null
    expandedVehicles.value = null
    vehiclesError.value = ''
    return
  }
  // 展开
  expandedId.value = u.id
  expandedVehicles.value = null
  vehiclesLoading.value = true
  vehiclesError.value = ''
  try {
    const data: any = await getUserVehicles(u.id)
    expandedVehicles.value = Array.isArray(data) ? data : (data.vehicles || data.data?.vehicles || [])
  } catch (e: any) {
    vehiclesError.value = '加载车辆失败'
  } finally {
    vehiclesLoading.value = false
  }
}

// ═══════ 删除 ═══════
function confirmDelete(u: any) { deleteTarget.value = u }
async function doDelete() {
  if (!deleteTarget.value) return
  try {
    await deleteUser(deleteTarget.value.id)
    deleteTarget.value = null
    if (expandedId.value === deleteTarget.value.id) {
      expandedId.value = null
      expandedVehicles.value = null
    }
    await fetchUsers()
  } catch (e: any) {
    error.value = '删除失败: ' + (e?.message || e)
  }
}

// ═══════ 首次加载 ═══════
fetchUsers()
</script>

<style scoped>
.page { padding: 32px; }
.page-title { margin: 0 0 20px; font-size: 20px; color: #1a1a2e; }
.hint { color: #94a3b8; font-size: 13px; }

/* ── 搜索栏 ── */
.toolbar { display: flex; gap: 10px; margin-bottom: 16px; align-items: center; }
.search-input { padding: 8px 14px; border: 1px solid #e2e8f0; border-radius: 8px; font-size: 13px; outline: none; width: 180px; }
.search-input:focus { border-color: #1a56db; }

/* ── 表格 ── */
.table-wrap { background: #fff; border-radius: 12px; overflow: auto; box-shadow: 0 1px 8px rgba(0,0,0,0.04); }
.table { width: 100%; border-collapse: collapse; font-size: 13px; }
.table th { text-align: left; padding: 14px 12px; background: #f8fafc; color: #64748b; font-weight: 600; border-bottom: 1px solid #e2e8f0; white-space: nowrap; }
.table td { padding: 12px; border-bottom: 1px solid #f1f5f9; color: #334155; vertical-align: middle; }
.table tr:not(.detail-row) { cursor: pointer; transition: background 0.12s; }
.table tr:not(.detail-row):hover td { background: #f0f7ff; }
.table tr.row-expanded:not(.detail-row) td { background: #eff6ff; }
.bold { font-weight: 600; }
.date-cell { font-size: 12px; white-space: nowrap; }
.center { text-align: center; }
.vehicle-count { font-weight: 600; color: #1a56db; font-size: 13px; }
.vehicle-count.dim { color: #94a3b8; font-weight: 400; }
.loading-dots { color: #94a3b8; animation: blink 1s infinite; }
.empty-hint { text-align: center; padding: 40px 0; color: #94a3b8; }

/* ── 展开详情 ── */
.detail-row td { padding: 0; background: #f8faff; border-bottom: 2px solid #e2e8f0; }
.detail-panel { padding: 16px 20px; }
.detail-cols { display: flex; gap: 20px; }
.detail-card { flex: 1; background: #fff; border-radius: 10px; padding: 16px; border: 1px solid #e8edf3; min-width: 0; }
.detail-card-title { font-size: 13px; font-weight: 600; color: #1a1a2e; margin: 0 0 12px; }
.info-grid { display: flex; flex-direction: column; gap: 6px; }
.info-item { display: flex; gap: 8px; font-size: 12px; align-items: baseline; }
.info-label { color: #94a3b8; min-width: 56px; flex-shrink: 0; }

/* ── 车辆列表 ── */
.vehicle-list { display: flex; flex-direction: column; gap: 6px; }
.vehicle-item { display: flex; align-items: center; gap: 8px; font-size: 12px; padding: 6px 8px; border-radius: 6px; background: #f8fafc; }
.v-icon { font-size: 14px; }
.v-name { color: #334155; }
.v-default-tag { font-size: 10px; padding: 1px 6px; border-radius: 4px; background: #eff6ff; color: #1a56db; margin-left: auto; }

/* ── 通用组件 ── */
.btn { padding: 8px 16px; border: 1px solid #e2e8f0; border-radius: 8px; background: #fff; cursor: pointer; font-size: 13px; transition: all 0.15s; }
.btn:hover { border-color: #94a3b8; }
.btn-primary { background: #1a56db; color: #fff; border-color: #1a56db; }
.btn-primary:hover { background: #1e40af; }
.btn-danger { color: #ef4444; border-color: #fca5a5; }
.btn-danger:hover:not(:disabled) { background: #fef2f2; }
.btn-danger:disabled { opacity: 0.4; cursor: not-allowed; }
.btn-sm { padding: 4px 10px; font-size: 12px; }

.tag { font-size: 11px; padding: 2px 8px; border-radius: 10px; font-weight: 500; white-space: nowrap; }
.tag-red { background: #fef2f2; color: #dc2626; }
.tag-orange { background: #fff7ed; color: #ea580c; }
.tag-blue { background: #eff6ff; color: #2563eb; }

.error-msg { color: #ef4444; font-size: 13px; margin-top: 12px; }

/* ── 弹窗 ── */
.modal-overlay { position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.3); display: flex; align-items: center; justify-content: center; z-index: 999; }
.modal { background: #fff; border-radius: 12px; padding: 24px; width: 380px; }
.modal p { margin: 0 0 16px; font-size: 14px; }
.modal-actions { display: flex; justify-content: flex-end; gap: 10px; }

@keyframes blink { 0%, 100% { opacity: 1; } 50% { opacity: 0.3; } }
</style>
