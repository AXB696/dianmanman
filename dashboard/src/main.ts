import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import './assets/styles/variables.css'

// 注册 vue-router，使管理后台页面支持浏览器 URL 导航
createApp(App).use(router).mount('#app')
