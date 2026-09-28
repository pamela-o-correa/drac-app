package com.example.drac_app

import java.text.SimpleDateFormat
import java.util.*

object AgendaDose {
    // Não envia um aviso atrasado se o app for aberto dentro dos últimos 10 minutos.
    fun antecedencia(quando: Long, agora: Long = System.currentTimeMillis()): Long? =
        (quando - 10 * 60 * 1000L).takeIf { it > agora }

    private fun data(texto: String): Calendar? {
        if (texto.isBlank()) return null
        val formato = SimpleDateFormat("dd/MM/yyyy", Locale.ROOT).apply { isLenient = false }
        return Calendar.getInstance().apply { time = formato.parse(texto) ?: error("Data inválida") }
    }

    // Calendar.add preserva o horário local em mudanças de fuso/horário de verão.
    fun proximo(horario: String, dataInicio: String, dataFim: String, agora: Long = System.currentTimeMillis()): Long? {
        val partes = horario.split(":")
        require(partes.size == 2)
        val hora = partes[0].toInt(); val minuto = partes[1].toInt()
        require(hora in 0..23 && minuto in 0..59)
        val inicio = data(dataInicio)
        val fim = data(dataFim)?.apply {
            set(Calendar.HOUR_OF_DAY, 23); set(Calendar.MINUTE, 59)
            set(Calendar.SECOND, 59); set(Calendar.MILLISECOND, 999)
        }
        val proximo = Calendar.getInstance().apply {
            timeInMillis = agora
            set(Calendar.HOUR_OF_DAY, hora); set(Calendar.MINUTE, minuto)
            set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
        }
        if (inicio != null && proximo.before(inicio)) {
            proximo.timeInMillis = inicio.timeInMillis
            proximo.set(Calendar.HOUR_OF_DAY, hora); proximo.set(Calendar.MINUTE, minuto)
        }
        if (proximo.timeInMillis <= agora) proximo.add(Calendar.DATE, 1)
        return if (fim != null && proximo.after(fim)) null else proximo.timeInMillis
    }

}

