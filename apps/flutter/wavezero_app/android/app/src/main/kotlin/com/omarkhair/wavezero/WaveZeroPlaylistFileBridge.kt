package com.omarkhair.wavezero

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class WaveZeroPlaylistFileBridge(
    private val activity: Activity,
) : MethodChannel.MethodCallHandler {
    private var pendingImport: MethodChannel.Result? = null
    private var pendingExport: MethodChannel.Result? = null
    private var pendingExportContent: String? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "importM3u" -> importM3u(result)
            "exportM3u" -> exportM3u(call, result)
            else -> result.notImplemented()
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        return when (requestCode) {
            REQUEST_IMPORT_M3U -> {
                handleImportResult(resultCode, data)
                true
            }
            REQUEST_EXPORT_M3U -> {
                handleExportResult(resultCode, data)
                true
            }
            else -> false
        }
    }

    fun dispose() {
        pendingImport?.error("activity_closed", "Playlist import was cancelled because the activity closed.", null)
        pendingExport?.error("activity_closed", "Playlist export was cancelled because the activity closed.", null)
        pendingImport = null
        pendingExport = null
        pendingExportContent = null
    }

    private fun importM3u(result: MethodChannel.Result) {
        if (pendingImport != null || pendingExport != null) {
            result.error("playlist_file_busy", "Another playlist file action is already open.", null)
            return
        }
        pendingImport = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "audio/x-mpegurl",
                    "audio/mpegurl",
                    "application/x-mpegurl",
                    "application/vnd.apple.mpegurl",
                    "text/plain",
                ),
            )
        }
        activity.startActivityForResult(intent, REQUEST_IMPORT_M3U)
    }

    private fun exportM3u(call: MethodCall, result: MethodChannel.Result) {
        if (pendingImport != null || pendingExport != null) {
            result.error("playlist_file_busy", "Another playlist file action is already open.", null)
            return
        }
        val content = call.argument<String>("content").orEmpty()
        if (content.isBlank()) {
            result.error("invalid_arguments", "exportM3u requires non-empty content.", null)
            return
        }
        if (content.toByteArray(Charsets.UTF_8).size > MAX_M3U_BYTES) {
            result.error("playlist_too_large", "Playlist export is larger than the supported limit.", null)
            return
        }
        val requestedName = call.argument<String>("fileName").orEmpty().ifBlank { "WaveZero Playlist.m3u" }
        val fileName = if (requestedName.lowercase().endsWith(".m3u")) requestedName else "$requestedName.m3u"
        pendingExport = result
        pendingExportContent = content
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "audio/x-mpegurl"
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        activity.startActivityForResult(intent, REQUEST_EXPORT_M3U)
    }

    private fun handleImportResult(resultCode: Int, data: Intent?) {
        val result = pendingImport ?: return
        pendingImport = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }
        val uri = data?.data
        if (uri == null) {
            result.error("playlist_import_failed", "No playlist file was selected.", null)
            return
        }
        try {
            val bytes = readLimited(uri)
            val content = bytes.toString(Charsets.UTF_8)
            result.success(
                mapOf(
                    "name" to displayName(uri),
                    "content" to content,
                    "uri" to uri.toString(),
                ),
            )
        } catch (error: Exception) {
            result.error("playlist_import_failed", error.message ?: "Could not read playlist file.", null)
        }
    }

    private fun handleExportResult(resultCode: Int, data: Intent?) {
        val result = pendingExport ?: return
        val content = pendingExportContent.orEmpty()
        pendingExport = null
        pendingExportContent = null
        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }
        val uri = data?.data
        if (uri == null) {
            result.error("playlist_export_failed", "No playlist destination was selected.", null)
            return
        }
        try {
            activity.contentResolver.openOutputStream(uri, "wt")?.use { output ->
                output.write(content.toByteArray(Charsets.UTF_8))
                output.flush()
            } ?: throw IllegalStateException("Could not open playlist destination.")
            result.success(mapOf("uri" to uri.toString(), "name" to displayName(uri)))
        } catch (error: Exception) {
            result.error("playlist_export_failed", error.message ?: "Could not write playlist file.", null)
        }
    }

    private fun readLimited(uri: Uri): ByteArray {
        activity.contentResolver.openInputStream(uri)?.use { input ->
            val output = ByteArrayOutputStream()
            val buffer = ByteArray(8192)
            var total = 0
            while (true) {
                val read = input.read(buffer)
                if (read < 0) break
                total += read
                if (total > MAX_M3U_BYTES) {
                    throw IllegalArgumentException("Playlist file is larger than ${MAX_M3U_BYTES / 1024 / 1024} MB.")
                }
                output.write(buffer, 0, read)
            }
            return output.toByteArray()
        }
        throw IllegalStateException("Could not open playlist file.")
    }

    private fun displayName(uri: Uri): String {
        activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) {
                    val value = cursor.getString(index)
                    if (!value.isNullOrBlank()) return value
                }
            }
        }
        return uri.lastPathSegment?.substringAfterLast('/')?.takeIf { it.isNotBlank() } ?: "playlist.m3u"
    }

    companion object {
        const val CHANNEL_NAME = "wavezero/playlist_files"
        private const val REQUEST_IMPORT_M3U = 4101
        private const val REQUEST_EXPORT_M3U = 4102
        private const val MAX_M3U_BYTES = 2 * 1024 * 1024
    }
}
