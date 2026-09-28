package com.example.drac_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.app.AlarmManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    companion object {
        private var canal: MethodChannel? = null
        fun dadosAlterados() { canal?.invokeMethod("doseRegistrada", null) }
    }
    override fun onDestroy() {
        canal = null
        super.onDestroy()
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "drac/despertador").also { canal = it }.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "compartilhamento" -> {
                        getSharedPreferences("drac_shared", MODE_PRIVATE).edit()
                            .putBoolean("ativo", call.argument<Boolean>("ativo") ?: false)
                            .putString("banco", call.argument<String>("banco") ?: "drac.db").commit()
                        if (Build.VERSION.SDK_INT >= 26) getSystemService(android.app.NotificationManager::class.java)
                            .createNotificationChannel(android.app.NotificationChannel("compartilhamento", "Cuidado compartilhado", android.app.NotificationManager.IMPORTANCE_HIGH))
                        getSystemService(android.app.NotificationManager::class.java).cancelAll()
                        result.success(null)
                    }
                    "status" -> result.success(mapOf("ativo" to Despertador.ativo(this), "permitido" to Despertador.permitido(this)))
                    "permissoes" -> {
                        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 501)
                        } else if (Build.VERSION.SDK_INT >= 31 && !getSystemService(AlarmManager::class.java).canScheduleExactAlarms()) {
                            startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")))
                        } else {
                            startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                        }
                        result.success(null)
                    }
                    "sincronizar" -> {
                        val lista = JSONArray()
                        call.argument<List<Map<String, Any?>>>("doses")?.forEach { row ->
                            val obj = JSONObject()
                            row.forEach { (key, value) -> obj.put(key, value ?: "") }
                            lista.put(obj)
                        }
                        Despertador.sincronizar(this, lista, call.argument<Boolean>("ativo"))
                        result.success(null)
                    }
                    "testar" -> { check(Despertador.permitido(this)); Despertador.tocar(this, "Teste do despertador"); result.success(null) }
                    "parar" -> { stopService(Intent(this, SomService::class.java)); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("despertador", e.message, null) }
        }
    }
}
