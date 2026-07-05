from typing import List, Dict, Optional

class VehicleRepository:
    def __init__(self):
        self._db = {
            "特斯拉": {
                "Model 3 标准续航": {"battery": 60, "consumption": 13, "max_charge_power": 120, "battery_type": "磷酸铁锂"},
                "Model 3 长续航": {"battery": 78, "consumption": 14, "max_charge_power": 250, "battery_type": "三元锂"},
                "Model 3 高性能": {"battery": 78, "consumption": 15, "max_charge_power": 250, "battery_type": "三元锂"},
                "Model Y 标准续航": {"battery": 60, "consumption": 14, "max_charge_power": 120, "battery_type": "磷酸铁锂"},
                "Model Y 长续航": {"battery": 78, "consumption": 15, "max_charge_power": 250, "battery_type": "三元锂"},
                "Model Y 高性能": {"battery": 78, "consumption": 16, "max_charge_power": 250, "battery_type": "三元锂"},
                "Model S": {"battery": 100, "consumption": 18, "max_charge_power": 250, "battery_type": "三元锂"},
                "Model X": {"battery": 100, "consumption": 20, "max_charge_power": 250, "battery_type": "三元锂"},
            },
            "比亚迪": {
                "汉 EV 标准续航": {"battery": 76.9, "consumption": 14, "max_charge_power": 120, "battery_type": "磷酸铁锂"},
                "汉 EV 超长续航": {"battery": 85.4, "consumption": 14, "max_charge_power": 120, "battery_type": "磷酸铁锂"},
                "秦 Plus EV": {"battery": 57, "consumption": 13, "max_charge_power": 90, "battery_type": "磷酸铁锂"},
                "唐 EV": {"battery": 86.4, "consumption": 17, "max_charge_power": 120, "battery_type": "磷酸铁锂"},
                "海豹": {"battery": 82.5, "consumption": 14, "max_charge_power": 150, "battery_type": "三元锂"},
                "海豚": {"battery": 44.9, "consumption": 12, "max_charge_power": 60, "battery_type": "磷酸铁锂"},
                "元 Plus": {"battery": 60.48, "consumption": 13, "max_charge_power": 80, "battery_type": "磷酸铁锂"},
            },
            "蔚来": {
                "ET5": {"battery": 75, "consumption": 15, "max_charge_power": 180, "battery_type": "三元锂"},
                "ET7": {"battery": 100, "consumption": 16, "max_charge_power": 180, "battery_type": "三元锂"},
                "ES6": {"battery": 75, "consumption": 17, "max_charge_power": 180, "battery_type": "三元锂"},
                "ES8": {"battery": 100, "consumption": 19, "max_charge_power": 180, "battery_type": "三元锂"},
                "EC6": {"battery": 75, "consumption": 17, "max_charge_power": 180, "battery_type": "三元锂"},
            },
            "小鹏": {
                "P7 标准续航": {"battery": 60.2, "consumption": 14, "max_charge_power": 120, "battery_type": "磷酸铁锂"},
                "P7 长续航": {"battery": 80.9, "consumption": 14, "max_charge_power": 120, "battery_type": "三元锂"},
                "P5": {"battery": 66.2, "consumption": 13, "max_charge_power": 120, "battery_type": "磷酸铁锂"},
                "G3i": {"battery": 57.5, "consumption": 14, "max_charge_power": 90, "battery_type": "磷酸铁锂"},
                "G9": {"battery": 98, "consumption": 16, "max_charge_power": 480, "battery_type": "三元锂"},
            },
            "理想": {
                "理想 ONE": {"battery": 40.5, "consumption": 16, "max_charge_power": 60, "battery_type": "三元锂"},
                "理想 L7": {"battery": 42.8, "consumption": 17, "max_charge_power": 60, "battery_type": "三元锂"},
                "理想 L8": {"battery": 42.8, "consumption": 17, "max_charge_power": 60, "battery_type": "三元锂"},
                "理想 L9": {"battery": 44.5, "consumption": 18, "max_charge_power": 60, "battery_type": "三元锂"},
            },
            "广汽埃安": {
                "AION S": {"battery": 59.4, "consumption": 13, "max_charge_power": 100, "battery_type": "磷酸铁锂"},
                "AION V": {"battery": 80, "consumption": 15, "max_charge_power": 120, "battery_type": "三元锂"},
                "AION LX": {"battery": 93.3, "consumption": 17, "max_charge_power": 150, "battery_type": "三元锂"},
                "AION Y": {"battery": 63.98, "consumption": 13, "max_charge_power": 80, "battery_type": "磷酸铁锂"},
            },
            "极氪": {
                "001 超长续航": {"battery": 100, "consumption": 17, "max_charge_power": 360, "battery_type": "三元锂"},
                "001 长续航": {"battery": 86, "consumption": 16, "max_charge_power": 360, "battery_type": "三元锂"},
                "007": {"battery": 100, "consumption": 15, "max_charge_power": 360, "battery_type": "三元锂"},
                "X": {"battery": 66, "consumption": 14, "max_charge_power": 150, "battery_type": "三元锂"},
            },
            "吉利": {
                "几何A": {"battery": 70, "consumption": 13, "max_charge_power": 120, "battery_type": "三元锂"},
                "几何C": {"battery": 70, "consumption": 14, "max_charge_power": 120, "battery_type": "三元锂"},
                "星越L HiP": {"battery": 41.2, "consumption": 18, "max_charge_power": 60, "battery_type": "三元锂"},
            },
            "大众": {
                "ID.3": {"battery": 57.3, "consumption": 14, "max_charge_power": 100, "battery_type": "三元锂"},
                "ID.4": {"battery": 83.4, "consumption": 16, "max_charge_power": 150, "battery_type": "三元锂"},
                "ID.6": {"battery": 84.8, "consumption": 17, "max_charge_power": 150, "battery_type": "三元锂"},
                "高尔夫纯电": {"battery": 40, "consumption": 15, "max_charge_power": 50, "battery_type": "三元锂"},
            },
            "宝马": {
                "i3": {"battery": 70, "consumption": 15, "max_charge_power": 100, "battery_type": "三元锂"},
                "iX3": {"battery": 80, "consumption": 17, "max_charge_power": 150, "battery_type": "三元锂"},
                "i4": {"battery": 83.9, "consumption": 16, "max_charge_power": 200, "battery_type": "三元锂"},
                "iX": {"battery": 111.5, "consumption": 20, "max_charge_power": 200, "battery_type": "三元锂"},
            },
            "奔驰": {
                "EQC": {"battery": 79.2, "consumption": 20, "max_charge_power": 110, "battery_type": "三元锂"},
                "EQS": {"battery": 111.8, "consumption": 18, "max_charge_power": 200, "battery_type": "三元锂"},
                "EQA": {"battery": 73.5, "consumption": 17, "max_charge_power": 100, "battery_type": "三元锂"},
            },
            "奥迪": {
                "e-tron": {"battery": 96.7, "consumption": 21, "max_charge_power": 150, "battery_type": "三元锂"},
                "Q4 e-tron": {"battery": 84.8, "consumption": 17, "max_charge_power": 150, "battery_type": "三元锂"},
                "Q5 e-tron": {"battery": 83.4, "consumption": 18, "max_charge_power": 150, "battery_type": "三元锂"},
            },
            "通用": {
                "微蓝6": {"battery": 61.1, "consumption": 14, "max_charge_power": 120, "battery_type": "三元锂"},
                "微蓝7": {"battery": 68, "consumption": 15, "max_charge_power": 120, "battery_type": "三元锂"},
                "凯迪拉克 LYRIQ": {"battery": 95.7, "consumption": 18, "max_charge_power": 150, "battery_type": "三元锂"},
            },
            "小米": {
                "SU7 Max": {"battery": 101, "consumption": 15.8, "max_charge_power": 350, "battery_type": "三元锂"},
                "SU7 标准版": {"battery": 73.6, "consumption": 14.5, "max_charge_power": 200, "battery_type": "磷酸铁锂"},
                "SU7 Pro": {"battery": 94.3, "consumption": 14.8, "max_charge_power": 250, "battery_type": "三元锂"},
            },
            "华为问界": {
                "问界 M5 EV": {"battery": 80, "consumption": 16, "max_charge_power": 120, "battery_type": "三元锂"},
                "问界 M7": {"battery": 40, "consumption": 18, "max_charge_power": 60, "battery_type": "三元锂"},
            },
            "其他": {
                "默认车型": {"battery": 60, "consumption": 15, "max_charge_power": 120, "battery_type": "三元锂"},
            }
        }

    def get_all_brands(self) -> List[str]:
        return list(self._db.keys())

    def get_models_by_brand(self, brand: str) -> Optional[Dict[str, Dict]]:
        return self._db.get(brand)

    def get_vehicle_specs(self, brand: str, model: str) -> Optional[Dict]:
        models = self.get_models_by_brand(brand)
        if models:
            return models.get(model)
        return None

vehicle_repo = VehicleRepository()
