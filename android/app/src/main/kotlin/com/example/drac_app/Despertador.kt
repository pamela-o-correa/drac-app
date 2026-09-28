package com.example.drac_app

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.*
import org.json.JSONArray
import org.json.JSONObject

object Despertador {
    private fun prefs(c: Context) = c.getSharedPreferences("despertador", Context.MODE_PRIVATE)
    private fun manager(c: Context) = c.getSystemService(AlarmManager::class.java)
    fun ativo(c: Context) = prefs(c).getBoolean("ativo", false)
    fun permitido(c: Context): Boolean =
        (Build.VERSION.SDK_INT < 31 || manager(c).canScheduleExactAlarms()) &&
        (Build.VERSION.SDK_INT < 33 || c.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) &&
        c.getSystemService(NotificationManager::class.java).areNotificationsEnabled()

    private fun doses(c: Context) = JSONArray(prefs(c).getString("doses", "[]"))
    private fun pending(c: Context, id: Int, quando: Long = 0): PendingIntent = PendingIntent.getBroadcast(
        c, id, Intent(c, DoseReceiver::class.java).putExtra("id", id).putExtra("quando", quando),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun avisoPending(c: Context, id: Int, quando: Long = 0): PendingIntent = PendingIntent.getBroadcast(
        c, id, Intent(c, DoseReceiver::class.java).setAction("antecedencia")
            .putExtra("id", id).putExtra("quando", quando),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    fun proximo(dose: JSONObject): Long? = AgendaDose.proximo(
        dose.getString("horario"), dose.optString("data_inicio", ""), dose.optString("data_fim", ""))
    private fun agendar(c: Context, dose: JSONObject) {
        val quando = proximo(dose) ?: return
        val abrir = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        manager(c).setAlarmClock(AlarmManager.AlarmClockInfo(quando, abrir), pending(c, dose.getInt("id"), quando))
        manager(c).cancel(avisoPending(c, dose.getInt("id")))
        AgendaDose.antecedencia(quando)?.let { antes ->
            manager(c).setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, antes,
                avisoPending(c, dose.getInt("id"), quando))
        }
    }

    @Synchronized fun sincronizar(c: Context, novas: JSONArray? = null, habilitar: Boolean? = null) {
        val lista = novas ?: doses(c)
        // Valide tudo antes de modificar os alarmes existentes.
        for (i in 0 until lista.length()) proximo(lista.getJSONObject(i))
        if (habilitar == true && !permitido(c)) error("Autorize notificações e alarmes")
        val antigas = doses(c)
        for (i in 0 until antigas.length()) {
            val id = antigas.getJSONObject(i).getInt("id")
            manager(c).cancel(pending(c, id))
            manager(c).cancel(avisoPending(c, id))
            c.getSystemService(NotificationManager::class.java).cancel("antecedencia/$id", 2)
        }
        prefs(c).edit().putString("doses", lista.toString())
            .putBoolean("ativo", habilitar ?: ativo(c)).commit()
        if (!ativo(c)) c.stopService(Intent(c, SomService::class.java))
        if (ativo(c) && permitido(c)) {
            for (i in 0 until lista.length()) agendar(c, lista.getJSONObject(i))
        }
    }

    fun avisar(c: Context, id: Int, quando: Long) {
        if (!ativo(c) || !permitido(c) || quando <= System.currentTimeMillis()) return
        val lista = doses(c)
        for (i in 0 until lista.length()) {
            val dose = lista.getJSONObject(i)
            if (dose.getInt("id") != id) continue
            dose.put("data", java.text.SimpleDateFormat("dd/MM/yyyy", java.util.Locale.ROOT).format(java.util.Date(quando)))
            if (RegistroDose.administrada(c, dose)) return
            val nm = c.getSystemService(NotificationManager::class.java)
            if (Build.VERSION.SDK_INT >= 26) nm.createNotificationChannel(
                NotificationChannel("antecedencia", "Aviso 10 minutos antes", NotificationManager.IMPORTANCE_DEFAULT))
            val abrir = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, "antecedencia") else Notification.Builder(c)
            val texto = "${dose.getString("nome")} • ${dose.optString("dose")} ${dose.optString("unidade")} às ${dose.getString("horario")}. Prepare a dose do Drác."
            builder.setSmallIcon(R.drawable.ic_stat_drac).setContentTitle("Dose em 10 minutos")
                .setContentText(texto).setStyle(Notification.BigTextStyle().bigText(texto))
                .setContentIntent(abrir).setAutoCancel(true).setCategory(Notification.CATEGORY_REMINDER)
            if (Build.VERSION.SDK_INT >= 26) builder.setTimeoutAfter(quando - System.currentTimeMillis())
            else builder.setDefaults(Notification.DEFAULT_SOUND)
            nm.notify("antecedencia/$id", 2, builder.build())
            return
        }
    }

    fun disparar(c: Context, id: Int, quando: Long) {
        if (!ativo(c) || !permitido(c)) return
        val lista = doses(c)
        for (i in 0 until lista.length()) {
            val dose = lista.getJSONObject(i)
            if (dose.getInt("id") == id) {
                c.getSystemService(NotificationManager::class.java).cancel("antecedencia/$id", 2)
                agendar(c, dose)
                dose.put("data", java.text.SimpleDateFormat("dd/MM/yyyy", java.util.Locale.ROOT)
                    .format(java.util.Date(if (quando > 0) quando else System.currentTimeMillis())))
                if (!RegistroDose.administrada(c, dose)) {
                    RegistroDose.notificar(c, dose)
                    tocar(c, "${dose.getString("nome")} • ${dose.optString("dose")} ${dose.optString("unidade", "")}")
                }
                return
            }
        }
    }

    fun tocar(c: Context, texto: String) {
        val intent = Intent(c, SomService::class.java).putExtra("texto", texto)
        if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(intent) else c.startService(intent)
    }
}

class DoseReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            val id = intent.getIntExtra("id", -1)
            val quando = intent.getLongExtra("quando", 0)
            if (intent.action == "antecedencia") Despertador.avisar(context, id, quando)
            else Despertador.disparar(context, id, quando)
        }
        catch (e: Exception) { android.util.Log.e("DracAlarm", "Falha ao disparar", e) }
    }
}

class RestaurarAlarmesReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try { Despertador.sincronizar(context) }
        catch (e: Exception) { android.util.Log.e("DracAlarm", "Falha ao restaurar", e) }
    }
}

class SomService : Service() {
    private var player: MediaPlayer? = null
    private val mensagens = linkedSetOf<String>()
    private val handler = Handler(Looper.getMainLooper())
    private val parar = Runnable { stopSelf() }
    override fun onBind(intent: Intent?) = null
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "parar") { stopSelf(); return START_NOT_STICKY }
        val manager = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel("despertador", "Despertador das doses", NotificationManager.IMPORTANCE_HIGH).apply {
                setSound(null, null)
                description = "Aviso enquanto o despertador está tocando"
            })
        }
        val stop = PendingIntent.getService(this, 0, Intent(this, SomService::class.java).setAction("parar"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val abrir = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        mensagens.add(intent?.getStringExtra("texto") ?: "Despertador")
        val texto = mensagens.joinToString("; ")
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, "despertador") else Notification.Builder(this)
        val notification = builder.setSmallIcon(R.drawable.ic_stat_drac)
            .setContentTitle("Hora da dose do Drác")
            .setContentText(texto).setStyle(Notification.BigTextStyle().bigText(texto))
            .setContentIntent(abrir).setCategory(Notification.CATEGORY_ALARM)
            .setOngoing(true).setVisibility(Notification.VISIBILITY_PUBLIC)
            .addAction(Notification.Action.Builder(null, "Parar som", stop).build()).build()
        startForeground(700001, notification)
        if (player == null) {
            try {
                player = MediaPlayer().apply {
                    setAudioAttributes(AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build())
                    setDataSource(this@SomService, RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION))
                    isLooping = true
                    setWakeMode(this@SomService, PowerManager.PARTIAL_WAKE_LOCK)
                    prepare(); start()
                }
            } catch (e: Exception) {
                android.util.Log.e("DracAlarm", "Falha no som", e)
                stopSelf()
            }
        }
        handler.removeCallbacks(parar)
        handler.postDelayed(parar, 5 * 60 * 1000L)
        return START_NOT_STICKY
    }
    override fun onDestroy() {
        handler.removeCallbacks(parar)
        player?.release(); player = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        super.onDestroy()
    }
}


