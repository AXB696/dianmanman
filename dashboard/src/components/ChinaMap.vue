<template>
  <div style="flex:1;display:flex;flex-direction:column;position:relative;margin-top:20px;overflow:hidden">
    <div ref="mapRef" style="flex:1;min-height:0"></div>
    <canvas ref="pulseCanvas" class="pulse-canvas"></canvas>
    <div v-if="loading" class="map-loading">地图加载中...</div>
    <div class="map-legend">
      <div class="legend-item"><span class="legend-dot" style="background:#00d4ff"></span>空闲</div>
      <div class="legend-item"><span class="legend-dot" style="background:#f59e0b"></span>紧张</div>
      <div class="legend-item"><span class="legend-dot" style="background:#ef4444"></span>满位</div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import { getStationStatus, type StationStatus } from '@/api/dashboard'

const AMAP_KEY = '6fd660d52feb9033da8f3c772cad03db'

const mapRef = ref<HTMLElement | null>(null)
const pulseCanvas = ref<HTMLCanvasElement | null>(null)
const loading = ref(true)
let map: any = null
let markers: any[] = []
let currentInfoWindow: any = null
const stationMap = new Map<string, any>()

// ── 脉冲动画相关 ──
interface PulseStation { lng: number; lat: number; status: 0 | 1 | 2; phase: number }
let pulseStations: PulseStation[] = []
let pulseRafId = 0
let pulseCtx: CanvasRenderingContext2D | null = null
const PULSE_COLORS: Record<number, string> = {
  0: '#00d4ff', // 空闲 — 蓝
  1: '#f59e0b', // 紧张 — 橙
  2: '#ef4444', // 满位 — 红
}

onMounted(async () => {
  if (!mapRef.value) return

  ;(window as any).__closeAMapInfoWindow = () => {
    if (currentInfoWindow) {
      currentInfoWindow.close()
      currentInfoWindow = null
    }
  }

  try {
    await loadAMap()
    initMap()
    await loadStations()
    startPulse()
  } catch (err: any) {
    console.error('[ChinaMap]', err.message || err)
  } finally {
    loading.value = false
  }
})

onUnmounted(() => {
  if (currentInfoWindow) { currentInfoWindow.close(); currentInfoWindow = null }
  delete (window as any).__closeAMapInfoWindow
  stopPulse()
  clearMarkers()
  if (map) { map.destroy(); map = null }
})

function loadAMap(): Promise<void> {
  return new Promise((resolve, reject) => {
    const win = window as any
    if (win.AMap && win.AMap.Map) { resolve(); return }
    const script = document.createElement('script')
    script.src = `https://webapi.amap.com/maps?v=2.0&key=${AMAP_KEY}&plugin=AMap.Scale,AMap.ToolBar,AMap.MassMarks`
    script.onload = () => { console.log('[ChinaMap] AMap 加载成功'); resolve() }
    script.onerror = () => reject(new Error('AMap 脚本加载失败'))
    document.head.appendChild(script)
  })
}

function initMap(): void {
  const AMap = (window as any).AMap
  if (!mapRef.value) return

  mapRef.value.innerHTML = ''

  map = new AMap.Map(mapRef.value, {
    zoom: 12,
    center: new AMap.LngLat(114.305, 30.593),
    viewMode: '2D',
    resizeEnable: true,
    dragEnable: true,
    zoomEnable: true,
    scrollWheel: true,
    mapStyle: 'amap://styles/darkblue',
  })

  map.addControl(new AMap.Scale())
  console.log('[ChinaMap] 地图初始化完成，中心：武汉')

  mapRef.value.addEventListener('mouseleave', () => {
    const container = map.getContainer()
    if (container) {
      container.dispatchEvent(new MouseEvent('mouseup', { bubbles: true }))
    }
  })

  // 地图移动/缩放时更新脉冲坐标
  map.on('moveend', syncPulsePositions)
  map.on('zoomend', syncPulsePositions)
}

async function loadStations(): Promise<void> {
  if (!map) return
  const AMap = (window as any).AMap
  if (!AMap) return

  try {
    const data = await getStationStatus()
    const stations = data.stations || []
    const massMarks: any[] = []
    const newPulseStations: PulseStation[] = []

    for (const s of stations) {
      if (!s.location || !s.location.lat) continue
      const avail = s.availability
      const rate = avail.total > 0 ? avail.available / avail.total : 1
      const status: 0 | 1 | 2 = rate > 0.5 ? 0 : rate > 0 ? 1 : 2

      massMarks.push({
        lnglat: new AMap.LngLat(s.location.lng, s.location.lat),
        name: s.name,
        id: s.station_id,
        style: status,  // 0=空闲蓝 1=紧张橙 2=满位红
      })

      newPulseStations.push({ lng: s.location.lng, lat: s.location.lat, status, phase: Math.random() * Math.PI * 2 })
      stationMap.set(s.station_id, s)
    }

    // 清除旧标记
    clearMarkers()

    // 海量点标记
    if (massMarks.length > 0) {
      const mass = new AMap.MassMarks(massMarks, {
        opacity: 0.85,
        zIndex: 111,
        cursor: 'pointer',
        style: [
          // style[0] — 空闲：蓝
          {
            url: 'data:image/svg+xml,' + encodeURIComponent('<svg width="16" height="16" xmlns="http://www.w3.org/2000/svg"><circle cx="8" cy="8" r="6" fill="#00d4ff" stroke="#fff" stroke-width="1.5" opacity="0.9"/></svg>'),
            anchor: new AMap.Pixel(8, 8),
            size: new AMap.Size(16, 16),
          },
          // style[1] — 紧张：橙
          {
            url: 'data:image/svg+xml,' + encodeURIComponent('<svg width="16" height="16" xmlns="http://www.w3.org/2000/svg"><circle cx="8" cy="8" r="6" fill="#f59e0b" stroke="#fff" stroke-width="1.5" opacity="0.9"/></svg>'),
            anchor: new AMap.Pixel(8, 8),
            size: new AMap.Size(16, 16),
          },
          // style[2] — 满位：红
          {
            url: 'data:image/svg+xml,' + encodeURIComponent('<svg width="16" height="16" xmlns="http://www.w3.org/2000/svg"><circle cx="8" cy="8" r="6" fill="#ef4444" stroke="#fff" stroke-width="1.5" opacity="0.9"/></svg>'),
            anchor: new AMap.Pixel(8, 8),
            size: new AMap.Size(16, 16),
          },
        ],
      })

      // 绑定点击事件：点击海量点标记时弹出信息窗口
      mass.on('click', (e: any) => {
        const stationId = e.data?.id
        if (stationId) {
          const station = stationMap.get(stationId)
          if (station) {
            const avail = station.availability
            const total = avail.total
            const available = avail.available
            const rate = total > 0 ? available / total : 1
            showInfo(AMap, station, available, total, rate)
          }
        }
      })

      mass.setMap(map)
      markers.push(mass)
    }

    pulseStations = newPulseStations
    console.log('[ChinaMap] 站点加载完成:', stations.length)
  } catch (_) {
    console.log('[ChinaMap] 站点数据加载失败')
  }
}

// ──────── 呼吸脉冲动画 ────────

function initPulseCanvas() {
  if (!pulseCanvas.value || !mapRef.value) return
  const rect = mapRef.value.getBoundingClientRect()
  const dpr = window.devicePixelRatio || 1
  pulseCanvas.value.width = rect.width * dpr
  pulseCanvas.value.height = rect.height * dpr
  pulseCanvas.value.style.width = rect.width + 'px'
  pulseCanvas.value.style.height = rect.height + 'px'
  pulseCtx = pulseCanvas.value.getContext('2d')
  if (pulseCtx) {
    pulseCtx.setTransform(dpr, 0, 0, dpr, 0, 0)
  }
}

function syncPulsePositions() {
  // 地图移动后重设 canvas 尺寸
  initPulseCanvas()
}

function startPulse() {
  initPulseCanvas()
  const startTime = performance.now()

  function draw(now: number) {
    if (!pulseCtx || !map) {
      pulseRafId = requestAnimationFrame(draw)
      return
    }
    const ctx = pulseCtx
    const w = pulseCanvas.value?.width || 0
    const h = pulseCanvas.value?.height || 0
    const dpr = window.devicePixelRatio || 1

    ctx.clearRect(0, 0, w / dpr, h / dpr)

    const elapsed = (now - startTime) / 1000 // 秒

    for (const ps of pulseStations) {
      // 经纬度 → 容器像素坐标
      const pixel = map.lngLatToContainer(new (window as any).AMap.LngLat(ps.lng, ps.lat))
      if (!pixel) continue
      const x = pixel.x, y = pixel.y

      // 不同状态不同节奏
      let cycleDuration: number, minR: number, maxR: number
      if (ps.status === 0) {
        // 空闲：慢呼吸，蓝光扩散，3.5s 一个周期
        cycleDuration = 3.5; minR = 6; maxR = 24
      } else if (ps.status === 1) {
        // 紧张：中速闪烁，橙光，1.5s 一个周期
        cycleDuration = 1.5; minR = 6; maxR = 20
      } else {
        // 满位：快速脉冲，红光，0.8s 一个周期
        cycleDuration = 0.8; minR = 5; maxR = 18
      }

      // 环形进度 0→1，带相位偏移
      const raw = (elapsed % cycleDuration) / cycleDuration
      const ringProgress = (raw + ps.phase) % 1

      const radius = minR + (maxR - minR) * ringProgress
      const alpha = (1 - ringProgress) * 0.55 // 越大越淡

      const color = PULSE_COLORS[ps.status]

      ctx.beginPath()
      ctx.arc(x, y, radius, 0, Math.PI * 2)
      ctx.strokeStyle = color.replace(')', `, ${alpha})`).replace('rgb', 'rgba')
      // 处理 hex 颜色 → rgba
      ctx.strokeStyle = hexToRgba(color, alpha)
      ctx.lineWidth = 1.5
      ctx.stroke()
    }

    pulseRafId = requestAnimationFrame(draw)
  }

  pulseRafId = requestAnimationFrame(draw)
}

function hexToRgba(hex: string, alpha: number): string {
  const r = parseInt(hex.slice(1, 3), 16)
  const g = parseInt(hex.slice(3, 5), 16)
  const b = parseInt(hex.slice(5, 7), 16)
  return `rgba(${r},${g},${b},${alpha})`
}

function stopPulse() {
  if (pulseRafId) {
    cancelAnimationFrame(pulseRafId)
    pulseRafId = 0
  }
  pulseCtx = null
}

// ──────── 弹窗 / 聚焦 ────────

function showInfo(AMap: any, s: any, available: number, total: number, rate: number): void {
  if (currentInfoWindow) { currentInfoWindow.close(); currentInfoWindow = null }

  const typeName = s.type_name || s.type || ''
  const price = s.price ? s.price.total + (s.price.unit || '') : '--'
  const addr = s.address || ''
  const tel = s.tel || ''

  const html = [
    '<div style="padding:10px 14px;font-size:12px;min-width:190px;position:relative;',
    'background:rgba(9,22,41,0.96);color:#e2e8f0;',
    'border:1px solid rgba(0, 212, 255,0.3);border-radius:8px;',
    'box-shadow:0 4px 24px rgba(0,0,0,0.5);',
    'font-family:\'PingFang SC\',\'Microsoft YaHei\',sans-serif">',
    '<span onclick="window.__closeAMapInfoWindow()" style="position:absolute;top:4px;right:8px;',
    'cursor:pointer;color:#64748b;font-size:16px;line-height:1;',
    'transition:color 0.2s" onmouseover="this.style.color=\'#ef4444\'" onmouseout="this.style.color=\'#64748b\'">✕</span>',
    '<div style="font-weight:700;color:#00d4ff;margin-bottom:4px;font-size:14px;padding-right:18px">'+s.name+'</div>',
    '<div style="display:flex;gap:8px;margin-bottom:6px;font-size:10px">',
    '<span style="color:#64748b">'+(s.district_group||'')+'</span>',
    '<span style="color:#06b6d4">'+typeName+'</span>',
    '<span style="color:#fbbf24">★ '+(s.rating||'-')+'</span>',
    '</div>',
    '<div style="display:flex;gap:14px;padding:6px 0;',
    'border-top:1px solid rgba(0, 212, 255,0.1);border-bottom:1px solid rgba(0, 212, 255,0.1)">',
    '<div><span style="color:#64748b;font-size:10px">可用</span><br><span style="font-weight:700;color:#38bdf8;font-size:18px">'+available+'</span></div>',
    '<div><span style="color:#64748b;font-size:10px">总桩</span><br><span style="font-weight:700;color:#e2e8f0;font-size:18px">'+total+'</span></div>',
    '<div><span style="color:#64748b;font-size:10px">电价</span><br><span style="font-weight:700;color:#fbbf24;font-size:14px">'+price+'</span></div>',
    '</div>',
    addr ? '<div style="color:#64748b;font-size:10px;margin-top:4px">'+addr+'</div>' : '',
    tel ? '<div style="color:#64748b;font-size:10px">📞 '+tel+'</div>' : '',
    '</div>'
  ].join('')

  const infoWindow = new AMap.InfoWindow({
    content: html,
    offset: new AMap.Pixel(0, -20),
    isCustom: true,
  })
  // s.location 是 {lat, lng} 嵌套结构
  const loc = s.location || {}
  infoWindow.open(map, new AMap.LngLat(Number(loc.lng), Number(loc.lat)))
  currentInfoWindow = infoWindow
}

// 从外部（如 AlertTicker）聚焦到指定站点并弹出信息窗
function focusStation(stationId: string): void {
  if (!map) return
  const station = stationMap.get(stationId)
  if (!station) return
  const AMap = (window as any).AMap
  // station 就是 StationStatus 对象，location 是嵌套属性
  const loc = station.location
  map.setZoomAndCenter(14, new AMap.LngLat(Number(loc.lng), Number(loc.lat)), false, 600)
  // 地图移动动画结束后弹出信息窗
  setTimeout(() => {
    const avail = station.availability
    const total = avail.total
    const available = avail.available
    const rate = total > 0 ? available / total : 1
    showInfo(AMap, station, available, total, rate)
  }, 650)
}

defineExpose({ focusStation })

function clearMarkers(): void {
  markers.forEach(m => {
    try { m.setMap?.(null) } catch(e) {}
    try { m.clear?.() } catch(e) {}
  })
  markers = []
  stationMap.clear()
  pulseStations = []
}

function makeDotIcon(color: string): string {
  return 'data:image/svg+xml,' + encodeURIComponent(
    '<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14">' +
    '<circle cx="7" cy="7" r="6" fill="'+color+'" stroke="#fff" stroke-width="1.5" opacity="0.95"/>' +
    '</svg>'
  )
}

</script>

<style scoped>
.map-loading {
  position: absolute; top: 0; left: 0; right: 0; bottom: 0;
  display: flex; align-items: center; justify-content: center;
  background: rgba(5, 13, 24, 0.85); z-index: 5;
  color: var(--text-dim); font-size: 13px;
}
.map-legend {
  position: absolute; bottom: 10px; right: 10px;
  display: flex; gap: 14px; padding: 6px 12px;
  background: rgba(5, 13, 24, 0.8);
  border: 1px solid var(--border-subtle); border-radius: var(--radius-sm);
  z-index: 3; backdrop-filter: blur(4px);
}
.legend-item { display: flex; align-items: center; gap: 5px; font-size: 10px; color: var(--text-secondary); }
.legend-dot { width: 8px; height: 8px; border-radius: 50%; }

/* ── 脉冲画布 ── */
.pulse-canvas {
  position: absolute;
  top: 0; left: 0;
  width: 100%; height: 100%;
  pointer-events: none;
  z-index: 2;
}

</style>
