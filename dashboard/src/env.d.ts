/// <reference types="vite/client" />

declare module '*.vue' {
  import type { DefineComponent } from 'vue'
  const component: DefineComponent<{}, {}, any>
  export default component
}

declare namespace AMap {
  class Map {
    constructor(container: HTMLElement | string, opts?: any)
    destroy(): void
    setCenter(center: [number, number]): void
    setZoom(zoom: number): void
    setBounds(bounds: Bounds, noAnim: boolean, padding: number[], duration: number): void
    addControl(control: any): void
    remove(markers: any[]): void
  }
  class Bounds {
    extend(point: [number, number]): void
  }
  class Marker {
    constructor(opts?: any)
    setTitle(title: string): void
    setMap(map: any): void
    on(event: string, callback: (e?: any) => void): void
    getPosition(): LngLat
  }
  class InfoWindow {
    constructor(opts?: any)
    open(map: any, pos: LngLat): void
  }
  class LngLat {
    lng: number
    lat: number
  }
  class Icon {
    constructor(opts?: any)
  }
  class Size {
    constructor(width: number, height: number)
  }
  class Pixel {
    constructor(x: number, y: number)
  }
  class Scale {}
  class ToolBar {
    constructor(opts?: any)
  }
}
