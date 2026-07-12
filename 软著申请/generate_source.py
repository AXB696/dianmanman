import os

SOFTWARE_NAME = "电满满新能源充电导航综合管理平台"
VERSION = "V1.0"
LINES_PER_PAGE = 50
TOTAL_PAGES = 60  # 前30页 + 后30页
TOTAL_LINES = LINES_PER_PAGE * TOTAL_PAGES

PROJECT_ROOT = r"c:\Users\28773\Desktop\DianManMan"

# 源代码文件（按模块、按重要程度排序）
SOURCE_FILES = [
    # 后端核心
    "backend_v2/app/main.py",
    "backend_v2/app/core/config.py",
    "backend_v2/app/core/security.py",
    "backend_v2/app/core/dependencies.py",
    "backend_v2/app/core/database.py",
    "backend_v2/app/core/exceptions.py",
    "backend_v2/app/api/v1/auth.py",
    "backend_v2/app/api/v1/users.py",
    "backend_v2/app/api/v1/favorites.py",
    "backend_v2/app/api/v1/history.py",
    "backend_v2/app/api/v1/stations.py",
    "backend_v2/app/api/v1/recommend.py",
    "backend_v2/app/api/v1/navigation.py",
    "backend_v2/app/api/v1/admin.py",
    "backend_v2/app/api/v1/admin_extended.py",
    "backend_v2/app/api/v1/admin_users.py",
    "backend_v2/app/api/v1/announcements.py",
    "backend_v2/app/api/v1/router.py",
    "backend_v2/app/models/user.py",
    "backend_v2/app/models/vehicle.py",
    "backend_v2/app/models/favorite.py",
    "backend_v2/app/models/history.py",
    "backend_v2/app/models/announcement.py",
    "backend_v2/app/schemas/auth.py",
    "backend_v2/app/schemas/history.py",
    "backend_v2/app/schemas/favorite.py",
    "backend_v2/app/schemas/announcement.py",
    "backend_v2/app/schemas/response.py",
    "backend_v2/app/repositories/station_repo.py",
    "backend_v2/app/repositories/vehicle_repo.py",
    # App 核心服务层
    "app_v2/lib/services/data_repository.dart",
    "app_v2/lib/services/local_storage.dart",
    "app_v2/lib/services/api_client.dart",
    "app_v2/lib/services/auth_service.dart",
    "app_v2/lib/services/vehicle_data.dart",
    # App 主要页面（home.dart 太大，取一部分）
    "app_v2/lib/main.dart",
    "app_v2/lib/pages/login_page.dart",
    "app_v2/lib/pages/register_page.dart",
    # App 主页取部分
    "app_v2/lib/home.dart",
]

# 收集所有代码行
all_lines = []
for rel_path in SOURCE_FILES:
    abs_path = os.path.join(PROJECT_ROOT, rel_path)
    if not os.path.exists(abs_path):
        continue
    with open(abs_path, "r", encoding="utf-8", errors="ignore") as f:
        lines = f.readlines()
    # 跳过空行过多的部分，保留注释和代码
    all_lines.append(f"\n// ====== 文件: {rel_path} ======\n")
    for line in lines:
        # 去掉行尾空白但保留行首缩进
        clean = line.rstrip()
        if clean == "":
            clean = " "  # 保留空行但占位
        all_lines.append(clean + "\n")

# 如果不够 3000 行，从 home.dart 中多取一些
if len(all_lines) < TOTAL_LINES:
    home_path = os.path.join(PROJECT_ROOT, "app_v2/lib/home.dart")
    if os.path.exists(home_path):
        with open(home_path, "r", encoding="utf-8", errors="ignore") as f:
            extra = f.readlines()
        # 从第 2000 行开始取
        start = min(2000, len(extra))
        for line in extra[start:]:
            clean = line.rstrip()
            if clean == "":
                clean = " "
            all_lines.append(clean + "\n")
            if len(all_lines) >= TOTAL_LINES * 2:
                break

# 截取到目标行数
total = min(len(all_lines), TOTAL_LINES * 2)
all_lines = all_lines[:TOTAL_LINES]

# 分页输出
output_path = os.path.join(PROJECT_ROOT, "软著申请", "源代码前后30页", "源代码文档.txt")
with open(output_path, "w", encoding="utf-8") as f:
    line_idx = 0
    for page in range(1, TOTAL_PAGES + 1):
        f.write(f"{'='*70}\n")
        f.write(f"   {SOFTWARE_NAME} {VERSION} \n")
        f.write(f"   源代码文档 - 第 {page} / {TOTAL_PAGES} 页\n")
        f.write(f"{'='*70}\n\n")
        
        line_start = (page - 1) * LINES_PER_PAGE
        line_end = min(line_start + LINES_PER_PAGE, total)
        
        for i in range(line_start, line_end):
            if i < len(all_lines):
                f.write(all_lines[i])
        
        # 不足50行时补齐
        for i in range(line_end - line_start, LINES_PER_PAGE):
            f.write(" \n")
        
        f.write(f"\n{'='*70}\n")
        if page < TOTAL_PAGES:
            f.write("\f\n")  # 换页符

print(f"生成完成: {total} 行, {TOTAL_PAGES} 页")
print(f"输出: {output_path}")
