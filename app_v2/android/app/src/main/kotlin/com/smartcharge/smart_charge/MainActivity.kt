package com.smartcharge.smart_charge

import android.os.Bundle
import com.amap.api.location.AMapLocationClient
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // 高德定位 SDK 隐私合规——必须在任何定位客户端创建之前调用
        AMapLocationClient.updatePrivacyShow(this, true, true)
        AMapLocationClient.updatePrivacyAgree(this, true)

        // 允许采集个人及设备信息（新版 SDK 必需）
        try {
            val clazz = Class.forName("com.amap.api.track.AMapUtilCoreApi")
            val method = clazz.getMethod("setCollectInfoEnable", Boolean::class.javaPrimitiveType)
            method.invoke(null, true)
        } catch (e: Exception) {
            // SDK 版本可能不支持此接口，忽略
        }

        super.onCreate(savedInstanceState)
    }
}
