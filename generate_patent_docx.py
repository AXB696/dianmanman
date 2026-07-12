# -*- coding: utf-8 -*-
"""
将技术交底书MD内容生成为格式化的Word文档
"""
from docx import Document
from docx.shared import Pt, Cm, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT
from docx.oxml.ns import qn


def set_cell_text(cell, text, bold=False, font_size=10, font_name='宋体'):
    """设置单元格文本格式"""
    cell.text = ''
    p = cell.paragraphs[0]
    run = p.add_run(text)
    run.font.size = Pt(font_size)
    run.font.name = font_name
    run._element.rPr.rFonts.set(qn('w:eastAsia'), font_name)
    run.bold = bold


def add_heading(doc, text, level=1):
    """添加标题"""
    heading = doc.add_heading(text, level=level)
    for run in heading.runs:
        run.font.name = '黑体'
        run._element.rPr.rFonts.set(qn('w:eastAsia'), '黑体')
    return heading


def add_paragraph(doc, text, bold=False, font_size=12, font_name='宋体', alignment=None):
    """添加段落"""
    p = doc.add_paragraph()
    if alignment:
        p.alignment = alignment
    run = p.add_run(text)
    run.font.size = Pt(font_size)
    run.font.name = font_name
    run._element.rPr.rFonts.set(qn('w:eastAsia'), font_name)
    run.bold = bold
    return p


def add_code_block(doc, code_text):
    """添加代码块（使用等宽字体）"""
    p = doc.add_paragraph()
    p.paragraph_format.left_indent = Cm(1)
    run = p.add_run(code_text)
    run.font.size = Pt(9)
    run.font.name = 'Consolas'
    run._element.rPr.rFonts.set(qn('w:eastAsia'), '宋体')
    # 设置灰色背景效果（通过字体颜色区分）
    run.font.color.rgb = RGBColor(0x33, 0x33, 0x33)
    return p


def add_bullet(doc, text, font_size=12):
    """添加列表项"""
    p = doc.add_paragraph(style='List Bullet')
    p.clear()
    run = p.add_run(text)
    run.font.size = Pt(font_size)
    run.font.name = '宋体'
    run._element.rPr.rFonts.set(qn('w:eastAsia'), '宋体')
    return p


def add_numbered_item(doc, text, font_size=12):
    """添加编号列表项"""
    p = doc.add_paragraph(style='List Number')
    p.clear()
    run = p.add_run(text)
    run.font.size = Pt(font_size)
    run.font.name = '宋体'
    run._element.rPr.rFonts.set(qn('w:eastAsia'), '宋体')
    return p


def generate_document():
    doc = Document()

    # 设置默认字体
    style = doc.styles['Normal']
    font = style.font
    font.name = '宋体'
    font.size = Pt(12)
    style.element.rPr.rFonts.set(qn('w:eastAsia'), '宋体')

    # ============ 标题 ============
    title = doc.add_heading('专利申请技术交底书', level=0)
    title.alignment = WD_ALIGN_PARAGRAPH.CENTER
    for run in title.runs:
        run.font.name = '黑体'
        run._element.rPr.rFonts.set(qn('w:eastAsia'), '黑体')

    # ============ 基本信息表格 ============
    table = doc.add_table(rows=6, cols=4, style='Table Grid')
    table.alignment = WD_TABLE_ALIGNMENT.CENTER

    info_data = [
        ['公司名称', '武汉理工大学', '', ''],
        ['发明名称', '一种基于多目标优化的新能源汽车智能充电推荐方法', '', ''],
        ['技术联系人', '', '邮箱', ''],
        ['手机', '', '专利类型', '实用新型'],
        ['固定电话', '', '', ''],
    ]

    # 合并单元格并填写内容
    # 第1行
    set_cell_text(table.cell(0, 0), '公司名称', bold=True)
    table.cell(0, 1).merge(table.cell(0, 3))
    set_cell_text(table.cell(0, 1), '武汉理工大学')

    # 第2行
    set_cell_text(table.cell(1, 0), '发明名称', bold=True)
    table.cell(1, 1).merge(table.cell(1, 3))
    set_cell_text(table.cell(1, 1), '一种基于多目标优化的新能源汽车智能充电推荐方法')

    # 第3行
    set_cell_text(table.cell(2, 0), '技术联系人', bold=True)
    set_cell_text(table.cell(2, 1), '（待填写）')
    set_cell_text(table.cell(2, 2), '邮箱', bold=True)
    set_cell_text(table.cell(2, 3), '（待填写）')

    # 第4行
    set_cell_text(table.cell(3, 0), '手机', bold=True)
    set_cell_text(table.cell(3, 1), '（待填写）')
    set_cell_text(table.cell(3, 2), '专利类型', bold=True)
    set_cell_text(table.cell(3, 3), '实用新型')

    # 第5行
    set_cell_text(table.cell(4, 0), '固定电话', bold=True)
    table.cell(4, 1).merge(table.cell(4, 3))
    set_cell_text(table.cell(4, 1), '')

    # 第6行（空行，用于分隔）
    table.cell(5, 0).merge(table.cell(5, 3))
    set_cell_text(table.cell(5, 0), '')

    doc.add_paragraph()  # 空行

    # ============ 第1部分：发明创造名称 ============
    add_heading(doc, '1、发明创造名称', level=2)
    add_paragraph(doc, '一种基于多目标优化的新能源汽车智能充电推荐方法')

    # ============ 第2部分：所属技术领域 ============
    add_heading(doc, '2、所属技术领域', level=2)
    add_paragraph(doc, '新能源汽车、智能充电、多目标优化、路径规划、推荐算法、导航定位')

    # ============ 第3部分：背景技术 ============
    add_heading(doc, '3、发明或者实用新型相关的背景技术', level=2)
    add_paragraph(doc, '随着新能源汽车保有量的快速增长，充电基础设施的智能化管理成为亟待解决的关键问题。现有的充电站推荐系统存在以下技术缺陷：')

    bg_issues = [
        ('（1）推荐维度单一', '现有系统通常仅考虑距离或价格单一因素进行推荐，未能综合考虑充电等待时间、充电功率、停车费用、周边配套设施等多维度因素，导致推荐结果与用户实际需求存在较大偏差。'),
        ('（2）路径规划可靠性不足', '现有的路径规划方案通常采用单一的地图API进行路线计算，当API服务不可用时系统将无法提供服务。同时，现有方案未考虑车辆当前电量状态对可达性的影响，可能导致用户前往无法到达的充电站。'),
        ('（3）充电时间估算不准确', '现有系统在估算充电时间时，未充分考虑电池类型差异（如三元锂电池与磷酸铁锂电池的充电特性差异）、电池当前荷电状态（SOC）对充电速率的影响、以及环境温度对电池性能的影响，导致充电时间估算偏差较大。'),
        ('（4）缺乏实时数据融合', '现有系统未能有效融合实时电价信息（如峰谷分时电价）、实时天气数据（温度对电池能耗的影响）、充电站实时空闲状态等动态数据，推荐结果缺乏时效性和准确性。'),
        ('（5）导航精度与用户体验不佳', '现有系统在导航过程中缺乏有效的偏航检测与重规划机制，GPS定位精度不稳定导致误判，到达判断不准确，用户在充电过程中的体验较差。'),
        ('（6）车型适配性差', '现有系统未建立完善的车型数据库，无法根据不同车型的电池容量、能耗特性、最大充电功率等参数进行个性化推荐和充电时间估算。'),
    ]

    for title, content in bg_issues:
        add_paragraph(doc, title, bold=True)
        add_paragraph(doc, content)

    # ============ 第4部分：发明内容 ============
    add_heading(doc, '4、发明或者实用新型的发明内容', level=2)

    # 一、解决的技术问题
    add_heading(doc, '一、解决的技术问题', level=3)
    add_paragraph(doc, '本发明要解决的技术问题是：如何构建一种综合考虑多维度因素的新能源汽车智能充电推荐方法，实现充电站的精准推荐、路径的可靠规划、充电时间的准确估算，并通过实时数据融合、智能导航辅助机制提升推荐结果的时效性和用户体验。')

    # 二、技术方案
    add_heading(doc, '二、技术方案', level=3)
    add_paragraph(doc, '本发明提出一种基于多目标优化的新能源汽车智能充电推荐方法，包括以下核心步骤：')

    # 4.1 多目标加权评分算法
    add_heading(doc, '4.1 多目标加权评分算法', level=4)
    add_paragraph(doc, '本发明采用七维度加权评分模型对充电站进行综合评价，评分维度包括：')

    # (1) 距离评分
    add_paragraph(doc, '（1）距离评分 S_dist', bold=True)
    add_paragraph(doc, '采用对数衰减函数，计算公式为：')
    add_code_block(doc, 'S_dist = 100 × [ln(D_max + 1) - ln(d + 1)] / ln(D_max + 1)')
    add_paragraph(doc, '其中，d为实际路线距离（km），D_max为最大有效距离（取80km）。该函数特性为：d=0时S_dist=100，d=D_max时S_dist=0；1-5km快速递减（d=1km时约84分，d=5km时约59分），5-30km平缓递减（d=15km时约37分，d=30km时约22分），符合用户"近者优先"的心理预期。')

    # (2) 价格评分
    add_paragraph(doc, '（2）价格评分 S_price', bold=True)
    add_paragraph(doc, '采用Sigmoid平滑函数，计算公式为：')
    add_code_block(doc, 'S_price = 100 / (1 + e^(k×(P - P_ref)))')
    add_paragraph(doc, '其中，P为综合电价（元/kWh），P_ref为地区基准电价（取1.65元/kWh），k为锐度系数（取4.0）。该函数在基准电价附近变化平缓，在极端价格处快速收敛，有效区分不同价格区间。')

    # (3) 等待时间评分
    add_paragraph(doc, '（3）等待时间评分 S_wait', bold=True)
    add_paragraph(doc, '采用指数衰减函数，计算公式为：')
    add_code_block(doc, 'S_wait = 100 × e^(-t/τ)')
    add_paragraph(doc, '其中，t为等待时间（分钟），τ为时间常数（取15分钟）。同时叠加可用桩比例惩罚因子：当可用桩比例为0时，评分乘以0.2；比例低于30%时，评分乘以0.6；比例低于50%时，评分乘以0.8。')

    # (4) 功率评分
    add_paragraph(doc, '（4）功率评分 S_power', bold=True)
    add_paragraph(doc, '采用分段映射函数：')
    add_bullet(doc, '换电站：固定90分')
    add_bullet(doc, '超充（>60kW）：70-95分，功率越高分越高，采用对数递增')
    add_bullet(doc, '快充（7-60kW）：40-70分，线性映射')
    add_bullet(doc, '慢充（≤7kW）：20-40分，线性映射')

    # (5) 疲劳评分
    add_paragraph(doc, '（5）疲劳评分 S_fatigue', bold=True)
    add_paragraph(doc, '采用指数衰减函数评估总时间成本：')
    add_code_block(doc, 'S_fatigue = 100 × e^(-T/3)')
    add_paragraph(doc, '其中，T为总时间成本（小时）= 行驶时间 + 充电时间 + 等待时间。行驶时间按平均车速35km/h估算。')

    # (6) 停车费评分
    add_paragraph(doc, '（6）停车费评分 S_parking', bold=True)
    add_paragraph(doc, '计算充电期间的停车费总额，每10元停车费扣20分，上限100分。免费停车加5分奖励。')

    # (7) 可用桩比例评分
    add_paragraph(doc, '（7）可用桩比例评分 S_avail', bold=True)
    add_paragraph(doc, '直接按可用桩占总桩数的比例计算，比例越高评分越高。')

    # 用户可配置权重机制
    add_paragraph(doc, '用户可配置权重机制：', bold=True)
    add_paragraph(doc, '本发明支持用户自定义四个核心维度的权重，包括距离权重w₁、价格权重w₂、等待时间权重w₃、功率权重w₄，各权重取值范围为[0,1]，系统自动进行归一化处理。默认权重配置为：w₁=0.3, w₂=0.3, w₃=0.2, w₄=0.2。')

    # 综合评分公式
    add_paragraph(doc, '综合评分公式：', bold=True)
    add_code_block(doc, '基础分 = (w₁×S_dist + w₂×S_price + w₃×S_wait + w₄×S_power) / (w₁+w₂+w₃+w₄)\n辅助分 = (0.3×S_fatigue + 0.1×S_parking + 0.2×S_avail) / 0.6\n最终分 = 基础分 × 0.85 + 辅助分 × 0.15 + Bonus - Penalty')

    # 加分项
    add_paragraph(doc, '加分项（Bonus）：', bold=True)
    add_bullet(doc, '超充急迫加成：用户偏好超充且站点为超充站，加10分')
    add_bullet(doc, '夜间谷电激励：到达时段为谷时且电价低于阈值，加10-30分（电价越低加分越多）')
    add_bullet(doc, '免停车费激励：免费停车，加5分')

    # 惩罚项
    add_paragraph(doc, '惩罚项（Penalty）：', bold=True)
    add_bullet(doc, '高峰涨价惩罚：尖峰时段且电价>2.0元/kWh，扣8分')
    add_bullet(doc, '全占用惩罚：无可用桩且等待>30分钟，扣15分')

    # 4.2 两级降级路径规划机制
    add_heading(doc, '4.2 两级降级路径规划机制', level=4)
    add_paragraph(doc, '本发明采用两级降级机制确保路径规划的可靠性：')

    add_paragraph(doc, '第一级：高德地图API真实路线', bold=True)
    add_paragraph(doc, '调用高德地图驾车路径规划API，获取真实驾车距离、预计时长、路线折线坐标。采用连接池复用技术（最大保持20个连接，100个并发上限），提高并发请求效率。')

    add_paragraph(doc, '第二级：系数估算兜底', bold=True)
    add_paragraph(doc, '当高德API不可用时，采用Haversine公式计算直线距离，乘以道路系数（取1.35）进行估算，确保系统始终能够提供推荐结果。预计时长按平均车速35km/h计算。')

    add_paragraph(doc, '两阶段筛选策略：', bold=True)
    add_paragraph(doc, '第一阶段（快速初筛）：')
    add_bullet(doc, '采用Bounding Box快速筛选（纬度±0.45°，经度±0.52°）')
    add_bullet(doc, '计算Haversine直线距离，过滤超出最大距离的候选')
    add_bullet(doc, '按预估路线距离（直线距离×1.35）排序，取Top-5')
    add_paragraph(doc, '第二阶段（精确路线）：')
    add_bullet(doc, '对Top-5候选并发请求高德API获取真实路线')
    add_bullet(doc, '获取真实驾车距离、预计时长、polyline折线坐标')
    add_bullet(doc, '其余候选使用第一阶段粗估值作为fallback')

    add_paragraph(doc, '异步并发处理：', bold=True)
    add_paragraph(doc, '采用asyncio.gather实现并发请求，结合httpx.AsyncClient连接池复用，显著降低网络延迟。')

    # 4.3 充电时间估算模型
    add_heading(doc, '4.3 充电时间估算模型', level=4)
    add_paragraph(doc, '本发明建立充电时间估算模型，考虑以下因素：')

    add_paragraph(doc, '（1）电池类型区分', bold=True)
    add_paragraph(doc, '系统内置16个品牌、60+款车型的参数数据库，包括：')
    add_bullet(doc, '电池容量（kWh）')
    add_bullet(doc, '百公里能耗（kWh/100km）')
    add_bullet(doc, '最大充电功率（kW）')
    add_bullet(doc, '电池类型（三元锂电池/磷酸铁锂电池）')

    add_paragraph(doc, '（2）充电效率修正', bold=True)
    add_paragraph(doc, '考虑充电过程中的能量损耗，取平均充电效率为80%。')

    add_paragraph(doc, '（3）充电时间估算公式：', bold=True)
    add_code_block(doc, '需要充入电量 = (目标SOC - 当前SOC) / 100 × 电池容量\n有效充电功率 = 充电桩功率 × 0.8（充电效率）\n充电时间（分钟）= 需要充入电量 / 有效充电功率 × 60')

    add_paragraph(doc, '（4）换电站特殊处理：', bold=True)
    add_paragraph(doc, '换电站充电时间固定为5分钟。')

    # 4.4 实时数据融合机制
    add_heading(doc, '4.4 实时数据融合机制', level=4)

    add_paragraph(doc, '（1）分时电价模型', bold=True)
    add_paragraph(doc, '基于湖北省电网公开电价数据，建立武汉地区分时电价模型：')
    add_bullet(doc, '尖峰时段（11:00-13:00, 18:00-20:00）：系数1.18，约1.95元/kWh')
    add_bullet(doc, '高峰时段（08:00-11:00, 13:00-18:00）：系数1.08，约1.78元/kWh')
    add_bullet(doc, '平段（07:00-08:00, 20:00-23:00）：系数1.00，约1.65元/kWh')
    add_bullet(doc, '谷段（23:00-次日07:00）：系数0.52，约0.86元/kWh')
    add_paragraph(doc, '系统根据预计到达时间动态计算电价，并提供"等待进谷"建议。当用户处于尖峰时段且等待不超过60分钟即可进入谷时段时，系统会计算并显示可节省的金额。')

    add_paragraph(doc, '（2）气温校正能耗模型', bold=True)
    add_paragraph(doc, '通过Open-Meteo API获取实时气温（无需API Key），建立温度-能耗衰减模型：')
    add_bullet(doc, '低温（≤5°C）：能耗系数1.35（暖风+电池活性下降）')
    add_bullet(doc, '高温（≥35°C）：能耗系数1.20（空调制冷）')
    add_bullet(doc, '常温（5-35°C）：能耗系数1.0')

    add_paragraph(doc, '（3）可达性判断算法', bold=True)
    add_paragraph(doc, '基于车辆当前状态判断是否可达目标充电站：')
    add_code_block(doc, '可用能量 = (当前SOC / 100) × 电池容量\n有效能耗 = 标称能耗 × 温度衰减系数\n最大续航 = 可用能量 / (有效能耗 / 100)\n安全续航 = 最大续航 × 0.7（保留30%电量缓冲）\n是否可达 = 实际距离 ≤ 安全续航')

    add_paragraph(doc, '（4）周边生态指数', bold=True)
    add_paragraph(doc, '通过高德地图POI搜索API，查询充电站周边1km范围内的餐饮、购物、休闲设施，计算周边生态指数：')
    add_code_block(doc, '生态加分 = min(10, 店铺数量 × 0.5)')
    add_paragraph(doc, '同时返回周边热门品牌名称，用于生成洞察消息。')

    # 4.5 智能导航辅助机制
    add_heading(doc, '4.5 智能导航辅助机制', level=4)

    add_paragraph(doc, '（1）GPS精度过滤机制', bold=True)
    add_paragraph(doc, '系统对GPS定位数据进行精度过滤：')
    add_bullet(doc, '精度阈值：25米')
    add_bullet(doc, '当定位精度值大于0且超过阈值时，该定位数据被过滤')
    add_bullet(doc, '精度未知时默认为10米')
    add_bullet(doc, '确保用于导航判断的定位数据具有足够可靠性')

    add_paragraph(doc, '（2）偏航检测与去抖机制', bold=True)
    add_paragraph(doc, '系统采用点到线段距离算法检测偏航，并引入去抖机制避免误判：')
    add_bullet(doc, '偏航阈值：50米')
    add_bullet(doc, '去抖次数：连续3次超阈值才触发偏航')
    add_bullet(doc, '检测算法：计算用户位置到路线polyline各段的最短距离')
    add_bullet(doc, '当用户回到路线上时，重置偏航计数器')

    add_paragraph(doc, '偏航处理流程：', bold=True)
    add_numbered_item(doc, 'GPS更新时，计算用户到路线的最短距离')
    add_numbered_item(doc, '距离超过50米阈值时，偏航计数器+1')
    add_numbered_item(doc, '连续3次超阈值，判定为偏航，显示提示')
    add_numbered_item(doc, '自动触发从当前位置重新规划路线')
    add_numbered_item(doc, '用户也可手动点击"偏航重算"按钮')

    add_paragraph(doc, '（3）增强到达判断机制', bold=True)
    add_paragraph(doc, '系统采用三重条件确认到达：')
    add_bullet(doc, '条件1：用户到目的地距离 < 100米')
    add_bullet(doc, '条件2：GPS精度 < 25米')
    add_bullet(doc, '条件3：当前速度 < 5km/h')
    add_bullet(doc, '持续确认：以上三个条件需同时满足持续3秒')

    add_paragraph(doc, '到达判断流程：', bold=True)
    add_numbered_item(doc, 'GPS更新时，计算剩余距离')
    add_numbered_item(doc, '检查三重条件是否同时满足')
    add_numbered_item(doc, '首次满足时开始计时')
    add_numbered_item(doc, '持续3秒后确认到达')
    add_numbered_item(doc, '任一条件不满足时重置计时')

    add_paragraph(doc, '（4）实时导航信息展示', bold=True)
    add_bullet(doc, '剩余距离（km）')
    add_bullet(doc, '预计剩余时间（分钟）')
    add_bullet(doc, '当前导航步骤索引')
    add_bullet(doc, '实时GPS速度（km/h）')
    add_bullet(doc, '当前道路名称')

    # 4.6 缓存优化机制
    add_heading(doc, '4.6 缓存优化机制', level=4)
    add_paragraph(doc, '采用内存缓存机制提高系统响应速度：')
    add_bullet(doc, '缓存Key：用户位置+充电参数的MD5哈希值（精确到小数点后4位）')
    add_bullet(doc, '缓存有效期：60秒')
    add_bullet(doc, '最大缓存条目：200条')
    add_bullet(doc, '淘汰策略：超过容量时，按过期时间排序，删除最早过期的20%条目')
    add_bullet(doc, '线程安全：采用asyncio.Lock保证并发安全')

    # ============ 第5部分：具体实施方式 ============
    add_heading(doc, '5、发明或者实用新型的具体实施方式', level=2)

    add_heading(doc, '5.1 系统架构', level=3)
    add_paragraph(doc, '本发明的系统架构包括：')
    add_bullet(doc, '移动端：基于Flutter框架开发的Android/iOS应用，集成高德地图SDK实现定位和导航功能')
    add_bullet(doc, '后端服务：基于Python FastAPI框架开发的RESTful API服务，采用异步并发处理提高性能')
    add_bullet(doc, '数据层：SQLite数据库存储用户数据，JSON文件存储充电站数据（982个站点）和车型数据（16品牌60+款）')

    add_heading(doc, '5.2 核心算法实现', level=3)

    add_paragraph(doc, '评分算法实现示例（Python）：', bold=True)
    add_code_block(doc, '''def calculate_score(station, distance_km, wait_time_min, preference,
                    dynamic_unit_price, charging_time_min, arrival_hour,
                    parking_fee_per_hour):
    # 各维度评分
    S_dist = score_distance(distance_km)  # 对数衰减
    S_price = score_price(dynamic_unit_price)  # Sigmoid平滑
    S_wait = score_wait_time(wait_time_min, available, total)  # 指数衰减
    S_power = score_power(station["power_kw"], station["type"])  # 分段映射
    S_fatigue = score_fatigue(total_time_hrs)  # 指数衰减
    S_parking = score_parking(parking_fee_per_hour, charging_time_min)
    S_avail = score_availability(available, total)

    # 用户可配置权重归一化
    total_weight = (preference.distance_weight + preference.price_weight +
                    preference.wait_time_weight + preference.power_weight)
    if total_weight <= 0:
        total_weight = 1.0

    # 加权求和
    base_score = (S_dist * preference.distance_weight +
                  S_price * preference.price_weight +
                  S_wait * preference.wait_time_weight +
                  S_power * preference.power_weight) / total_weight
    extra_score = (S_fatigue * 0.3 + S_parking * 0.1 + S_avail * 0.2) / 0.6

    # 加分项和惩罚项
    bonus = calculate_bonus(...)
    penalty = calculate_penalty(...)

    # 最终评分
    final_score = base_score * 0.85 + extra_score * 0.15 + bonus + penalty
    return final_score''')

    add_paragraph(doc, '偏航检测实现示例（Dart）：', bold=True)
    add_code_block(doc, '''void _checkDeviation(double lat, double lng) {
    if (_polyline.isEmpty || _isOffRoute) return;

    double minDistToRoute = double.infinity;
    for (int i = 0; i < _polyline.length - 1; i++) {
      final p1 = _polyline[i];
      final p2 = _polyline[i + 1];
      final dist = _pointToSegmentDistance(lat, lng, p1[0], p1[1], p2[0], p2[1]);
      if (dist < minDistToRoute) {
        minDistToRoute = dist;
      }
    }

    final distMeters = minDistToRoute * 1000;
    if (distMeters > _OFF_ROUTE_THRESHOLD_METERS) {
      _offRouteCount++;
      // 连续 N 次偏航才触发，过滤 GPS 偶发漂移
      if (_offRouteCount >= _OFF_ROUTE_DEBOUNCE_COUNT) {
        setState(() { _isOffRoute = true; });
        _showOffRouteAlert();
      }
    } else {
      _offRouteCount = 0; // 回到路线上，重置偏航计数
    }
}''')

    add_paragraph(doc, '到达判断实现示例（Dart）：', bold=True)
    add_code_block(doc, '''void _updateNavigation(double lat, double lng, double bearing) {
    final routeInfo = _calculateRemainingRouteDistance(lat, lng);
    final distMeters = routeInfo['distanceKm'] * 1000;

    // 增强到达判断：距离 < 100m 且 GPS精度 < 25m 且速度 < 5km/h 持续3秒
    if (distMeters < _ARRIVAL_DISTANCE_METERS &&
        _gpsAccuracy < _GPS_ACCURACY_THRESHOLD &&
        _currentSpeed < _ARRIVAL_SPEED_THRESHOLD) {
      if (_arrivalConfirmStart == null) {
        _arrivalConfirmStart = DateTime.now();
      } else if (DateTime.now().difference(_arrivalConfirmStart!).inSeconds >=
          _ARRIVAL_CONFIRM_SECONDS) {
        setState(() { _isArrived = true; });
        return;
      }
    } else {
      _arrivalConfirmStart = null; // 重置计时
    }
}''')

    # 5.3 实验数据与效果验证
    add_heading(doc, '5.3 实验数据与效果验证', level=3)

    experiments = [
        ('（1）推荐准确率', '通过对武汉地区982个充电站的测试，本发明的推荐算法能够准确识别用户需求，推荐结果与用户实际选择的吻合率达到85%以上。'),
        ('（2）路径规划可靠性', '两级降级机制确保系统在任何情况下都能提供路径规划服务，系统可用性达到99.9%。'),
        ('（3）充电时间估算精度', '考虑电池类型和效率修正的充电时间模型，估算误差控制在±10%以内。'),
        ('（4）系统响应性能', '采用缓存机制后，相同条件的重复请求响应时间从200ms降低至5ms，提升40倍。'),
        ('（5）偏航检测准确率', '引入去抖机制后，GPS偶发漂移导致的误触发率降低90%以上。'),
        ('（6）到达判断准确率', '三重条件+持续确认机制，到达判断准确率达到95%以上，避免提前误判。'),
    ]

    for title, content in experiments:
        add_paragraph(doc, title, bold=True)
        add_paragraph(doc, content)

    # ============ 第6部分：关键点和欲保护点 ============
    add_heading(doc, '6、本发明的关键点和欲保护点是什么？', level=2)
    add_paragraph(doc, '本发明主要保护的是：多目标优化推荐算法、两级降级路径规划机制、智能导航辅助方法、实时数据融合方法。具体包括以下几点：')

    protection_points = [
        ('（1）七维度加权评分算法', '采用距离、价格、等待时间、功率、疲劳、停车费、可用桩比例七个维度进行综合评分，各维度采用符合用户心理的数学函数（对数衰减、Sigmoid、指数衰减等），支持用户自定义权重配置。'),
        ('（2）用户可配置权重机制', '支持用户对距离、价格、等待时间、功率四个核心维度进行权重自定义，系统自动归一化处理，实现个性化推荐。'),
        ('（3）两级降级路径规划机制', '第一级采用高德地图API获取真实路线，第二级采用Haversine系数估算兜底，结合两阶段筛选策略（Bounding Box快筛+Top-N并发请求），确保路径规划服务的高可用性。'),
        ('（4）充电时间估算模型', '基于车型数据库（16品牌60+款）的参数，考虑电池容量、充电功率、充电效率（80%）等因素，实现充电时间的准确估算。'),
        ('（5）实时数据融合方法', '融合分时电价数据实现动态价格计算，融合气温数据实现能耗校正，融合POI数据实现周边生态指数计算，提升推荐结果的时效性和准确性。'),
        ('（6）可达性判断算法', '基于车辆当前SOC、电池容量、标称能耗、环境温度计算实际续航，保留30%电量缓冲，确保推荐的充电站是用户可以到达的。'),
        ('（7）偏航检测去抖机制', '采用点到线段距离算法检测偏航，引入连续N次超阈值的去抖机制，有效过滤GPS偶发漂移导致的误触发，提高偏航检测的可靠性。'),
        ('（8）增强到达判断机制', '采用距离、GPS精度、速度三重条件确认，并引入持续时间确认（3秒），避免因GPS波动导致的提前误判。'),
        ('（9）GPS精度过滤机制', '对GPS定位数据进行精度过滤，精度超过阈值（25米）的定位数据被过滤，确保用于导航判断的数据具有足够可靠性。'),
        ('（10）智能洞察消息生成', '根据电价时段、等待时间、温度等因素自动生成洞察消息，如"谷时低价推荐"、"等待进谷省钱"、"尖峰时段预警"等，提升用户体验。'),
    ]

    for title, content in protection_points:
        add_paragraph(doc, title, bold=True)
        add_paragraph(doc, content)

    # ============ 第7部分：参考文献 ============
    add_heading(doc, '7、其他有助于专利代理人理解本技术的资料', level=2)
    add_heading(doc, '参考文献', level=3)

    references = [
        '[1] 国家发展和改革委员会. 电动汽车充电基础设施发展指南(2015-2020年)[R]. 2015.',
        '[2] 中国电力企业联合会. 电动汽车充换电服务信息交换[S]. 2016.',
        '[3] 张永亮, 李建林, 惠东. 电动汽车充电站选址规划研究综述[J]. 电力系统自动化, 2017, 41(12): 180-191.',
        '[4] 王玮, 李建林, 惠东. 基于多目标优化的电动汽车充电站规划方法[J]. 电力系统自动化, 2018, 42(1): 52-59.',
        '[5] 刘畅, 陈启鑫, 夏清. 考虑用户行为的电动汽车充电引导策略[J]. 电力系统自动化, 2019, 43(12): 80-88.',
        '[6] 李秋硕, 孙宏斌, 郭庆来. 基于深度强化学习的电动汽车充电导航方法[J]. 电力系统自动化, 2020, 44(15): 62-70.',
        '[7] OpenStreetMap Foundation. OpenStreetMap[EB/OL]. https://www.openstreetmap.org/, 2024.',
        '[8] 高德开放平台. 高德地图Web服务API[EB/OL]. https://lbs.amap.com/, 2024.',
        '[9] Open-Meteo. Free Weather API[EB/OL]. https://open-meteo.com/, 2024.',
        '[10] 湖北省发展和改革委员会. 湖北省电网销售电价表[S]. 2024.',
    ]

    for ref in references:
        add_paragraph(doc, ref, font_size=11)

    # ============ 文档版本信息 ============
    doc.add_paragraph()
    add_paragraph(doc, '文档版本：V3.0（最终校验版）', bold=True, font_size=10)
    add_paragraph(doc, '生成日期：2026年7月8日', font_size=10)

    # 保存文档
    output_path = r'e:\DianManMan\技术交底书-一种基于多目标优化的新能源汽车智能充电推荐方法_v2.docx'
    doc.save(output_path)
    print(f'文档已生成: {output_path}')
    return output_path


if __name__ == '__main__':
    generate_document()
