<template>
  <div class="page">
    <div class="page-header">
      <div>
        <h1 class="page-title">站内公告</h1>
        <p class="page-desc">管理 App 端公告，支持草稿保存和弹窗推送。发布后 App 端实时生效。</p>
      </div>
      <button class="btn btn-primary" @click="openEditor()">+ 新增公告</button>
    </div>

    <!-- ═══ 表格 ═══ -->
    <div class="table-wrap"><table class="table">
      <thead><tr>
        <th style="width:44px">ID</th>
        <th>标题</th>
        <th>内容</th>
        <th style="width:90px">状态</th>
        <th style="width:110px">弹窗截止</th>
        <th style="width:100px">更新时间</th>
        <th style="width:100px">操作</th>
      </tr></thead>
      <tbody>
        <template v-for="a in list" :key="a.id">
          <tr :class="{ 'row-draft': a.status === 'draft' }" @click="toggleExpand(a)">
            <td class="mono">{{ a.id }}</td>
            <td class="bold">{{ a.title }}</td>
            <td class="cell-content">{{ a.content || '-' }}</td>
            <td>
              <span class="tag" :class="statusClass(a)">
                <span class="status-dot"></span>{{ statusText(a) }}
              </span>
            </td>
            <td class="date-cell mono">
              <template v-if="a.display_until">
                <span :class="{ 'text-danger': isExpired(a.display_until), 'text-accent': !isExpired(a.display_until) }">
                  {{ fmtDate(a.display_until) }}
                </span>
              </template>
              <span v-else class="text-dim">—</span>
            </td>
            <td class="date-cell">{{ fmtDate(a.updated_at || a.created_at) }}</td>
            <td class="actions" @click.stop>
              <button class="btn btn-sm" @click="openEditor(a)">编辑</button>
              <button class="btn btn-sm btn-danger" @click="confirmDel(a)">删除</button>
            </td>
          </tr>
          <!-- 展开预览 -->
          <tr v-if="expandedId === a.id" class="detail-row">
            <td colspan="7">
              <div class="detail-panel">
                <div class="detail-cols">
                  <!-- 公告详情 -->
                  <div class="detail-card">
                    <h3 class="detail-card-title">{{ a.title }}</h3>
                    <p class="detail-content">{{ a.content }}</p>
                    <div class="detail-meta">
                      <span>状态：<span :class="statusClass(a)">{{ statusText(a) }}</span></span>
                      <span v-if="a.display_until">
                        弹窗截止：<span :class="isExpired(a.display_until) ? 'text-danger' : 'text-accent'">{{ fmtFullDate(a.display_until) }}</span>
                        <span v-if="isExpired(a.display_until)" class="expired-tag">已过期</span>
                        <span v-else class="active-tag">弹窗中</span>
                      </span>
                      <span v-else>弹窗截止：未启用（仅滚动展示）</span>
                    </div>
                  </div>
                  <!-- App 预览 -->
                  <div class="detail-card preview-card">
                    <h3 class="detail-card-title">📱 App 端预览</h3>
                    <div class="phone-mock">
                      <div class="phone-header">
                        <span class="phone-title">电满满</span>
                      </div>
                      <div v-if="a.status === 'published'" class="phone-body">
                        <div class="phone-announce">
                          <div class="phone-announce-title">📢 {{ a.title }}</div>
                          <div class="phone-announce-text">{{ a.content }}</div>
                        </div>
                      </div>
                      <div v-else class="phone-body phone-empty">
                        草稿状态，App 端不可见
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </td>
          </tr>
        </template>
        <tr v-if="list.length === 0">
          <td colspan="7" class="empty-hint">暂无公告，点击右上角"新增公告"创建</td>
        </tr>
      </tbody>
    </table></div>

    <Pagination
      :currentPage="page"
      :totalPages="totalPages"
      :total="total"
      @change="goPage"
    />

    <p v-if="error" class="error-msg">{{ error }}</p>

    <!-- ═══ 编辑弹窗 ═══ -->
    <div v-if="editor" class="modal-overlay" @click.self="editor=null"><div class="modal">
      <h3>{{ editor.id ? '编辑公告' : '新增公告' }}</h3>
      <div class="field">
        <label>标题 <span class="char-hint">{{ form.title.length }}/50</span></label>
        <input v-model="form.title" class="input" maxlength="50" placeholder="输入公告标题" />
      </div>
      <div class="field">
        <label>内容 <span class="char-hint">{{ form.content.length }}/500</span></label>
        <textarea v-model="form.content" class="input textarea" maxlength="500" rows="4" placeholder="输入公告正文，支持纯文本"></textarea>
      </div>
      <div class="field">
        <label>状态</label>
        <div class="radio-group">
          <label class="radio-item" :class="{ active: form.status === 'draft' }">
            <input type="radio" v-model="form.status" value="draft" />
            <span class="radio-label">📝 草稿</span>
            <span class="radio-desc">仅管理员可见</span>
          </label>
          <label class="radio-item" :class="{ active: form.status === 'published' }">
            <input type="radio" v-model="form.status" value="published" />
            <span class="radio-label">📢 发布</span>
            <span class="radio-desc">App 端立即可见</span>
          </label>
        </div>
      </div>
      <div class="field" v-if="form.status === 'published'">
        <label>弹窗截止时间 <span class="char-hint">（选填，设置后 App 首页弹窗展示）</span></label>
        <input type="datetime-local" v-model="form.display_until" class="input" />
      </div>
      <p v-if="formError" class="error-msg">{{ formError }}</p>
      <div class="modal-actions">
        <button class="btn" @click="editor=null">取消</button>
        <button v-if="editor.id && form.status === 'draft'" class="btn btn-ghost" @click="saveDraft">存为草稿</button>
        <button class="btn btn-primary" @click="submitEditor">{{ editor.id ? (form.status === 'published' ? '发布更新' : '保存') : (form.status === 'published' ? '立即发布' : '保存草稿') }}</button>
      </div>
    </div></div>

    <!-- ═══ 删除确认 ═══ -->
    <div v-if="delTarget" class="modal-overlay" @click.self="delTarget=null"><div class="modal modal-sm">
      <p>确定删除公告 <b>{{ delTarget.title }}</b>？<br><span class="text-dim">删除后 App 端同步消失，不可恢复。</span></p>
      <div class="modal-actions"><button class="btn" @click="delTarget=null">取消</button><button class="btn btn-danger" @click="doDelete">确认删除</button></div>
    </div></div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from "vue"
import { getAnnouncements, createAnnouncement, updateAnnouncement, deleteAnnouncement } from "@/api/admin"
import Pagination from "@/components/Pagination.vue"
const list=ref<any[]>([]); const offset=ref(0); const limit=20; const total=ref(0); const error=ref(""); const editor=ref<any>(null)
const form=ref({title:"",content:"",status:"draft",display_until:""}); const formError=ref(""); const delTarget=ref<any>(null)

// 展开预览
const expandedId = ref<number | null>(null)

// 分页
const page = computed(() => Math.floor(offset.value / limit))
const totalPages = computed(() => Math.max(1, Math.ceil(total.value / limit)))

// 状态计算
function isExpired(d: string) { return d ? new Date(d) < new Date() : false }

function statusClass(a: any) {
  if (a.status === 'draft') return 'tag-gray'
  if (a.display_until && !isExpired(a.display_until)) return 'tag-popup'
  return 'tag-green'
}
function statusText(a: any) {
  if (a.status === 'draft') return '草稿'
  if (a.display_until && !isExpired(a.display_until)) return '弹窗中'
  return '已发布'
}

function fmtDate(d:string){return d?new Date(d).toLocaleDateString("zh-CN"):"-"}
function fmtFullDate(d:string){return d?new Date(d).toLocaleString("zh-CN"):"-"}

function toggleExpand(a: any) { expandedId.value = expandedId.value === a.id ? null : a.id }

async function fetch(){try{const data:any=await getAnnouncements({offset:offset.value,limit});list.value=data.announcements||data.data?.announcements||[];total.value=data.total||0}catch(e:any){}}
function goPage(p: number) { offset.value = Math.max(0, p) * limit; fetch() }

function openEditor(a?:any){
  form.value=a?{title:a.title,content:a.content,status:a.status,display_until:a.display_until?toLocalDatetime(a.display_until):""}
    :{title:"",content:"",status:"draft",display_until:""}
  formError.value="";editor.value=a||{}
}
function toLocalDatetime(iso: string) {
  // ISO → datetime-local 格式
  const d = new Date(iso)
  const pad = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${pad(d.getMonth()+1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`
}
function confirmDel(a:any){delTarget.value=a}

async function submitEditor(){
  formError.value=""
  if(!form.value.title){formError.value="请输入标题";return}
  if(!form.value.content){formError.value="请输入内容";return}
  const payload: any = {
    title: form.value.title,
    content: form.value.content,
    status: form.value.status,
  }
  // 已发布时如果填了弹窗截止时间，转为 ISO 格式
  if (form.value.status === 'published' && form.value.display_until) {
    payload.display_until = new Date(form.value.display_until).toISOString()
  } else if (form.value.status === 'draft') {
    payload.display_until = null
  }
  try{
    if(editor.value.id){await updateAnnouncement(editor.value.id,payload)}else{await createAnnouncement(payload)}
    editor.value=null;expandedId.value=null;await fetch()
  }catch(e:any){formError.value=e?.response?.data?.detail||"操作失败"}
}
function saveDraft(){form.value.status="draft";submitEditor()}
async function doDelete(){if(!delTarget.value)return;try{await deleteAnnouncement(delTarget.value.id);delTarget.value=null;expandedId.value=null;await fetch()}catch(e:any){}}
onMounted(fetch)
</script>

<style scoped>
.page{padding:32px}
.page-header{display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:20px}
.page-title{margin:0;font-size:20px;color:#1a1a2e}
.page-desc{margin:4px 0 0;font-size:12px;color:#94a3b8}

/* ── 表格 ── */
.table-wrap{background:#fff;border-radius:12px;overflow:auto;box-shadow:0 1px 8px rgba(0,0,0,0.04)}
.table{width:100%;border-collapse:collapse;font-size:13px}
.table th{text-align:left;padding:14px 12px;background:#f8fafc;color:#64748b;font-weight:600;border-bottom:1px solid #e2e8f0;white-space:nowrap}
.table td{padding:10px 12px;border-bottom:1px solid #f1f5f9;color:#334155;vertical-align:middle}
.table tr:not(.detail-row){cursor:pointer;transition:background .12s}
.table tr:not(.detail-row):hover td{background:#f0f7ff}
.row-draft td{color:#94a3b8}
.row-draft:hover td{background:#f8fafc}
.bold{font-weight:600}
.mono{font-family:"JetBrains Mono",monospace;font-size:11px}
.cell-content{max-width:200px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.date-cell{font-size:12px;white-space:nowrap}
.actions{display:flex;gap:6px;justify-content:flex-end}
.empty-hint{text-align:center;padding:40px 0;color:#94a3b8}

/* ── 状态标签 ── */
.tag{font-size:11px;padding:2px 8px;border-radius:10px;font-weight:500;white-space:nowrap;display:inline-flex;align-items:center;gap:4px}
.tag-green{background:#ecfdf5;color:#059669}
.tag-gray{background:#f1f5f9;color:#64748b}
.tag-popup{background:#fef3c7;color:#d97706}
.status-dot{width:5px;height:5px;border-radius:50%}
.tag-green .status-dot{background:#10b981}
.tag-gray .status-dot{background:#94a3b8}
.tag-popup .status-dot{background:#f59e0b}

/* ── 文字色 ── */
.text-dim{color:#94a3b8;font-size:12px}
.text-danger{color:#ef4444}
.text-accent{color:#059669;font-weight:600}
.expired-tag{font-size:10px;padding:1px 5px;border-radius:4px;background:#fef2f2;color:#ef4444;margin-left:4px}
.active-tag{font-size:10px;padding:1px 5px;border-radius:4px;background:#fef3c7;color:#d97706;margin-left:4px}

/* ── 展开详情 ── */
.detail-row td{padding:0;background:#f8faff;border-bottom:2px solid #e2e8f0}
.detail-panel{padding:16px 20px}
.detail-cols{display:flex;gap:20px}
.detail-card{flex:1;background:#fff;border-radius:10px;padding:16px;border:1px solid #e8edf3;min-width:0}
.detail-card-title{font-size:14px;font-weight:600;color:#1a1a2e;margin:0 0 12px}
.detail-content{font-size:13px;color:#475569;line-height:1.7;white-space:pre-wrap;margin:0}
.detail-meta{display:flex;flex-direction:column;gap:4px;margin-top:12px;padding-top:12px;border-top:1px solid #f1f5f9;font-size:12px;color:#64748b}

/* ── App 预览卡片 ── */
.preview-card{max-width:240px;flex-shrink:0}
.phone-mock{border:2px solid #1a1a2e;border-radius:16px;overflow:hidden;font-size:11px}
.phone-header{background:#1a56db;color:#fff;text-align:center;padding:6px;font-weight:600;font-size:12px}
.phone-body{background:#f8fafc;padding:10px;min-height:60px}
.phone-empty{display:flex;align-items:center;justify-content:center;color:#94a3b8;font-size:11px}
.phone-announce{background:#fff;border-radius:8px;padding:10px;border:1px solid #e2e8f0}
.phone-announce-title{font-weight:600;color:#1a1a2e;margin-bottom:4px;font-size:12px}
.phone-announce-text{color:#64748b;line-height:1.5;font-size:11px;white-space:pre-wrap}

/* ── 编辑弹窗 ── */
.modal-overlay{position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.3);display:flex;align-items:center;justify-content:center;z-index:999}
.modal{background:#fff;border-radius:12px;padding:28px;width:520px;max-height:85vh;overflow-y:auto}
.modal-sm{width:400px}
.modal h3{margin:0 0 20px;font-size:16px;color:#1a1a2e}
.modal p{margin:0 0 16px;font-size:14px}
.modal-actions{display:flex;justify-content:flex-end;gap:10px;margin-top:20px}
.field{margin-bottom:16px}
.field label{display:block;font-size:12px;color:#475569;margin-bottom:4px;font-weight:500}
.char-hint{font-weight:400;color:#94a3b8}
.input{width:100%;padding:8px 12px;border:1px solid #e2e8f0;border-radius:8px;font-size:13px;outline:none;box-sizing:border-box;color:#334155;transition:border-color .15s;height:38px;line-height:1.4;font-family:inherit}
.input:focus{border-color:#1a56db;box-shadow:0 0 0 3px rgba(26,86,219,.08)}
.textarea{resize:none;font-family:inherit;height:auto;min-height:80px}

/* ── 状态单选组 ── */
.radio-group{display:flex;gap:10px}
.radio-item{flex:1;border:1px solid #e2e8f0;border-radius:8px;padding:12px;cursor:pointer;transition:all .15s;display:flex;flex-direction:column;align-items:center;gap:4px}
.radio-item:not(.active):hover{border-color:#94a3b8;background:#f8fafc}
.radio-item.active{border-color:#1a56db;background:#eff6ff}
.radio-item input{display:none}
.radio-label{font-size:13px;font-weight:600;color:#1a1a2e}
.radio-desc{font-size:11px;color:#94a3b8}
.radio-item.active .radio-desc{color:#1a56db}

/* ── 通用 ── */
.btn{padding:8px 16px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;cursor:pointer;font-size:13px;transition:all .15s;font-family:inherit}
.btn:hover{border-color:#94a3b8}
.btn-primary{background:#1a56db;color:#fff;border-color:#1a56db}
.btn-primary:hover{background:#1e40af}
.btn-danger{color:#ef4444;border-color:#fca5a5}
.btn-danger:hover{background:#fef2f2}
.btn-ghost{color:#64748b;border-color:transparent}
.btn-ghost:hover{color:#475569;background:#f1f5f9;border-color:#e2e8f0}
.btn-sm{padding:4px 10px;font-size:12px}
.error-msg{color:#ef4444;font-size:13px;margin-top:12px}
</style>
