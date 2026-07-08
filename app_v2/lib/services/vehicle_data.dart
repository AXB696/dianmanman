/// 车型数据库 —— 与后台 backend_v2/app/repositories/vehicle_repo.py 保持一致
/// 结构：品牌 → 车型列表，每个车型含 battery(kWh)、consumption(kWh/100km)、max_charge_power(kW)、battery_type
class VehicleData {
  static const Map<String, List<Map<String, dynamic>>> brands = {
    "特斯拉": [
      {"model": "Model 3 标准续航", "battery": 60, "consumption": 13, "max_charge_power": 120, "battery_type": "磷酸铁锂"},
      {"model": "Model 3 长续航", "battery": 78, "consumption": 14, "max_charge_power": 250, "battery_type": "三元锂"},
      {"model": "Model 3 高性能", "battery": 78, "consumption": 15, "max_charge_power": 250, "battery_type": "三元锂"},
      {"model": "Model Y 标准续航", "battery": 60, "consumption": 14, "max_charge_power": 120, "battery_type": "磷酸铁锂"},
      {"model": "Model Y 长续航", "battery": 78, "consumption": 15, "max_charge_power": 250, "battery_type": "三元锂"},
      {"model": "Model Y 高性能", "battery": 78, "consumption": 16, "max_charge_power": 250, "battery_type": "三元锂"},
      {"model": "Model S", "battery": 100, "consumption": 18, "max_charge_power": 250, "battery_type": "三元锂"},
      {"model": "Model X", "battery": 100, "consumption": 20, "max_charge_power": 250, "battery_type": "三元锂"},
    ],
    "比亚迪": [
      {"model": "汉 EV 标准续航", "battery": 76.9, "consumption": 14, "max_charge_power": 120, "battery_type": "磷酸铁锂"},
      {"model": "汉 EV 超长续航", "battery": 85.4, "consumption": 14, "max_charge_power": 120, "battery_type": "磷酸铁锂"},
      {"model": "秦 Plus EV", "battery": 57, "consumption": 13, "max_charge_power": 90, "battery_type": "磷酸铁锂"},
      {"model": "唐 EV", "battery": 86.4, "consumption": 17, "max_charge_power": 120, "battery_type": "磷酸铁锂"},
      {"model": "海豹", "battery": 82.5, "consumption": 14, "max_charge_power": 150, "battery_type": "三元锂"},
      {"model": "海豚", "battery": 44.9, "consumption": 12, "max_charge_power": 60, "battery_type": "磷酸铁锂"},
      {"model": "元 Plus", "battery": 60.48, "consumption": 13, "max_charge_power": 80, "battery_type": "磷酸铁锂"},
    ],
    "蔚来": [
      {"model": "ET5", "battery": 75, "consumption": 15, "max_charge_power": 180, "battery_type": "三元锂"},
      {"model": "ET7", "battery": 100, "consumption": 16, "max_charge_power": 180, "battery_type": "三元锂"},
      {"model": "ES6", "battery": 75, "consumption": 17, "max_charge_power": 180, "battery_type": "三元锂"},
      {"model": "ES8", "battery": 100, "consumption": 19, "max_charge_power": 180, "battery_type": "三元锂"},
      {"model": "EC6", "battery": 75, "consumption": 17, "max_charge_power": 180, "battery_type": "三元锂"},
    ],
    "小鹏": [
      {"model": "P7 标准续航", "battery": 60.2, "consumption": 14, "max_charge_power": 120, "battery_type": "磷酸铁锂"},
      {"model": "P7 长续航", "battery": 80.9, "consumption": 14, "max_charge_power": 120, "battery_type": "三元锂"},
      {"model": "P5", "battery": 66.2, "consumption": 13, "max_charge_power": 120, "battery_type": "磷酸铁锂"},
      {"model": "G3i", "battery": 57.5, "consumption": 14, "max_charge_power": 90, "battery_type": "磷酸铁锂"},
      {"model": "G9", "battery": 98, "consumption": 16, "max_charge_power": 480, "battery_type": "三元锂"},
    ],
    "理想": [
      {"model": "理想 ONE", "battery": 40.5, "consumption": 16, "max_charge_power": 60, "battery_type": "三元锂"},
      {"model": "理想 L7", "battery": 42.8, "consumption": 17, "max_charge_power": 60, "battery_type": "三元锂"},
      {"model": "理想 L8", "battery": 42.8, "consumption": 17, "max_charge_power": 60, "battery_type": "三元锂"},
      {"model": "理想 L9", "battery": 44.5, "consumption": 18, "max_charge_power": 60, "battery_type": "三元锂"},
    ],
    "广汽埃安": [
      {"model": "AION S", "battery": 59.4, "consumption": 13, "max_charge_power": 100, "battery_type": "磷酸铁锂"},
      {"model": "AION V", "battery": 80, "consumption": 15, "max_charge_power": 120, "battery_type": "三元锂"},
      {"model": "AION LX", "battery": 93.3, "consumption": 17, "max_charge_power": 150, "battery_type": "三元锂"},
      {"model": "AION Y", "battery": 63.98, "consumption": 13, "max_charge_power": 80, "battery_type": "磷酸铁锂"},
    ],
    "极氪": [
      {"model": "001 超长续航", "battery": 100, "consumption": 17, "max_charge_power": 360, "battery_type": "三元锂"},
      {"model": "001 长续航", "battery": 86, "consumption": 16, "max_charge_power": 360, "battery_type": "三元锂"},
      {"model": "007", "battery": 100, "consumption": 15, "max_charge_power": 360, "battery_type": "三元锂"},
      {"model": "X", "battery": 66, "consumption": 14, "max_charge_power": 150, "battery_type": "三元锂"},
    ],
    "吉利": [
      {"model": "几何A", "battery": 70, "consumption": 13, "max_charge_power": 120, "battery_type": "三元锂"},
      {"model": "几何C", "battery": 70, "consumption": 14, "max_charge_power": 120, "battery_type": "三元锂"},
      {"model": "星越L HiP", "battery": 41.2, "consumption": 18, "max_charge_power": 60, "battery_type": "三元锂"},
    ],
    "大众": [
      {"model": "ID.3", "battery": 57.3, "consumption": 14, "max_charge_power": 100, "battery_type": "三元锂"},
      {"model": "ID.4", "battery": 83.4, "consumption": 16, "max_charge_power": 150, "battery_type": "三元锂"},
      {"model": "ID.6", "battery": 84.8, "consumption": 17, "max_charge_power": 150, "battery_type": "三元锂"},
      {"model": "高尔夫纯电", "battery": 40, "consumption": 15, "max_charge_power": 50, "battery_type": "三元锂"},
    ],
    "宝马": [
      {"model": "i3", "battery": 70, "consumption": 15, "max_charge_power": 100, "battery_type": "三元锂"},
      {"model": "iX3", "battery": 80, "consumption": 17, "max_charge_power": 150, "battery_type": "三元锂"},
      {"model": "i4", "battery": 83.9, "consumption": 16, "max_charge_power": 200, "battery_type": "三元锂"},
      {"model": "iX", "battery": 111.5, "consumption": 20, "max_charge_power": 200, "battery_type": "三元锂"},
    ],
    "奔驰": [
      {"model": "EQC", "battery": 79.2, "consumption": 20, "max_charge_power": 110, "battery_type": "三元锂"},
      {"model": "EQS", "battery": 111.8, "consumption": 18, "max_charge_power": 200, "battery_type": "三元锂"},
      {"model": "EQA", "battery": 73.5, "consumption": 17, "max_charge_power": 100, "battery_type": "三元锂"},
    ],
    "奥迪": [
      {"model": "e-tron", "battery": 96.7, "consumption": 21, "max_charge_power": 150, "battery_type": "三元锂"},
      {"model": "Q4 e-tron", "battery": 84.8, "consumption": 17, "max_charge_power": 150, "battery_type": "三元锂"},
      {"model": "Q5 e-tron", "battery": 83.4, "consumption": 18, "max_charge_power": 150, "battery_type": "三元锂"},
    ],
    "通用": [
      {"model": "微蓝6", "battery": 61.1, "consumption": 14, "max_charge_power": 120, "battery_type": "三元锂"},
      {"model": "微蓝7", "battery": 68, "consumption": 15, "max_charge_power": 120, "battery_type": "三元锂"},
      {"model": "凯迪拉克 LYRIQ", "battery": 95.7, "consumption": 18, "max_charge_power": 150, "battery_type": "三元锂"},
    ],
    "小米": [
      {"model": "SU7 Max", "battery": 101, "consumption": 15.8, "max_charge_power": 350, "battery_type": "三元锂"},
      {"model": "SU7 标准版", "battery": 73.6, "consumption": 14.5, "max_charge_power": 200, "battery_type": "磷酸铁锂"},
      {"model": "SU7 Pro", "battery": 94.3, "consumption": 14.8, "max_charge_power": 250, "battery_type": "三元锂"},
    ],
    "华为问界": [
      {"model": "问界 M5 EV", "battery": 80, "consumption": 16, "max_charge_power": 120, "battery_type": "三元锂"},
      {"model": "问界 M7", "battery": 40, "consumption": 18, "max_charge_power": 60, "battery_type": "三元锂"},
    ],
    "五菱": [
      // 宏光 MINI EV 系列 —— 经典款（无快充，220V/10A家用慢充约2kW）
      {"model": "宏光 MINI EV 轻松款", "battery": 9.2, "consumption": 7.7, "max_charge_power": 2, "battery_type": "磷酸铁锂"},
      {"model": "宏光 MINI EV 马卡龙", "battery": 9.2, "consumption": 7.7, "max_charge_power": 2, "battery_type": "磷酸铁锂"},
      {"model": "宏光 MINI EV 马卡龙 长续航", "battery": 13.4, "consumption": 7.9, "max_charge_power": 2, "battery_type": "磷酸铁锂"},
      // 宏光 MINI EV GAMEBOY 系列（220V/16A，约3.3kW交流充电，无直流快充）
      {"model": "宏光 MINI EV GAMEBOY 200km", "battery": 17.3, "consumption": 8.7, "max_charge_power": 3.3, "battery_type": "磷酸铁锂"},
      {"model": "宏光 MINI EV GAMEBOY 300km", "battery": 26.5, "consumption": 8.8, "max_charge_power": 3.3, "battery_type": "磷酸铁锂"},
      // 第三代马卡龙（215km版支持约20kW直流快充）
      {"model": "宏光 MINI EV 第三代马卡龙", "battery": 17.3, "consumption": 8.0, "max_charge_power": 20, "battery_type": "磷酸铁锂"},
      // 第五代五门版（全系标配约40kW直流快充）
      {"model": "宏光 MINI EV 第五代五门版", "battery": 16.2, "consumption": 7.9, "max_charge_power": 40, "battery_type": "磷酸铁锂"},
      // 缤果 系列
      {"model": "缤果 203km", "battery": 17.3, "consumption": 10, "max_charge_power": 3.3, "battery_type": "磷酸铁锂"},
      {"model": "缤果 333km", "battery": 31.9, "consumption": 10, "max_charge_power": 3.3, "battery_type": "磷酸铁锂"},
      {"model": "缤果 410km", "battery": 37.9, "consumption": 10, "max_charge_power": 3.3, "battery_type": "磷酸铁锂"},
      {"model": "缤果 PLUS 510km", "battery": 50.6, "consumption": 11.4, "max_charge_power": 6.6, "battery_type": "磷酸铁锂"},
      // Air EV 晴空
      {"model": "Air EV 晴空 两座", "battery": 26.7, "consumption": 9.5, "max_charge_power": 2, "battery_type": "磷酸铁锂"},
      {"model": "Air EV 晴空 四座", "battery": 28.4, "consumption": 10.3, "max_charge_power": 40, "battery_type": "磷酸铁锂"},
      // Nano EV（仅慢充，可选装6.6kW高功率充电机）
      {"model": "Nano EV", "battery": 28, "consumption": 9.9, "max_charge_power": 6.6, "battery_type": "磷酸铁锂"},
      // 星光 EV（标配2C快充，同级领先的120kW充电功率）
      {"model": "星光 EV 410km", "battery": 41.9, "consumption": 11.5, "max_charge_power": 120, "battery_type": "磷酸铁锂"},
      {"model": "星光 EV 510km", "battery": 54.5, "consumption": 12.5, "max_charge_power": 120, "battery_type": "磷酸铁锂"},
    ],
  };

  /// 获取所有品牌列表
  static List<String> getBrands() => brands.keys.toList();

  /// 获取指定品牌的车型列表
  static List<Map<String, dynamic>> getModels(String brand) =>
      brands[brand] ?? [];

  /// 根据品牌和车型名查找规格
  static Map<String, dynamic>? findSpecs(String carName) {
    for (final brand in brands.keys) {
      for (final model in brands[brand]!) {
        final displayName = "${model['model']}";
        if (displayName == carName ||
            "$brand ${model['model']}" == carName) {
          return model;
        }
      }
    }
    return null;
  }
}
