import type { RankItem } from '@/types'

/** 模拟：热门充电站 TOP10（按充电量） */
export const mockHotRankings: RankItem[] = [
  { rank: 1, name: '特来电武汉光谷超级充电站', district: '武昌', value: 128500, unit: 'kWh' },
  { rank: 2, name: '星星充电汉口火车站快充站', district: '汉口', value: 119200, unit: 'kWh' },
  { rank: 3, name: '国家电网武昌徐东充电站', district: '武昌', value: 105800, unit: 'kWh' },
  { rank: 4, name: '壳牌武汉塔子湖超级充电站', district: '汉口', value: 98400, unit: 'kWh' },
  { rank: 5, name: '小鹏超充武汉天地站', district: '汉口', value: 91200, unit: 'kWh' },
  { rank: 6, name: '蔚来换电站武汉楚河汉街站', district: '武昌', value: 87600, unit: 'kWh' },
  { rank: 7, name: '特来电汉阳王家湾充电站', district: '汉阳', value: 82300, unit: 'kWh' },
  { rank: 8, name: '星星充电光谷软件园站', district: '武昌', value: 78100, unit: 'kWh' },
  { rank: 9, name: '国家电网汉口北充电站', district: '汉口', value: 74500, unit: 'kWh' },
  { rank: 10, name: '壳牌武汉解放公园充电站', district: '汉口', value: 70200, unit: 'kWh' },
]
