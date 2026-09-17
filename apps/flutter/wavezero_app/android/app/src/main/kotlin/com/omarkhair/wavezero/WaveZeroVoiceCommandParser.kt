package com.omarkhair.wavezero

sealed interface WaveZeroVoiceCommand {
    data object Play : WaveZeroVoiceCommand
    data object Pause : WaveZeroVoiceCommand
    data object Next : WaveZeroVoiceCommand
    data object Previous : WaveZeroVoiceCommand
    data object VolumeUp : WaveZeroVoiceCommand
    data object VolumeDown : WaveZeroVoiceCommand
    data class SeekBy(val deltaMs: Long) : WaveZeroVoiceCommand
    data class PlayLocalTrack(val query: String) : WaveZeroVoiceCommand
    data class Unknown(val raw: String) : WaveZeroVoiceCommand
}

object WaveZeroVoiceCommandParser {
    private val wakePhrases = listOf(
        "wave zero",
        "wavezero",
        "ويف زيرو",
        "ويفزيرو",
        "ويف زيرو",
    )

    fun splitWakePhrase(raw: String): Pair<Boolean, String> {
        val normalized = normalize(raw)
        val wake = wakePhrases.firstOrNull { normalized.contains(it) } ?: return false to normalized
        val remainder = normalized.substringAfter(wake).trim()
        return true to remainder
    }

    fun parse(raw: String): WaveZeroVoiceCommand {
        val normalized = normalize(raw)
        if (normalized.isBlank()) return WaveZeroVoiceCommand.Unknown(raw)

        if (containsAny(normalized, "وطي الصوت", "وطي", "قلل الصوت", "نزل الصوت", "volume down", "lower volume")) {
            return WaveZeroVoiceCommand.VolumeDown
        }
        if (containsAny(normalized, "علي الصوت", "علي", "زود الصوت", "ارفع الصوت", "volume up", "raise volume")) {
            return WaveZeroVoiceCommand.VolumeUp
        }
        if (containsAny(normalized, "اللي بعدها", "اللى بعدها", "بعدها", "next", "next track")) {
            return WaveZeroVoiceCommand.Next
        }
        if (containsAny(normalized, "اللي قبلها", "اللى قبلها", "قبلها", "previous", "previous track")) {
            return WaveZeroVoiceCommand.Previous
        }
        if (containsAny(normalized, "وقف", "وقّف", "pause", "استنى", "استني")) {
            return WaveZeroVoiceCommand.Pause
        }
        if (containsAny(normalized, "كمل", "كمّل", "resume", "كمل الاغنيه", "كمل الأغنيه")) {
            return WaveZeroVoiceCommand.Play
        }

        parseSeek(normalized)?.let { return it }
        parseTrackQuery(normalized)?.let { return WaveZeroVoiceCommand.PlayLocalTrack(it) }

        if (normalized == "شغل" || normalized == "play") return WaveZeroVoiceCommand.Play
        return WaveZeroVoiceCommand.Unknown(raw)
    }

    private fun parseSeek(text: String): WaveZeroVoiceCommand.SeekBy? {
        val backwards = containsAny(text, "ارجع", "رجع", "ورا", "back")
        val forwards = containsAny(text, "قدم", "قدّم", "forward")
        if (!backwards && !forwards) return null

        val seconds = extractSeconds(text) ?: 10L
        val delta = seconds.coerceIn(1L, 300L) * 1000L * if (backwards) -1L else 1L
        return WaveZeroVoiceCommand.SeekBy(delta)
    }

    private fun extractSeconds(text: String): Long? {
        Regex("(\\d{1,3})").find(text)?.groupValues?.getOrNull(1)?.toLongOrNull()?.let { return it }
        val spoken = linkedMapOf(
            "خمس" to 5L,
            "خمسه" to 5L,
            "خمسة" to 5L,
            "عشر" to 10L,
            "عشره" to 10L,
            "عشرة" to 10L,
            "خمستاشر" to 15L,
            "عشرين" to 20L,
            "تلاتين" to 30L,
            "ثلاثين" to 30L,
            "دقيقه" to 60L,
            "دقيقة" to 60L,
        )
        return spoken.entries.firstOrNull { text.contains(it.key) }?.value
    }

    private fun parseTrackQuery(text: String): String? {
        val prefixes = listOf(
            "شغل اغنيه ",
            "شغل أغنيه ",
            "شغل اغنية ",
            "شغل أغنية ",
            "شغلي اغنيه ",
            "شغلي أغنيه ",
            "شغلي اغنية ",
            "شغلي أغنية ",
            "شغللي ",
            "شغلي ",
            "شغل ",
            "play song ",
            "play ",
        )
        val prefix = prefixes.firstOrNull { text.startsWith(it) } ?: return null
        return text.removePrefix(prefix).trim().takeIf { it.length >= 2 }
    }

    private fun containsAny(text: String, vararg phrases: String): Boolean = phrases.any(text::contains)

    fun normalize(raw: String): String {
        return raw
            .lowercase()
            .replace('أ', 'ا')
            .replace('إ', 'ا')
            .replace('آ', 'ا')
            .replace('ى', 'ي')
            .replace('ؤ', 'و')
            .replace('ئ', 'ي')
            .replace(Regex("[ًٌٍَُِّْـ]"), "")
            .replace(Regex("[^\\p{L}\\p{N} ]"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
    }
}
