package com.omarkhair.wavezero

import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.util.Patterns
import android.widget.Toast
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest
import java.util.UUID

private const val IMPORT_INBOX_FILE = "wavezero_import_inbox.json"
private const val IMPORT_INBOX_MAX_ITEMS = 100
private const val MAX_BATCH_AUDIO_IMPORTS = 50
private const val WAVEZERO_IMPORT_RELATIVE_PATH = "Music/WaveZero/Imports/"

class WaveZeroShareActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (intent?.action !in setOf(Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE)) {
            finish()
            return
        }

        Thread {
            val result = runCatching { receiveShare(intent) }
            runOnUiThread {
                val message = result.getOrElse { error ->
                    error.message ?: "WaveZero could not import this item."
                }
                Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
                openWaveZero()
                finish()
            }
        }.start()
    }

    private fun receiveShare(intent: Intent): String {
        if (intent.action == Intent.ACTION_SEND_MULTIPLE) {
            return receiveMultipleAudio(intent)
        }

        val mimeType = intent.type.orEmpty()
        val stream = sharedStream(intent)
        if (stream != null && mimeType.startsWith("audio/")) {
            val resolvedMimeType = contentResolver.getType(stream)
                ?.takeIf { it.startsWith("audio/") }
                ?: mimeType
            val imported = importAudio(stream, resolvedMimeType)
            WaveZeroImportInbox.append(
                context = this,
                item = audioInboxItem(
                    imported = imported,
                    mimeType = resolvedMimeType,
                    createdAtMs = System.currentTimeMillis(),
                ),
            )
            return if (imported.alreadyExists) {
                "${imported.displayName} is already in WaveZero"
            } else {
                "${imported.displayName} added to WaveZero"
            }
        }

        val text = intent.getStringExtra(Intent.EXTRA_TEXT)?.trim().orEmpty()
        if (text.isNotEmpty()) return receiveSharedText(text)

        throw IllegalArgumentException("WaveZero can receive audio files and shared links.")
    }

    private fun receiveMultipleAudio(intent: Intent): String {
        val streams = sharedStreams(intent).take(MAX_BATCH_AUDIO_IMPORTS)
        if (streams.isEmpty()) {
            throw IllegalArgumentException("No shared audio files were found.")
        }

        val fallbackMimeType = intent.type.orEmpty()
        val inboxItems = mutableListOf<JSONObject>()
        var importedCount = 0
        var existingCount = 0
        var failedCount = 0
        val batchStartedAt = System.currentTimeMillis()

        streams.forEachIndexed { index, stream ->
            val mimeType = contentResolver.getType(stream)
                ?.takeIf { it.startsWith("audio/") }
                ?: fallbackMimeType.takeIf { it.startsWith("audio/") }

            if (mimeType == null) {
                failedCount += 1
                return@forEachIndexed
            }

            runCatching { importAudio(stream, mimeType) }
                .onSuccess { imported ->
                    if (imported.alreadyExists) {
                        existingCount += 1
                    } else {
                        importedCount += 1
                    }
                    inboxItems += audioInboxItem(
                        imported = imported,
                        mimeType = mimeType,
                        createdAtMs = batchStartedAt + index,
                    )
                }
                .onFailure { failedCount += 1 }
        }

        if (inboxItems.isEmpty()) {
            throw IllegalStateException("WaveZero could not import the selected audio files.")
        }
        WaveZeroImportInbox.appendAll(context = this, items = inboxItems)

        val summary = mutableListOf<String>()
        if (importedCount > 0) summary += "$importedCount added"
        if (existingCount > 0) summary += "$existingCount already here"
        if (failedCount > 0) summary += "$failedCount skipped"
        if (streams.size == MAX_BATCH_AUDIO_IMPORTS && sharedStreams(intent).size > MAX_BATCH_AUDIO_IMPORTS) {
            summary += "first $MAX_BATCH_AUDIO_IMPORTS processed"
        }
        return summary.joinToString(" • ").ifBlank { "Audio added to WaveZero" }
    }

    private fun audioInboxItem(
        imported: ImportedAudio,
        mimeType: String,
        createdAtMs: Long,
    ): JSONObject {
        val item = JSONObject()
            .put("id", UUID.randomUUID().toString())
            .put("kind", "audio")
            .put("title", imported.displayName)
            .put(
                "subtitle",
                if (imported.alreadyExists) "Already in WaveZero" else "Shared to WaveZero",
            )
            .put("value", imported.uri.toString())
            .put("mimeType", mimeType)
            .put("duplicateOfExisting", imported.alreadyExists)
            .put("createdAtMs", createdAtMs)
        imported.trackId?.let { item.put("trackId", it) }
        return item
    }

    private fun receiveSharedText(text: String): String {
        val httpUrl = firstHttpUrl(text)
        if (httpUrl != null && WaveZeroWebDownloads.looksLikeAudio(httpUrl, null, null)) {
            val task = WaveZeroWebDownloads.enqueue(
                context = applicationContext,
                url = httpUrl,
                userAgent = null,
                contentDisposition = null,
                mimeType = null,
                referer = null,
            )
            val downloadId = (task["id"] as? Number)?.toLong()
            val fileName = task["fileName"]?.toString()?.takeIf { it.isNotBlank() }
                ?: "WaveZero audio download"
            val item = JSONObject()
                .put("id", UUID.randomUUID().toString())
                .put("kind", "download")
                .put("title", fileName)
                .put("subtitle", "Downloading to WaveZero")
                .put("value", httpUrl)
                .put("mimeType", "text/plain")
                .put("createdAtMs", System.currentTimeMillis())
            if (downloadId != null) item.put("downloadId", downloadId)
            WaveZeroImportInbox.append(context = this, item = item)
            return "$fileName download started"
        }

        val value = httpUrl ?: text
        WaveZeroImportInbox.append(
            context = this,
            item = JSONObject()
                .put("id", UUID.randomUUID().toString())
                .put("kind", "link")
                .put("title", linkTitle(value))
                .put("subtitle", "Shared link")
                .put("value", value)
                .put("mimeType", "text/plain")
                .put("createdAtMs", System.currentTimeMillis()),
        )
        return "Saved to WaveZero Inbox"
    }

    private fun importAudio(sourceUri: Uri, mimeType: String): ImportedAudio {
        val displayName = queryDisplayName(sourceUri)
            ?.takeIf { it.isNotBlank() }
            ?: "wavezero-import-${System.currentTimeMillis()}.${extensionForMime(mimeType)}"
        val safeName = sanitizeFileName(displayName)
        val sourceSize = querySize(sourceUri)

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            findExistingImport(sourceUri, safeName, sourceSize)
                ?: importAudioWithMediaStore(sourceUri, mimeType, safeName)
        } else {
            importAudioLegacy(sourceUri, mimeType, safeName)
        }
    }

    private fun importAudioWithMediaStore(sourceUri: Uri, mimeType: String, displayName: String): ImportedAudio {
        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Audio.Media.MIME_TYPE, mimeType)
            put(MediaStore.Audio.Media.RELATIVE_PATH, WAVEZERO_IMPORT_RELATIVE_PATH)
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }
        val targetUri = resolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Android could not create the WaveZero import.")

        try {
            resolver.openInputStream(sourceUri)?.use { input ->
                resolver.openOutputStream(targetUri, "w")?.use { output ->
                    input.copyTo(output)
                } ?: throw IllegalStateException("WaveZero could not open the destination file.")
            } ?: throw IllegalStateException("WaveZero could not read the shared audio file.")

            values.clear()
            values.put(MediaStore.Audio.Media.IS_PENDING, 0)
            resolver.update(targetUri, values, null, null)
            return ImportedAudio(
                uri = targetUri,
                displayName = displayName,
                trackId = deviceTrackId(targetUri),
            )
        } catch (error: Exception) {
            resolver.delete(targetUri, null, null)
            throw error
        }
    }

    private fun findExistingImport(sourceUri: Uri, displayName: String, sourceSize: Long?): ImportedAudio? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val resolver = contentResolver
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.SIZE,
        )
        val selection =
            "${MediaStore.Audio.Media.RELATIVE_PATH} = ? AND ${MediaStore.Audio.Media.DISPLAY_NAME} = ?"
        val args = arrayOf(WAVEZERO_IMPORT_RELATIVE_PATH, displayName)
        var sourceDigest: ByteArray? = null
        var sourceDigestResolved = false
        resolver.query(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            projection,
            selection,
            args,
            "${MediaStore.Audio.Media.DATE_ADDED} DESC",
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val nameColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
            val sizeColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
            while (cursor.moveToNext()) {
                val existingSize = if (cursor.isNull(sizeColumn)) null else cursor.getLong(sizeColumn)
                if (sourceSize != null && existingSize != null && sourceSize != existingSize) continue

                val id = cursor.getLong(idColumn)
                val uri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
                if (!sourceDigestResolved) {
                    sourceDigest = contentDigest(sourceUri)
                    sourceDigestResolved = true
                }
                val incomingDigest = sourceDigest ?: continue
                val existingDigest = contentDigest(uri) ?: continue
                if (!incomingDigest.contentEquals(existingDigest)) continue

                return ImportedAudio(
                    uri = uri,
                    displayName = cursor.getString(nameColumn),
                    trackId = "device-audio-$id",
                    alreadyExists = true,
                )
            }
        }
        return null
    }

    private fun contentDigest(uri: Uri): ByteArray? = runCatching {
        val digest = MessageDigest.getInstance("SHA-256")
        contentResolver.openInputStream(uri)?.use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                if (read > 0) digest.update(buffer, 0, read)
            }
        } ?: return@runCatching null
        digest.digest()
    }.getOrNull()

    private fun importAudioLegacy(sourceUri: Uri, mimeType: String, displayName: String): ImportedAudio {
        val root = getExternalFilesDir(Environment.DIRECTORY_MUSIC)
            ?: throw IllegalStateException("WaveZero could not access device music storage.")
        val folder = File(root, "WaveZero/Imports").apply { mkdirs() }
        val target = uniqueFile(folder, displayName)
        contentResolver.openInputStream(sourceUri)?.use { input ->
            target.outputStream().use { output -> input.copyTo(output) }
        } ?: throw IllegalStateException("WaveZero could not read the shared audio file.")

        MediaScannerConnection.scanFile(this, arrayOf(target.absolutePath), arrayOf(mimeType), null)
        return ImportedAudio(Uri.fromFile(target), target.name)
    }

    private fun sharedStream(intent: Intent): Uri? {
        val fromExtra = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
        }
        return fromExtra ?: intent.clipData?.takeIf { it.itemCount > 0 }?.getItemAt(0)?.uri
    }

    private fun sharedStreams(intent: Intent): List<Uri> {
        val fromExtra = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java).orEmpty()
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM).orEmpty()
        }
        val fromClip = intent.clipData?.let { clip ->
            buildList {
                for (index in 0 until clip.itemCount) {
                    clip.getItemAt(index).uri?.let(::add)
                }
            }
        }.orEmpty()
        return (fromExtra + fromClip).distinctBy(Uri::toString)
    }

    private fun queryDisplayName(uri: Uri): String? {
        return contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index < 0 || cursor.isNull(index)) null else cursor.getString(index)
        }
    }

    private fun querySize(uri: Uri): Long? {
        return contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            val index = cursor.getColumnIndex(OpenableColumns.SIZE)
            if (index < 0 || cursor.isNull(index)) null else cursor.getLong(index)
        }
    }

    private fun deviceTrackId(uri: Uri): String? =
        uri.lastPathSegment?.toLongOrNull()?.let { "device-audio-$it" }

    private fun firstHttpUrl(text: String): String? {
        val matcher = Patterns.WEB_URL.matcher(text)
        while (matcher.find()) {
            val raw = matcher.group().orEmpty()
            val normalized = if (raw.startsWith("http://") || raw.startsWith("https://")) raw else "https://$raw"
            val uri = runCatching { Uri.parse(normalized) }.getOrNull()
            if (uri?.scheme in setOf("http", "https") && !uri?.host.isNullOrBlank()) return normalized
        }
        return null
    }

    private fun linkTitle(value: String): String {
        val uri = runCatching { Uri.parse(value) }.getOrNull()
        return uri?.host?.removePrefix("www.")?.takeIf { it.isNotBlank() } ?: "Shared to WaveZero"
    }

    private fun sanitizeFileName(raw: String): String {
        val clean = raw
            .replace(Regex("[\\/:*?\"<>|]+"), "_")
            .replace(Regex("\\s+"), " ")
            .trim()
            .take(180)
        return clean.ifBlank { "wavezero-import-${System.currentTimeMillis()}.mp3" }
    }

    private fun extensionForMime(mimeType: String): String = when (mimeType.lowercase()) {
        "audio/mp4", "audio/x-m4a" -> "m4a"
        "audio/aac" -> "aac"
        "audio/flac", "audio/x-flac" -> "flac"
        "audio/wav", "audio/x-wav" -> "wav"
        "audio/ogg" -> "ogg"
        "audio/opus" -> "opus"
        else -> "mp3"
    }

    private fun uniqueFile(folder: File, displayName: String): File {
        val initial = File(folder, displayName)
        if (!initial.exists()) return initial
        val dot = displayName.lastIndexOf('.')
        val stem = if (dot > 0) displayName.substring(0, dot) else displayName
        val extension = if (dot > 0) displayName.substring(dot) else ""
        var index = 2
        while (true) {
            val candidate = File(folder, "$stem ($index)$extension")
            if (!candidate.exists()) return candidate
            index += 1
        }
    }

    private fun openWaveZero() {
        startActivity(
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            },
        )
    }

    private data class ImportedAudio(
        val uri: Uri,
        val displayName: String,
        val trackId: String? = null,
        val alreadyExists: Boolean = false,
    )
}

private object WaveZeroImportInbox {
    private val lock = Any()

    fun append(context: android.content.Context, item: JSONObject) {
        appendAll(context, listOf(item))
    }

    fun appendAll(context: android.content.Context, items: List<JSONObject>) {
        if (items.isEmpty()) return
        synchronized(lock) {
            val target = File(context.filesDir, IMPORT_INBOX_FILE)
            val existing = runCatching {
                if (target.exists()) JSONArray(target.readText()) else JSONArray()
            }.getOrElse { JSONArray() }

            val next = JSONArray()
            val seenKeys = mutableSetOf<String>()
            for (item in items.asReversed()) {
                val key = inboxIdentity(item)
                if (key != null && !seenKeys.add(key)) continue
                if (next.length() >= IMPORT_INBOX_MAX_ITEMS) break
                next.put(item)
            }
            for (index in 0 until existing.length()) {
                if (next.length() >= IMPORT_INBOX_MAX_ITEMS) break
                val candidate = existing.optJSONObject(index) ?: continue
                val key = inboxIdentity(candidate)
                if (key != null && !seenKeys.add(key)) continue
                next.put(candidate)
            }

            val temp = File(context.filesDir, "$IMPORT_INBOX_FILE.tmp")
            temp.writeText(next.toString())
            if (!temp.renameTo(target)) {
                target.writeText(next.toString())
                temp.delete()
            }
        }
    }

    private fun inboxIdentity(item: JSONObject): String? {
        val trackId = item.optString("trackId").takeIf { it.isNotBlank() }
        if (trackId != null) return "track:$trackId"
        val downloadId = item.optLong("downloadId", -1L).takeIf { it > 0L }
        if (downloadId != null) return "download:$downloadId"
        val value = item.optString("value").trim()
        return value.takeIf { it.isNotBlank() }?.let { "value:$it" }
    }
}
