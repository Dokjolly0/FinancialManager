package com.alexviolatto.financialmanager

import android.app.ActivityManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.PowerManager
import android.os.StatFs
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // On-device AI (plan.md section 33): memory, storage, heat and
        // battery, to tell whether a model fits and when to hold a run.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "financialmanager/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "capabilities" ->
                        try {
                            result.success(capabilities())
                        } catch (e: Exception) {
                            result.error("DEVICE", e.toString(), null)
                        }
                    else -> result.notImplemented()
                }
            }
    }

    private fun capabilities(): Map<String, Any?> {
        val am = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val mi = ActivityManager.MemoryInfo().also { am.getMemoryInfo(it) }
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        val battery = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val level = battery?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = battery?.getIntExtra(BatteryManager.EXTRA_SCALE, 100) ?: 100
        val plugged = battery?.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) ?: 0
        return mapOf(
            "total_mem" to mi.totalMem,
            "avail_mem" to mi.availMem,
            "low_memory" to mi.lowMemory,
            "free_storage" to StatFs(filesDir.path).availableBytes,
            "thermal_status" to if (Build.VERSION.SDK_INT >= 29) pm.currentThermalStatus else null,
            "battery_pct" to if (level >= 0 && scale > 0) level * 100 / scale else null,
            "charging" to (plugged != 0),
            "soc_manufacturer" to if (Build.VERSION.SDK_INT >= 31) Build.SOC_MANUFACTURER else null,
            "soc_model" to if (Build.VERSION.SDK_INT >= 31) Build.SOC_MODEL else Build.HARDWARE,
            "sdk" to Build.VERSION.SDK_INT,
        )
    }
}
