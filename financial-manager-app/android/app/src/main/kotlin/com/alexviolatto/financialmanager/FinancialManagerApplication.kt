package com.alexviolatto.financialmanager

import android.app.Application
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * Starts the Flutter engine with the process and keeps it in the cache, so
 * it outlives MainActivity: a model download or an on-device analysis
 * running in the foreground service (plan.md section 33.9) goes on when
 * the user swipes the app away from the recents, and reopening the app
 * attaches to the same engine instead of starting a second one.
 */
class FinancialManagerApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        val engine = FlutterEngine(this)
        engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
        FlutterEngineCache.getInstance().put(ENGINE_ID, engine)
    }

    companion object {
        const val ENGINE_ID = "main"
    }
}
