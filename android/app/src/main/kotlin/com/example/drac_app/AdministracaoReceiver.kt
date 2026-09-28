package com.example.drac_app

import android.app.*
import android.content.*
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.os.*
import android.widget.Toast
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

/** Usa o mesmo banco do sqflite, inclusive quando o Flutter está fechado. */
object RegistroDose {
    private fun banco(c: Context) = SQLiteDatabase.openDatabase(
        c.getDatabasePath(c.getSharedPreferences("drac_shared", Context.MODE_PRIVATE).getString("banco", "drac.db") ?: "drac.db").path, null, SQLiteDatabase.OPEN_READWRITE)

    fun administrada(c: Context, dose: JSONObject): Boolean = banco(c).use { db ->
        db.rawQuery("SELECT 1 FROM administracoes WHERE medicamento_id=? AND data=? AND horario=? AND administrado=1",
            arrayOf(dose.getInt("medicamento_id").toString(), dose.getString("data"), dose.getString("horario"))).use { it.moveToFirst() }
    }

    fun salvar(c: Context, dose: JSONObject) {
        check(!c.getSharedPreferences("drac_shared", Context.MODE_PRIVATE).getBoolean("ativo", false)) { "Abra o aplicativo para confirmar a dose compartilhada" }
        banco(c).use { db ->
            db.beginTransaction()
            try {
                val id = dose.getInt("medicamento_id")
                db.rawQuery("SELECT 1 FROM medicamentos WHERE id=?", arrayOf(id.toString())).use {
                    check(it.moveToFirst()) { "Medicamento não encontrado" }
                }
                val args = arrayOf(id.toString(), dose.getString("data"), dose.getString("horario"))
                val where = "medicamento_id=? AND data=? AND horario=?"
                val existe = db.rawQuery("SELECT 1 FROM administracoes WHERE $where", args).use { it.moveToFirst() }
                val valores = ContentValues().apply {
                    put("administrado", 1)
                    put("administrado_em", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.ROOT).format(Date()))
                }
                if (existe) {
                    // Cliques repetidos preservam o horário da primeira confirmação.
                    db.update("administracoes", valores, "$where AND administrado=0", args)
                } else {
                    valores.put("medicamento_id", id)
                    valores.put("data", dose.getString("data"))
                    valores.put("horario", dose.getString("horario"))
                    db.insertOrThrow("administracoes", null, valores)
                }
                db.setTransactionSuccessful()
            } finally { db.endTransaction() }
        }
    }

    fun chave(dose: JSONObject) = "${dose.getInt("medicamento_id")}/${dose.getString("data")}/${dose.getString("horario")}"

    fun notificar(c: Context, dose: JSONObject) {
        val manager = c.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(
            NotificationChannel("doses", "Registro das doses", NotificationManager.IMPORTANCE_HIGH).apply { setSound(null, null) })
        fun acao(nome: String): PendingIntent = PendingIntent.getBroadcast(c, 0,
            Intent(c, AdministracaoReceiver::class.java).setAction(nome)
                .setData(Uri.parse("drac://dose/" + Uri.encode(chave(dose))))
                .putExtra("dose", dose.toString()), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val abrir = PendingIntent.getActivity(c, 0, Intent(c, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val texto = "${dose.optString("dose")} ${dose.optString("unidade")} • ${dose.getString("data")} às ${dose.getString("horario")}".trim()
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, "doses") else Notification.Builder(c)
        val compartilhado = c.getSharedPreferences("drac_shared", Context.MODE_PRIVATE).getBoolean("ativo", false)
        val confirmar = if (compartilhado) abrir else acao("administrar")
        manager.notify(chave(dose), 1, builder.setSmallIcon(R.drawable.ic_stat_drac)
            .setContentTitle(dose.getString("nome")).setContentText(texto)
            .setStyle(Notification.BigTextStyle().bigText(texto))
            .setContentIntent(abrir).setAutoCancel(false).setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .addAction(Notification.Action.Builder(null, "Parar som", acao("parar")).build())
            .addAction(Notification.Action.Builder(null, if (compartilhado) "Conferir no aplicativo" else "Já administrei", confirmar).build()).build())
    }
}

class AdministracaoReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "parar") {
            context.stopService(Intent(context, SomService::class.java))
            return
        }
        if (intent.action != "administrar") return
        val pending = goAsync()
        Thread {
            try {
                val dose = JSONObject(intent.getStringExtra("dose") ?: error("Dose ausente"))
                RegistroDose.salvar(context, dose)
                context.getSystemService(NotificationManager::class.java).cancel(RegistroDose.chave(dose), 1)
                context.stopService(Intent(context, SomService::class.java))
                Handler(Looper.getMainLooper()).post {
                    MainActivity.dadosAlterados()
                    Toast.makeText(context, "Dose registrada no histórico", Toast.LENGTH_SHORT).show()
                }
            } catch (e: Exception) {
                android.util.Log.e("DracAlarm", "Falha ao registrar dose", e)
                Handler(Looper.getMainLooper()).post {
                    Toast.makeText(context, "Não foi possível salvar. Tente novamente ou abra o app.", Toast.LENGTH_LONG).show()
                }
            } finally { pending.finish() }
        }.start()
    }
}
