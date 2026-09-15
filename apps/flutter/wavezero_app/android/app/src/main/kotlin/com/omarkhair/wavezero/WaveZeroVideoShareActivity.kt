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
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.Transformer
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest
import java.util.UUID

private const val VIDEO_AUDIO_RELATIVE_PATH = "Music/WaveZero/Imports/"
private const val VIDEO_AUDIO_MIME_TYPE = "audio/mp4"

@UnstableApi
class WaveZeroVideoShareActivity : Activity() {
    private var activeTransformer: Transformer? = null
    private var temporaryOutput: File? = null
    private var completed = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (intent?.action != Intent.ACTION_SEND) {
            finish()
            return
        }

        val sourceUri = sharedStream(intent)
        val mimeType = sourceUri?.let(contentResolver::getType) ?: intent.type.orEmpty()
        if (sourceUri == null || !mimeType.startsWith("video/")) {
            finishWithMessage("WaveZero needs a shared video file to extract audio.")
            return
        }

        showExtractionState()
        startExtraction(sourceUri)
    }

    override fun onDestroy() {
        if (!completed) {
            runCatching { activeTransformer?.cancel() }
            temporaryOutput?.delete()
        }
        activeTransformer = null
        temporaryOutput = null
        super.onDestroy()
    }

    private fun showExtractionState() {
        val density = resources.displayMetrics.density
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding((28 * density).toInt(), (28 * density).toInt(), (28 * density).toInt(), (28 * density).toInt())
            setBackgroundColor(0xFFF7F9FB.toInt())
        }
        root.addView(ProgressBar(this))
        root.addView(TextView(this).apply {
            text = "Extracting audio…"
            textSize = 18f
            gravity = Gravity.CENTER
            setTextColor(0xFF17222C.toInt())
            setPadding(0, (18 * density).toInt(), 0, 0)
        })
        root.addView(TextView(this).apply {
            text = "The video stays on your device. WaveZero will save an M4A copy of its audio."
            textSize = 13f
            gravity = Gravity.CENTER
            setTextColor(0xFF697986.toInt())
            setPadding(0, (8 * density).toInt(), 0, 0)
        })
        setContentView(root)
    }

    private fun startExtraction(sourceUri: Uri) {
        val sourceName = queryDisplayName(sourceUri)
            ?.takeIf { it.isNotBlank() }
            ?: "wavezero-video-${System.currentTimeMillis()}.mp4"
        val outputName = audioOutputName(sourceName)
        val outputFile = File.createTempFile("wavezero-video-audio-", ".mp4", cacheDir)
        temporaryOutput = outputFile

        val editedMediaItem = EditedMediaItem.Builder(MediaItem.fromUri(sourceUri))
            .setRemoveVideo(true)
            .build()

        val transformer = Transformer.Builder(applicationContext)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .addListener(
                object : Transformer.Listener {
                    override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                        activeTransformer = null
                        Thread {
                            val published = runCatching { publishAudio(outputFile, outputName) }
                            runOnUiThread {
                                published.fold(
                                    onSuccess = { audio ->
                                        WaveZeroImportInbox.append(
                                            context = this@WaveZeroVideoShareActivity,
                                            item = audioInboxItem(audio),
                                        )
                                        completed = true
                                        outputFile.delete()
                                        val message = if (audio.alreadyExists) {
                                            "${audio.displayName} is already in WaveZero"
                                        } else {
                                            "${audio.displayName} extracted to WaveZero"
                                        }
                                        finishWithMessage(message)
                                    },
                                    onFailure = {
                                        outputFile.delete()
                                        finishWithMessage("WaveZero could not save the extracted audio.")
                                    },
                                )
                            }
                        }.start()
                    }

                    override fun onError(
                        composition: Composition,
                        exportResult: ExportResult,
                        exportException: ExportException,
                    ) {
                        activeTransformer = null
                        outputFile.delete()
                        finishWithMessage("WaveZero could not extract audio from this video.")
                    }
                },
            )
            .build()

        activeTransformer = transformer
        runCatching { transformer.start(editedMediaItem, outputFile.absolutePath) }
            .onFailure {
                activeTransformer = null
                outputFile.delete()
                finishWithMessage("WaveZero could not start audio extraction for this video.")
            }
    }

    private fun publishAudio(sourceFile: File, displayName: String): PublishedAudio {
        if (!sourceFile.exists() || sourceFile.length() <= 0L) {
            throw IllegalStateException("Audio export did not produce a file.")
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            findExistingPublishedAudio(sourceFile, displayName)
                ?: publishWithMediaStore(sourceFile, displayName)
        } else {
            publishLegacy(sourceFile, displayName)
        }
    }

    private fun publishWithMediaStore(sourceFile: File, displayName: String): PublishedAudio {
        val resolver = contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, displayName)
            put(MediaStore.Audio.Media.MIME_TYPE, VIDEO_AUDIO_MIME_TYPE)
            put(MediaStore.Audio.Media.RELATIVE_PATH, VIDEO_AUDIO_RELATIVE_PATH)
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }
        val targetUri = resolver.insert(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("Android could not create the extracted audio file.")
        try {
            sourceFile.inputStream().use { input ->
                resolver.openOutputStream(targetUri, "w")?.use { output ->
                    input.copyTo(output)
                } ?: throw IllegalStateException("WaveZero could not open the audio destination.")
            }
            values.clear()
            values.put(MediaStore.Audio.Media.IS_PENDING, 0)
            resolver.update(targetUri, values, null, null)
            return PublishedAudio(
                uri = targetUri,
                displayName = displayName,
                trackId = targetUri.lastPathSegment?.toLongOrNull()?.let { "device-audio-$it" },
            )
        } catch (error: Exception) {
            resolver.delete(targetUri, null, null)
            throw error
        }
    }

    private fun findExistingPublishedAudio(sourceFile: File, displayName: String): PublishedAudio? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.SIZE,
        )
        val selection =
            "${MediaStore.Audio.Media.RELATIVE_PATH} = ? AND ${MediaStore.Audio.Media.DISPLAY_NAME} = ?"
        val args = arrayOf(VIDEO_AUDIO_RELATIVE_PATH, displayName)
        val sourceSize = sourceFile.length()
        val sourceDigest = fileDigest(sourceFile) ?: return null
        contentResolver.query(
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
                if (existingSize != null && existingSize != sourceSize) continue
                val id = cursor.getLong(idColumn)
                val uri = ContentUris.withAppendedId(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id)
                val existingDigest = contentDigest(uri) ?: continue
                if (!sourceDigest.contentEquals(existingDigest)) continue
                return PublishedAudio(
                    uri = uri,
                    displayName = cursor.getString(nameColumn),
                    trackId = "device-audio-$id",
                    alreadyExists = true,
                )
            }
        }
        return null
    }

    private fun publishLegacy(sourceFile: File, displayName: String): PublishedAudio {
        val root = getExternalFilesDir(Environment.DIRECTORY_MUSIC)
            ?: throw IllegalStateException("WaveZero could not access local music storage.")
        val folder = File(root, "WaveZero/Imports").apply { mkdirs() }
        val target = uniqueFile(folder, displayName)
        sourceFile.copyTo(target, overwrite = false)
        MediaScannerConnection.scanFile(this, arrayOf(target.absolutePath), arrayOf(VIDEO_AUDIO_MIME_TYPE), null)
        return PublishedAudio(uri = Uri.fromFile(target), displayName = target.name)
    }

    private fun audioInboxItem(audio: PublishedAudio): JSONObject {
        val item = JSONObject()
            .put("id", UUID.randomUUID().toString())
            .put("kind", "audio")
            .put("title", audio.displayName)
            .put(
                "subtitle",
                if (audio.alreadyExists) "Already in WaveZero" else "Extracted from shared video",
            )
            .put("value", audio.uri.toString())
            .put("mimeType", VIDEO_AUDIO_MIME_TYPE)
            .put("duplicateOfExisting", audio.alreadyExists)
            .put("createdAtMs", System.currentTimeMillis())
        audio.trackId?.let { item.put("trackId", it) }
        return item
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

    private fun queryDisplayName(uri: Uri): String? =
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (!cursor.moveToFirst()) return@use null
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index < 0 || cursor.isNull(index)) null else cursor.getString(index)
        }

    private fun audioOutputName(sourceName: String): String {
        val dot = sourceName.lastIndexOf('.')
        val stem = if (dot > 0) sourceName.substring(0, dot) else sourceName
        val clean = stem
            .replace(Regex("[\\/:*?\"<>|]+"), "_")
            .replace(Regex("\\s+"), " ")
            .trim()
            .take(170)
            .ifBlank { "WaveZero audio" }
        return "$clean.m4a"
    }

    private fun fileDigest(file: File): ByteArray? = runCatching {
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                if (read > 0) digest.update(buffer, 0, read)
            }
        }
        digest.digest()
    }.getOrNull()

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

    private fun finishWithMessage(message: String) {
        if (isFinishing || isDestroyed) return
        completed = true
        Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
        startActivity(
            Intent(this, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            },
        )
        finish()
    }

    private data class PublishedAudio(
        val uri: Uri,
        val displayName: String,
        val trackId: String? = null,
        val alreadyExists: Boolean = false,
    )
}
