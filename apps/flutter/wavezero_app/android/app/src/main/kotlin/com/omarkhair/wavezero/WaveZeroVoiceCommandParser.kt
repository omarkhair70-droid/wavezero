package com.omarkhair.wavezero

sealed interface WaveZeroVoiceCommand {
    data object Play : WaveZeroVoiceCommand
    data object Pause : WaveZeroVoiceCommand
    data object Next : WaveZeroVoiceCommand
    data object Previous : WaveZeroVoiceCommand
    data object VolumeUp : WaveZeroVoiceCommand
    data object VolumeDown : WaveZeroVoiceCommand
    data object StopLoop : WaveZeroVoiceCommand
    data class SeekBy(val deltaMs: Long) : WaveZeroVoiceCommand
    data class PlayLocalTrack(val query: String) : WaveZeroVoiceCommand
    data class SaveMoment(val name: String) : WaveZeroVoiceCommand
    data class GoToMoment(val name: String) : WaveZeroVoiceCommand
    data class LoopFromHere(val durationMs: Long) : WaveZeroVoiceCommand
    data class Unknown(val raw: String) : WaveZeroVoiceCommand
}

object WaveZeroVoiceCommandParser {
    private val wakePhrases = listOf(
        "wave zero",
        "wavezero",
        "ويف زيرو",
        "ويفزيرو",
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

        parseSaveMoment(normalized)?.let { return it }
        parseGoToMoment(normalized)?.let { return it }

        if (containsAny(normalized, "وقف التكرار", "بطل التكرار", "الغ التكرار", "stop loop", "cancel loop")) {
            return WaveZeroVoiceCommand.StopLoop
        }
        parseLoop(normalized)?.let { return it }

        if (containsAny(normalized, "وطي الصوت", "وطي", "قلل الصوت", "نزل الصوت", "volume down", "lower volume")) {
            return WaveZeroVoiceCommand.VolumeDown
        }
        if (containsAny(normalized, "علي الصوت", "علي", "زود الصوت", "ارفع الصوت", "volume up", "raise volume")) {
            return WaveZeroVoiceCommand.VolumeUp
        }
        if (containsAny(normalized, "اللي بعدها", "بعدها", "next", "next track")) {
            return WaveZeroVoiceCommand.Next
        }
        if (containsAny(normalized, "اللي قبلها", "قبلها", "previous", "previous track")) {
            return WaveZeroVoiceCommand.Previous
        }
        if (containsAny(normalized, "وقف", "pause", "استنى", "استني")) {
            return WaveZeroVoiceCommand.Pause
        }
        if (containsAny(normalized, "كمل", "resume", "كمل الاغنيه", "كمل الاغنية")) {
            return WaveZeroVoiceCommand.Play
        }

        parseSeek(normalized)?.let { return it }
        parseTrackQuery(normalized)?.let { return WaveZeroVoiceCommand.PlayLocalTrack(it) }

        if (normalized == "شغل" || normalized == "play") return WaveZeroVoiceCommand.Play
        return WaveZeroVoiceCommand.Unknown(raw)
    }

    private fun parseSaveMoment(text: String): WaveZeroVoiceCommand.SaveMoment? {
        val prefixes = listOf(
            "احفظ الحته دي باسم ",
            "احفظ الحتة دي باسم ",
            "احفظ الجزء ده باسم ",
            "سجل الحته دي باسم ",
            "سجل الحتة دي باسم ",
            "save this part as ",
            "save this moment as ",
        )
        val prefix = prefixes.firstOrNull { text.startsWith(it) } ?: return null
        val name = text.removePrefix(prefix).trim().takeIf { it.length >= 2 } ?: return null
        return WaveZeroVoiceCommand.SaveMoment(name)
    }

    private fun parseGoToMoment(text: String): WaveZeroVoiceCommand.GoToMoment? {
        val prefixes = listOf(
            "روح للحته ",
            "روح للحتة ",
            "روح لجزء ",
            "روح ل ",
            "ارجع للحته ",
            "ارجع للحتة ",
            "go to moment ",
            "go to ",
        )
        val prefix = prefixes.firstOrNull { text.startsWith(it) } ?: return null
        val name = text.removePrefix(prefix).trim().takeIf { it.length >= 2 } ?: return null
        if (name.any(Char::isDigit) && containsAny(name, "ثانيه", "ثانية", "second", "seconds")) return null
        return WaveZeroVoiceCommand.GoToMoment(name)
    }

    private fun parseLoop(text: String): WaveZeroVoiceCommand.LoopFromHere? {
        if (!containsAny(text, "كرر", "repeat", "loop")) return null
        if (!containsAny(text, "الحته دي", "الحتة دي", "الجزء ده", "من هنا", "this part", "from here")) return null
        val seconds = extractSeconds(text) ?: 15L
        return WaveZeroVoiceCommand.LoopFromHere(seconds.coerceIn(3L, 120L) * 1000L)
    }

    private fun parseSeek(text: String): WaveZeroVoiceCommand.SeekBy? {
        val backwards = containsAny(text, "ارجع", "رجع", "ورا", "back")
        val forwards = containsAny(text, "قدم", "forward")
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
            "شغل اغنية ",
            "شغلي اغنيه ",
            "شغلي اغنية ",
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
