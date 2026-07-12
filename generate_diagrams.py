# -*- coding: utf-8 -*-
"""
为技术交底书生成4张专业图表
"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
import numpy as np
import os

# 设置中文字体
plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'SimSun']
plt.rcParams['font.monospace'] = ['SimHei', 'Microsoft YaHei', 'SimSun', 'Courier New']
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['axes.unicode_minus'] = False

OUTPUT_DIR = r'e:\DianManMan\diagrams'
os.makedirs(OUTPUT_DIR, exist_ok=True)


def draw_box(ax, x, y, w, h, text, color='#4A90D9', text_color='white', fontsize=9, style='round,pad=0.1'):
    """绘制圆角矩形框"""
    box = FancyBboxPatch((x - w/2, y - h/2), w, h,
                         boxstyle=style, facecolor=color,
                         edgecolor='#333333', linewidth=1.2)
    ax.add_patch(box)
    ax.text(x, y, text, ha='center', va='center', fontsize=fontsize,
            color=text_color, fontweight='bold', wrap=True)


def draw_arrow(ax, x1, y1, x2, y2, color='#555555'):
    """绘制箭头"""
    ax.annotate('', xy=(x2, y2), xytext=(x1, y1),
                arrowprops=dict(arrowstyle='->', color=color, lw=1.5))


def draw_diamond(ax, x, y, w, h, text, color='#F5A623', text_color='white', fontsize=8):
    """绘制菱形判断框"""
    diamond = plt.Polygon([(x, y+h/2), (x+w/2, y), (x, y-h/2), (x-w/2, y)],
                          facecolor=color, edgecolor='#333333', linewidth=1.2)
    ax.add_patch(diamond)
    ax.text(x, y, text, ha='center', va='center', fontsize=fontsize,
            color=text_color, fontweight='bold')


def diagram1_system_architecture():
    """图1：系统整体架构图"""
    fig, ax = plt.subplots(1, 1, figsize=(10, 12))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 14)
    ax.axis('off')
    ax.set_title('图1  系统整体架构图', fontsize=14, fontweight='bold', pad=20)

    # 移动端层
    rect = FancyBboxPatch((0.5, 11.2), 9, 2.2, boxstyle='round,pad=0.1',
                          facecolor='#E8F4FD', edgecolor='#4A90D9', linewidth=2)
    ax.add_patch(rect)
    ax.text(5, 13.1, 'Flutter 移动端', ha='center', va='center', fontsize=11, fontweight='bold', color='#2C5F8A')

    mobile_boxes = [
        (1.8, 12.0, '地图导航\n(高德SDK)'),
        (4.0, 12.0, '充电站列表\n(推荐结果)'),
        (6.2, 12.0, '路线规划\n(导航引导)'),
        (8.4, 12.0, '偏好设置\n(权重调节)'),
    ]
    for x, y, text in mobile_boxes:
        draw_box(ax, x, y, 1.6, 0.8, text, color='#5BA3E6', fontsize=8)

    # Nginx层
    draw_box(ax, 5, 10.5, 3, 0.6, 'Nginx 反向代理', color='#7B8A8E', fontsize=9)
    draw_arrow(ax, 5, 11.2, 5, 10.8)

    # 后端服务层
    rect2 = FancyBboxPatch((0.5, 5.8), 9, 4.2, boxstyle='round,pad=0.1',
                           facecolor='#F0F8E8', edgecolor='#5CB85C', linewidth=2)
    ax.add_patch(rect2)
    ax.text(5, 9.7, 'FastAPI 后端服务', ha='center', va='center', fontsize=11, fontweight='bold', color='#3D7A3D')
    draw_arrow(ax, 5, 10.5, 5, 9.95)

    # 核心服务模块
    service_boxes = [
        (2.0, 8.8, '推荐引擎\nranking.py\n(七维评分)', '#66BB6A'),
        (5.0, 8.8, '电池服务\nbattery.py\n(时间估算)', '#66BB6A'),
        (8.0, 8.8, '导航服务\nnavigation.py\n(偏航检测)', '#66BB6A'),
    ]
    for x, y, text, color in service_boxes:
        draw_box(ax, x, y, 2.0, 1.0, text, color=color, fontsize=8)

    # 支撑服务
    support_boxes = [
        (2.0, 7.2, '高德地图服务\namap.py\n(路径/POI)', '#81C784'),
        (5.0, 7.2, '天气服务\nweather.py\n(温度校正)', '#81C784'),
        (8.0, 7.2, '缓存服务\ncache.py\n(MD5+LRU)', '#81C784'),
    ]
    for x, y, text, color in support_boxes:
        draw_box(ax, x, y, 2.0, 1.0, text, color=color, fontsize=8)

    for x, _, _, _ in service_boxes:
        draw_arrow(ax, x, 8.3, x, 7.7)

    # 外部API层
    rect3 = FancyBboxPatch((0.5, 4.0), 9, 1.3, boxstyle='round,pad=0.1',
                           facecolor='#FFF3E0', edgecolor='#F5A623', linewidth=2)
    ax.add_patch(rect3)
    ax.text(5, 5.0, '外部API层', ha='center', va='center', fontsize=11, fontweight='bold', color='#8B6914')

    api_boxes = [
        (2.0, 4.4, '高德驾车API\n(连接池:20/100)'),
        (5.0, 4.4, '高德POI API\n(周边生态)'),
        (8.0, 4.4, 'Open-Meteo\n(实时温度)'),
    ]
    for x, y, text in api_boxes:
        draw_box(ax, x, y, 2.2, 0.6, text, color='#FFB74D', text_color='#333', fontsize=8)

    draw_arrow(ax, 2.0, 6.7, 2.0, 5.0)
    draw_arrow(ax, 5.0, 6.7, 5.0, 5.0)
    draw_arrow(ax, 8.0, 6.7, 8.0, 5.0)

    # 数据层
    rect4 = FancyBboxPatch((0.5, 0.5), 9, 3.0, boxstyle='round,pad=0.1',
                           facecolor='#F3E5F5', edgecolor='#9C27B0', linewidth=2)
    ax.add_patch(rect4)
    ax.text(5, 3.2, '数据层', ha='center', va='center', fontsize=11, fontweight='bold', color='#6A1B9A')
    draw_arrow(ax, 5, 4.0, 5, 3.5)

    data_boxes = [
        (1.8, 2.3, 'SQLite\n(用户数据)'),
        (4.0, 2.3, '充电站JSON\n(982个站点)'),
        (6.2, 2.3, '车型JSON\n(16品牌60+款)'),
        (8.4, 2.3, '电价/计费\n(武汉电网)'),
    ]
    for x, y, text in data_boxes:
        draw_box(ax, x, y, 1.6, 0.8, text, color='#CE93D8', text_color='#333', fontsize=8)

    draw_arrow(ax, 5, 5.8, 5, 5.3)

    plt.tight_layout()
    path = os.path.join(OUTPUT_DIR, 'diagram1_system_architecture.png')
    fig.savefig(path, dpi=200, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    print(f'已生成: {path}')
    return path


def diagram2_recommendation_algorithm():
    """图2：核心推荐算法流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(10, 14))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 16)
    ax.axis('off')
    ax.set_title('图2  核心推荐算法流程图（四级漏斗筛选 + 七维评分）',
                 fontsize=13, fontweight='bold', pad=20)

    y = 15.0
    draw_box(ax, 5, y, 4, 0.7, '用户发起充电请求\n(位置/SOC/车型/偏好)', color='#4A90D9')
    draw_arrow(ax, 5, y-0.35, 5, y-0.8)

    y -= 1.1
    draw_box(ax, 5, y, 3.5, 0.6, '查询缓存 (MD5 Key)\nTTL=60s, 最大200条', color='#7B8A8E')
    draw_arrow(ax, 5, y-0.3, 5, y-0.7)

    y -= 1.0
    draw_diamond(ax, 5, y, 2.0, 0.8, '缓存命中?', color='#F5A623')
    ax.text(6.2, y+0.1, '是', fontsize=9, color='#27AE60', fontweight='bold')
    ax.text(5, y-0.6, '否', fontsize=9, color='#E74C3C', fontweight='bold')
    draw_arrow(ax, 6.0, y, 8.0, y)
    draw_box(ax, 8.5, y, 1.5, 0.5, '返回缓存', color='#27AE60', fontsize=9)
    draw_arrow(ax, 5, y-0.4, 5, y-0.9)

    y -= 1.2
    rect = FancyBboxPatch((1.5, y-0.4), 7, 0.8, boxstyle='round,pad=0.1',
                          facecolor='#E3F2FD', edgecolor='#1976D2', linewidth=1.5)
    ax.add_patch(rect)
    ax.text(5, y, '第一级：Bounding Box 快速筛选\n纬度±0.45°  经度±0.52°  Haversine直线距离过滤',
            ha='center', va='center', fontsize=8, color='#1565C0')
    ax.text(8.7, y, '约50-100个', fontsize=8, color='#666', ha='left')
    draw_arrow(ax, 5, y-0.4, 5, y-0.9)

    y -= 1.2
    rect = FancyBboxPatch((1.5, y-0.4), 7, 0.8, boxstyle='round,pad=0.1',
                          facecolor='#E8F5E9', edgecolor='#388E3C', linewidth=1.5)
    ax.add_patch(rect)
    ax.text(5, y, '第二级：粗估排序取 Top-5\n直线距离 × 1.35 估算路线距离',
            ha='center', va='center', fontsize=8, color='#2E7D32')
    ax.text(8.7, y, '→ 5个', fontsize=8, color='#666', ha='left')
    draw_arrow(ax, 5, y-0.4, 5, y-0.9)

    y -= 1.2
    rect = FancyBboxPatch((1.5, y-0.4), 7, 0.8, boxstyle='round,pad=0.1',
                          facecolor='#FFF3E0', edgecolor='#F57C00', linewidth=1.5)
    ax.add_patch(rect)
    ax.text(5, y, '第三级：并发请求高德 API\nasyncio.gather 并发5路 → 真实驾车距离/时长/polyline',
            ha='center', va='center', fontsize=8, color='#E65100')
    ax.text(8.7, y, '→ 5个精确', fontsize=8, color='#666', ha='left')
    draw_arrow(ax, 5, y-0.4, 5, y-0.9)

    y -= 1.2
    # 评分框 - 用较大区域
    rect = FancyBboxPatch((1.0, y-0.9), 8, 1.8, boxstyle='round,pad=0.1',
                          facecolor='#FCE4EC', edgecolor='#C2185B', linewidth=2)
    ax.add_patch(rect)
    ax.text(5, y+0.5, '第四级：七维加权评分排序', ha='center', va='center',
            fontsize=10, fontweight='bold', color='#880E4F')

    score_text = (
        '基础分(85%):  距离·w₁ + 价格·w₂ + 等待·w₃ + 功率·w₄\n'
        '辅助分(15%):  疲劳×0.3 + 停车×0.1 + 可用桩×0.2\n'
        '最终分 = 基础分×0.85 + 辅助分×0.15 + Bonus - Penalty'
    )
    ax.text(5, y-0.2, score_text, ha='center', va='center', fontsize=8, color='#333',
            linespacing=1.5)
    draw_arrow(ax, 5, y-0.9, 5, y-1.4)

    y -= 1.7
    draw_box(ax, 5, y, 4, 0.7, '写入缓存 → 返回 Top-20 排序结果', color='#4CAF50')
    draw_arrow(ax, 5, y-0.35, 5, y-0.8)

    y -= 1.1
    draw_box(ax, 5, y, 5, 0.7, '移动端展示充电站列表\n(含综合评分/价格/距离/预计时长)', color='#4A90D9')

    plt.tight_layout()
    path = os.path.join(OUTPUT_DIR, 'diagram2_recommendation_algorithm.png')
    fig.savefig(path, dpi=200, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    print(f'已生成: {path}')
    return path


def diagram3_route_planning():
    """图3：两级降级路径规划流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(10, 10))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 12)
    ax.axis('off')
    ax.set_title('图3  两级降级路径规划流程图', fontsize=13, fontweight='bold', pad=20)

    y = 11.0
    draw_box(ax, 5, y, 4, 0.7, '需要获取站点路线数据', color='#4A90D9')
    draw_arrow(ax, 5, y-0.35, 5, y-0.8)

    y -= 1.1
    # 第一级
    rect = FancyBboxPatch((1.5, y-0.6), 7, 1.2, boxstyle='round,pad=0.1',
                          facecolor='#E3F2FD', edgecolor='#1976D2', linewidth=2)
    ax.add_patch(rect)
    ax.text(5, y+0.2, '第一级：调用高德地图 API', ha='center', va='center',
            fontsize=10, fontweight='bold', color='#1565C0')
    ax.text(5, y-0.2, '驾车路径规划接口 | httpx.AsyncClient\n连接池: 20保持/100最大 | 超时: 5秒',
            ha='center', va='center', fontsize=8, color='#333')
    draw_arrow(ax, 5, y-0.6, 5, y-1.1)

    y -= 1.4
    draw_diamond(ax, 5, y, 2.5, 0.8, 'API 调用成功?', color='#F5A623')

    # 成功分支
    ax.text(7.0, y+0.15, '是', fontsize=9, color='#27AE60', fontweight='bold')
    draw_arrow(ax, 6.25, y, 7.5, y)
    draw_box(ax, 8.5, y, 2, 0.6, '返回真实数据', color='#27AE60', fontsize=9)

    # 失败分支
    ax.text(4.3, y-0.55, '否', fontsize=9, color='#E74C3C', fontweight='bold')
    draw_arrow(ax, 5, y-0.4, 5, y-1.0)

    y -= 1.3
    # 第二级
    rect2 = FancyBboxPatch((1.5, y-0.7), 7, 1.4, boxstyle='round,pad=0.1',
                           facecolor='#FFF3E0', edgecolor='#F57C00', linewidth=2)
    ax.add_patch(rect2)
    ax.text(5, y+0.3, '第二级：Haversine 系数估算（兜底）', ha='center', va='center',
            fontsize=10, fontweight='bold', color='#E65100')
    ax.text(5, y-0.15, '直线距离 = Haversine(用户位置, 站点位置)\n估算距离 = 直线距离 × 1.35（道路弯曲系数）\n估算时长 = 估算距离 / 35 × 60（平均车速35km/h）',
            ha='center', va='center', fontsize=8, color='#333', linespacing=1.4)
    draw_arrow(ax, 5, y-0.7, 5, y-1.2)

    y -= 1.5
    draw_box(ax, 5, y, 4, 0.7, '返回估算数据（降级模式）\npolyline = null', color='#FF9800', text_color='#333')

    # 右侧对比表
    ax.text(8.5, 10.5, '返回数据对比:', fontsize=9, fontweight='bold', color='#333', ha='center')
    ax.text(8.5, 10.0, '正常模式:', fontsize=8, color='#27AE60', fontweight='bold', ha='center')
    ax.text(8.5, 9.6, '· 真实驾车距离\n· 真实预计时长\n· polyline坐标', fontsize=7, color='#333', ha='center', linespacing=1.3)
    ax.text(8.5, 8.5, '降级模式:', fontsize=8, color='#E74C3C', fontweight='bold', ha='center')
    ax.text(8.5, 8.1, '· 估算驾车距离\n· 估算预计时长\n· polyline=null', fontsize=7, color='#333', ha='center', linespacing=1.3)

    plt.tight_layout()
    path = os.path.join(OUTPUT_DIR, 'diagram3_route_planning.png')
    fig.savefig(path, dpi=200, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    print(f'已生成: {path}')
    return path


def diagram4_navigation_state_machine():
    """图4：智能导航状态机流程图"""
    fig, ax = plt.subplots(1, 1, figsize=(11, 13))
    ax.set_xlim(0, 11)
    ax.set_ylim(0, 15)
    ax.axis('off')
    ax.set_title('图4  智能导航状态机流程图', fontsize=13, fontweight='bold', pad=20)

    y = 14.0
    draw_box(ax, 5.5, y, 3.5, 0.7, '用户开始导航', color='#4A90D9')
    draw_arrow(ax, 5.5, y-0.35, 5.5, y-0.8)

    y -= 1.1
    draw_box(ax, 5.5, y, 3.5, 0.7, '状态: 导航中\n偏航计数器 = 0', color='#66BB6A')
    draw_arrow(ax, 5.5, y-0.35, 5.5, y-0.8)

    y -= 1.1
    draw_box(ax, 5.5, y, 3, 0.6, 'GPS 位置更新', color='#7B8A8E')
    draw_arrow(ax, 5.5, y-0.3, 5.5, y-0.8)

    y -= 1.1
    draw_diamond(ax, 5.5, y, 3.0, 0.8, 'GPS精度 > 25m\n且 > 0 ?', color='#F5A623')

    # 是 - 丢弃
    ax.text(1.5, y+0.15, '是', fontsize=9, color='#E74C3C', fontweight='bold')
    draw_arrow(ax, 4.0, y, 2.0, y)
    draw_box(ax, 1.5, y, 1.5, 0.5, '丢弃该点', color='#E74C3C', fontsize=9)

    # 否 - 继续
    ax.text(5.8, y-0.55, '否', fontsize=9, color='#27AE60', fontweight='bold')
    draw_arrow(ax, 5.5, y-0.4, 5.5, y-1.0)

    y -= 1.3
    draw_box(ax, 5.5, y, 4.5, 0.7, '计算点到路线最短距离\n(点到线段距离算法)', color='#9C27B0')

    draw_arrow(ax, 5.5, y-0.35, 5.5, y-0.8)
    y -= 1.1
    draw_diamond(ax, 5.5, y, 2.5, 0.8, '距离 > 50m ?', color='#F5A623')

    # 否 - 正常
    ax.text(1.5, y+0.15, '否', fontsize=9, color='#27AE60', fontweight='bold')
    draw_arrow(ax, 4.25, y, 2.5, y)
    draw_box(ax, 1.5, y, 1.8, 0.5, '偏航计数=0\n继续导航', color='#27AE60', fontsize=8)

    # 是 - 偏航计数+1
    ax.text(5.8, y-0.55, '是', fontsize=9, color='#E74C3C', fontweight='bold')
    draw_arrow(ax, 5.5, y-0.4, 5.5, y-1.0)

    y -= 1.3
    draw_box(ax, 5.5, y, 3, 0.6, '偏航计数 +1', color='#FF9800', text_color='#333')
    draw_arrow(ax, 5.5, y-0.3, 5.5, y-0.8)

    y -= 1.1
    draw_diamond(ax, 5.5, y, 2.5, 0.8, '计数 ≥ 3 ?', color='#F5A623')

    # 否 - 继续监控
    ax.text(1.5, y+0.15, '否', fontsize=9, color='#27AE60', fontweight='bold')
    draw_arrow(ax, 4.25, y, 2.5, y)
    draw_box(ax, 1.5, y, 1.8, 0.5, '继续监控', color='#27AE60', fontsize=9)

    # 是 - 偏航判定
    ax.text(5.8, y-0.55, '是', fontsize=9, color='#E74C3C', fontweight='bold')
    draw_arrow(ax, 5.5, y-0.4, 5.5, y-1.0)

    y -= 1.3
    rect = FancyBboxPatch((3.0, y-0.5), 5, 1.0, boxstyle='round,pad=0.1',
                          facecolor='#FFEBEE', edgecolor='#D32F2F', linewidth=2)
    ax.add_patch(rect)
    ax.text(5.5, y+0.1, '偏航判定', ha='center', va='center',
            fontsize=11, fontweight='bold', color='#C62828')
    ax.text(5.5, y-0.25, '显示重规划提示 → 重新请求路径规划', ha='center', va='center',
            fontsize=8, color='#333')
    draw_arrow(ax, 5.5, y-0.5, 5.5, y-1.0)

    y -= 1.3
    draw_box(ax, 5.5, y, 4.5, 0.7, '更新路线 polyline\n偏航计数器归零 → 返回"导航中"状态', color='#2196F3')

    # 到达检测分支 (从"偏航计数=0"处分出)
    # 从"继续导航"框向下引出到达检测
    ax.text(1.5, 11.2, '到达检测:', fontsize=9, fontweight='bold', color='#333')
    ax.text(1.5, 10.8, '距离 < 100m', fontsize=8, color='#333')
    ax.text(1.5, 10.4, 'AND 精度 < 25m', fontsize=8, color='#333')
    ax.text(1.5, 10.0, 'AND 速度 < 5km/h', fontsize=8, color='#333')
    ax.text(1.5, 9.6, 'AND 持续 3 秒', fontsize=8, color='#333')

    draw_box(ax, 1.5, 8.8, 2.0, 0.6, '导航结束', color='#4CAF50')

    plt.tight_layout()
    path = os.path.join(OUTPUT_DIR, 'diagram4_navigation_state_machine.png')
    fig.savefig(path, dpi=200, bbox_inches='tight', facecolor='white')
    plt.close(fig)
    print(f'已生成: {path}')
    return path


if __name__ == '__main__':
    print('开始生成图表...')
    p1 = diagram1_system_architecture()
    p2 = diagram2_recommendation_algorithm()
    p3 = diagram3_route_planning()
    p4 = diagram4_navigation_state_machine()
    print(f'\n全部完成！共生成4张图表，保存在: {OUTPUT_DIR}')
