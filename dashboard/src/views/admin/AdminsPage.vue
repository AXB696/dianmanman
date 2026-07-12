<template>
  <div class="page">
    <div class="page-header"><h1 class="page-title">管理员账号</h1><button class="btn btn-primary" @click="openCreate">+ 新增管理员</button></div>
    <div class="table-wrap"><table class="table">
      <thead><tr><th>ID</th><th>用户名</th><th>昵称</th><th>手机号</th><th>角色</th><th>创建时间</th><th>操作</th></tr></thead>
      <tbody><tr v-for="a in admins" :key="a.id">
        <td>{{ a.id }}</td><td>{{ a.username }}</td><td>{{ a.nickname || '-' }}</td><td>{{ a.phone || '-' }}</td>
        <td><span class="tag" :class="a.role==='super_admin'?'tag-red':'tag-orange'">{{ a.role==='super_admin'?'超级管理员':'管理员' }}</span></td>
        <td>{{ fmtDate(a.created_at) }}</td>
        <td class="actions"><button class="btn btn-sm" @click="openPwd(a)">改密</button>
        <button class="btn btn-sm btn-danger" @click="confirmDel(a)">删除</button></td></tr></tbody></table></div>
    <p v-if="error" class="error-msg">{{ error }}</p>
    <div v-if="dialog" class="modal-overlay" @click.self="dialog=null"><div class="modal">
      <h3>{{ dialog.type==='create'?'新增管理员':'修改密码 - '+dialog.target?.username }}</h3>
      <div class="field" v-if="dialog.type==='create'"><label>用户名</label><input v-model="form.username" class="input" /></div>
      <div class="field" v-if="dialog.type==='create'"><label>昵称</label><input v-model="form.nickname" class="input" /></div>
      <div class="field" v-if="dialog.type==='create'"><label>手机号</label><input v-model="form.phone" class="input" /></div>
      <div class="field" v-if="dialog.type==='create'"><label>角色</label><select v-model="form.role" class="input"><option value="admin">管理员</option><option value="super_admin">超级管理员</option></select></div>
      <div class="field"><label>{{ dialog.type==='create'?'密码':'新密码' }}</label><input v-model="form.password" type="password" class="input" /></div>
      <div class="field" v-if="dialog.type==='create'"><label>确认密码</label><input v-model="form.password2" type="password" class="input" /></div>
      <p v-if="formError" class="error-msg">{{ formError }}</p>
      <div class="modal-actions"><button class="btn" @click="dialog=null">取消</button><button class="btn btn-primary" @click="submitDialog">{{ dialog.type==='create'?'创建':'保存' }}</button></div>
    </div></div>
    <div v-if="delTarget" class="modal-overlay" @click.self="delTarget=null"><div class="modal"><p>确定删除 <b>{{ delTarget.username }}</b>？</p>
      <div class="modal-actions"><button class="btn" @click="delTarget=null">取消</button><button class="btn btn-danger" @click="doDelete">删除</button></div></div></div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue'
import { getAdminUsers, createAdminUser, changePassword, deleteAdminUser } from '@/api/admin'
const admins = ref<any[]>([]); const error = ref(''); const selfId = ref(0)
const dialog = ref<any>(null); const formError = ref(''); const delTarget = ref<any>(null)
const form = ref({ username:'', nickname:'', phone:'', role:'admin', password:'', password2:'' })
function fmtDate(d: string) { return d ? new Date(d).toLocaleDateString('zh-CN') : '-' }
async function fetchAdmins() { try { const data: any = await getAdminUsers(); admins.value = data.users || data.data?.users || data.admins || [] } catch(e){} }
function openCreate() { form.value = { username:'', nickname:'', phone:'', role:'admin', password:'', password2:'' }; formError.value=''; dialog.value={type:'create'} }
function openPwd(a:any) { form.value = { username:'', nickname:'', phone:'', role:'admin', password:'', password2:'' }; formError.value=''; dialog.value={type:'pwd',target:a} }
function confirmDel(a:any) { delTarget.value=a }
async function submitDialog() { formError.value=''; if(!form.value.password) { formError.value='请输入密码'; return }
  if(dialog.value.type==='create') { if(!form.value.username) { formError.value='请输入用户名'; return }; if(form.value.password!==form.value.password2) { formError.value='两次密码不一致'; return }
    try{await createAdminUser({...form.value});dialog.value=null;await fetchAdmins()}catch(e:any){formError.value=e?.response?.data?.detail||'创建失败'} }
  else { try{await changePassword(dialog.value.target.id,form.value.password);dialog.value=null}catch(e:any){formError.value=e?.response?.data?.detail||'修改失败'} } }
async function doDelete() { if(!delTarget.value) return; try{await deleteAdminUser(delTarget.value.id);delTarget.value=null;await fetchAdmins()}catch(e:any){error.value='删除失败'} }
onMounted(fetchAdmins)
</script>

<style scoped>
.page{padding:32px}.page-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:20px}.page-title{margin:0;font-size:20px;color:#1a1a2e}
.table-wrap{background:#fff;border-radius:12px;overflow:auto;box-shadow:0 1px 8px rgba(0,0,0,0.04)}
.table{width:100%;border-collapse:collapse;font-size:13px}.table th{text-align:left;padding:14px 16px;background:#f8fafc;color:#64748b;font-weight:600;border-bottom:1px solid #e2e8f0}
.table td{padding:12px 16px;border-bottom:1px solid #f1f5f9;color:#334155}.actions{display:flex;gap:6px}
.tag{font-size:11px;padding:2px 8px;border-radius:10px;font-weight:500}.tag-red{background:#fef2f2;color:#dc2626}.tag-orange{background:#fff7ed;color:#ea580c}
.btn{padding:8px 16px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;cursor:pointer;font-size:13px}.btn-primary{background:#1a56db;color:#fff;border-color:#1a56db}.btn-danger{color:#ef4444;border-color:#fca5a5}.btn-sm{padding:4px 10px;font-size:12px}
.error-msg{color:#ef4444;font-size:13px;margin-top:12px}
.modal-overlay{position:fixed;top:0;left:0;width:100%;height:100%;background:rgba(0,0,0,0.3);display:flex;align-items:center;justify-content:center;z-index:999}
.modal{background:#fff;border-radius:12px;padding:24px;width:400px;max-height:80vh;overflow-y:auto}.modal h3{margin:0 0 16px;font-size:16px}.modal p{margin:0 0 16px;font-size:14px}.modal-actions{display:flex;justify-content:flex-end;gap:10px;margin-top:16px}
.field{margin-bottom:14px}.field label{display:block;font-size:12px;color:#64748b;margin-bottom:4px}
.input{width:100%;padding:8px 12px;border:1px solid #e2e8f0;border-radius:8px;font-size:13px;outline:none;box-sizing:border-box;color:#334155;transition:border-color .15s}.input:focus{border-color:#1a56db;box-shadow:0 0 0 3px rgba(26,86,219,.08)}
select.input{padding-right:32px;appearance:none;-webkit-appearance:none;cursor:pointer;background:#fff url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='12' viewBox='0 0 12 12'%3E%3Cpath d='M3 4.5l3 3 3-3' stroke='%2394a3b8' stroke-width='1.5' fill='none' stroke-linecap='round' stroke-linejoin='round'/%3E%3C/svg%3E") no-repeat right 10px center;height:38px}
select.input:hover{border-color:#94a3b8}
.input{height:38px;line-height:1.4;font-family:inherit}
textarea.input{height:auto;min-height:80px}
</style>