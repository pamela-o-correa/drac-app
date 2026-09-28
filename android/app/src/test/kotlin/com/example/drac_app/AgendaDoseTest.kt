package com.example.drac_app

import org.junit.Assert.*
import org.junit.Test
import java.text.SimpleDateFormat
import java.util.*

class AgendaDoseTest {
    private fun instante(valor: String): Long = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.ROOT).parse(valor)!!.time
    @Test fun avisoDezMinutosAntes() {
        assertEquals(instante("2026-09-25 08:50:00"), AgendaDose.antecedencia(instante("2026-09-25 09:00:00"), instante("2026-09-25 08:00:00")))
    }
    @Test fun avisoNaVesperaParaDoseAposMeiaNoite() {
        val dose = AgendaDose.proximo("00:05", "26/09/2026", "26/09/2026", instante("2026-09-25 22:00:00"))!!
        assertEquals(instante("2026-09-25 23:55:00"), AgendaDose.antecedencia(dose, instante("2026-09-25 22:00:00")))
    }
    @Test fun naoEnviaAvisoAtrasado() {
        assertNull(AgendaDose.antecedencia(instante("2026-09-25 09:00:00"), instante("2026-09-25 08:55:00")))
    }
    @Test fun naoRepeteAvisoNoMesmoInstante() {
        assertNull(AgendaDose.antecedencia(instante("2026-09-25 09:00:00"), instante("2026-09-25 08:50:00")))
    }
    @Test fun horarioFuturoHoje() {
        assertEquals(instante("2026-09-25 09:00:00"), AgendaDose.proximo("09:00", "", "", instante("2026-09-25 08:00:00")))
    }
    @Test fun horarioPassadoAmanha() {
        assertEquals(instante("2026-09-26 09:00:00"), AgendaDose.proximo("09:00", "", "", instante("2026-09-25 09:00:00")))
    }
    @Test fun respeitaInicioFuturo() {
        assertEquals(instante("2026-10-01 09:00:00"), AgendaDose.proximo("09:00", "01/10/2026", "", instante("2026-09-25 08:00:00")))
    }
    @Test fun incluiUltimoDia() {
        assertEquals(instante("2026-09-25 09:00:00"), AgendaDose.proximo("09:00", "", "25/09/2026", instante("2026-09-25 08:00:00")))
    }
    @Test fun naoAgendaDepoisDoFim() {
        assertNull(AgendaDose.proximo("09:00", "", "25/09/2026", instante("2026-09-25 10:00:00")))
    }
    @Test(expected = IllegalArgumentException::class) fun rejeitaHorarioInvalido() {
        AgendaDose.proximo("25:00", "", "")
    }
    @Test fun horarioVeraoMantemHoraLocal() {
        val original = TimeZone.getDefault()
        try {
            TimeZone.setDefault(TimeZone.getTimeZone("America/New_York"))
            assertEquals(instante("2026-03-08 09:00:00"), AgendaDose.proximo("09:00", "", "", instante("2026-03-07 10:00:00")))
        } finally { TimeZone.setDefault(original) }
    }
}
