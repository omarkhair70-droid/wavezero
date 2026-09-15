package com.omarkhair.wavezero

import android.app.DownloadManager
import android.content.Context
import android.net.Uri
import android.os.Environment
import android.webkit.CookieManager
import android.webkit.DownloadListener
import android.webkit.URLUtil
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

private const val WAVEZERO_NATIVE_WEBVIEW_TYPE = "wavezero/native_webview"
private const val WAVEZERO_WEB_DOWNLOAD_CHANNEL = "wavezero/web_downloads"

class WaveZeroWebViewFactory(
    private val context: Context,
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    init {
        MethodChannel(messenger, WAVEZERO_WEB_DOWNLOAD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "queryDownload" -> {
                    val id = (call.argument<Number>("id"))?.toLong()
                    if (id == null) {
                        result.error("invalid_arguments", "queryDownload requires id", null)
                    } else {
                        result.success(WaveZeroWebDownloads.query(context, id))
                    }
                }
                "cancelDownload" -> {
                    val id = (call.argument<Number>("id"))?.toLong()
                    if (id == null) {
                        result.error("invalid_arguments", "cancelDownload requires id", null)
                    } else {
                        WaveZeroWebDownloads.cancel(context, id)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
        val params = (args as? Map<*, *>) ?: emptyMap<Any?, Any?>()
        val initialUrl = params["url"]?.toString()?.takeIf { it.isNotBlank() } ?: "https://www.google.com"
        return WaveZeroNativeWebView(context, messenger, viewId, initialUrl)
    }

    companion object {
        const val VIEW_TYPE = WAVEZERO_NATIVE_WEBVIEW_TYPE
    }
}

private class WaveZeroNativeWebView(
    context: Context,
    messenger: BinaryMessenger,
    viewId: Int,
    initialUrl: String,
) : PlatformView, MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "wavezero/webview/$viewId")
    private val webView = WebView(context)

    init {
        channel.setMethodCallHandler(this)
        configureWebView()
        webView.loadUrl(initialUrl)
    }

    private fun configureWebView() {
        webView.setBackgroundColor(android.graphics.Color.WHITE)
        webView.settings.apply {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            loadsImagesAutomatically = true
            mediaPlaybackRequiresUserGesture = true
            builtInZoomControls = true
            displayZoomControls = false
            cacheMode = WebSettings.LOAD_DEFAULT
            mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
            allowFileAccess = false
            allowContentAccess = true
            setSupportMultipleWindows(false)
        }

        webView.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                val url = request?.url ?: return false
                val scheme = url.scheme?.lowercase()
                return scheme != "http" && scheme != "https"
            }

            override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
                super.onPageStarted(view, url, favicon)
                channel.invokeMethod("pageStarted", mapOf("url" to url.orEmpty()))
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                super.onPageFinished(view, url)
                channel.invokeMethod(
                    "pageFinished",
                    mapOf(
                        "url" to url.orEmpty(),
                        "canGoBack" to webView.canGoBack(),
                        "canGoForward" to webView.canGoForward(),
                    ),
                )
            }

            override fun onReceivedError(view: WebView?, request: WebResourceRequest?, error: WebResourceError?) {
                super.onReceivedError(view, request, error)
                if (request?.isForMainFrame != true) return
                channel.invokeMethod(
                    "webError",
                    mapOf("description" to (error?.description?.toString() ?: "This page could not be loaded.")),
                )
            }
        }

        webView.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                super.onProgressChanged(view, newProgress)
                channel.invokeMethod("progress", mapOf("progress" to newProgress.coerceIn(0, 100)))
            }
        }

        webView.setDownloadListener(
            DownloadListener { url, userAgent, contentDisposition, mimeType, _ ->
                if (!WaveZeroWebDownloads.looksLikeAudio(url, contentDisposition, mimeType)) {
                    channel.invokeMethod(
                        "downloadRejected",
                        mapOf("message" to "WaveZero Web only saves supported audio files."),
                    )
                    return@DownloadListener
                }
                try {
                    val task = WaveZeroWebDownloads.enqueue(
                        context = webView.context.applicationContext,
                        url = url,
                        userAgent = userAgent,
                        contentDisposition = contentDisposition,
                        mimeType = mimeType,
                        referer = webView.url,
                    )
                    channel.invokeMethod("downloadStarted", task)
                } catch (error: Exception) {
                    channel.invokeMethod(
                        "downloadRejected",
                        mapOf("message" to (error.message ?: "Could not start this download.")),
                    )
                }
            },
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadUrl" -> {
                val url = call.argument<String>("url")?.trim().orEmpty()
                if (!WaveZeroWebDownloads.isHttpUrl(url)) {
                    result.error("invalid_url", "WaveZero Web only opens http/https pages.", null)
                    return
                }
                webView.loadUrl(url)
                result.success(null)
            }
            "goBack" -> {
                if (webView.canGoBack()) webView.goBack()
                result.success(null)
            }
            "goForward" -> {
                if (webView.canGoForward()) webView.goForward()
                result.success(null)
            }
            "reload" -> {
                webView.reload()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun getView(): WebView = webView

    override fun dispose() {
        channel.setMethodCallHandler(null)
        webView.stopLoading()
        webView.loadUrl("about:blank")
        webView.clearHistory()
        webView.removeAllViews()
        webView.destroy()
    }
}

private object WaveZeroWebDownloads {
    private val supportedExtensions = setOf("mp3", "m4a", "aac", "flac", "wav", "ogg", "opus")

    fun isHttpUrl(url: String): Boolean {
        val scheme = runCatching { Uri.parse(url).scheme?.lowercase() }.getOrNull()
        return scheme == "http" || scheme == "https"
    }

    fun looksLikeAudio(url: String?, contentDisposition: String?, mimeType: String?): Boolean {
        if (mimeType?.lowercase()?.startsWith("audio/") == true) return true
        val guessedName = URLUtil.guessFileName(url.orEmpty(), contentDisposition, mimeType)
        val extension = guessedName.substringAfterLast('.', missingDelimiterValue = "").lowercase()
        if (extension in supportedExtensions) return true
        val pathExtension = Uri.parse(url.orEmpty()).lastPathSegment
            ?.substringAfterLast('.', missingDelimiterValue = "")
            ?.lowercase()
        return pathExtension in supportedExtensions
    }

    fun enqueue(
        context: Context,
        url: String,
        userAgent: String?,
        contentDisposition: String?,
        mimeType: String?,
        referer: String?,
    ): Map<String, Any?> {
        require(isHttpUrl(url)) { "Only http/https downloads are supported." }
        require(looksLikeAudio(url, contentDisposition, mimeType)) { "This link does not look like a supported audio file." }

        val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val fileName = sanitizeFileName(URLUtil.guessFileName(url, contentDisposition, mimeType))
        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle(fileName)
            .setDescription("Saving to WaveZero Device Music")
            .setAllowedOverMetered(true)
            .setAllowedOverRoaming(true)
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED)
            .setDestinationInExternalPublicDir(Environment.DIRECTORY_MUSIC, "WaveZero/$fileName")

        if (!mimeType.isNullOrBlank()) request.setMimeType(mimeType)
        if (!userAgent.isNullOrBlank()) request.addRequestHeader("User-Agent", userAgent)
        if (!referer.isNullOrBlank() && isHttpUrl(referer)) request.addRequestHeader("Referer", referer)
        CookieManager.getInstance().getCookie(url)?.takeIf { it.isNotBlank() }?.let { cookie ->
            request.addRequestHeader("Cookie", cookie)
        }

        val id = manager.enqueue(request)
        return mapOf(
            "id" to id,
            "status" to "pending",
            "fileName" to fileName,
            "downloadedBytes" to 0L,
            "totalBytes" to 0L,
        )
    }

    fun query(context: Context, id: Long): Map<String, Any?> {
        val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val query = DownloadManager.Query().setFilterById(id)
        manager.query(query)?.use { cursor ->
            if (!cursor.moveToFirst()) {
                return mapOf("id" to id, "status" to "missing", "fileName" to "WaveZero download")
            }
            val status = cursor.intColumn(DownloadManager.COLUMN_STATUS)
            val reason = cursor.intColumn(DownloadManager.COLUMN_REASON)
            val downloaded = cursor.longColumn(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR)
            val total = cursor.longColumn(DownloadManager.COLUMN_TOTAL_SIZE_BYTES)
            val title = cursor.stringColumn(DownloadManager.COLUMN_TITLE) ?: "WaveZero download"
            val localUri = if (status == DownloadManager.STATUS_SUCCESSFUL) manager.getUriForDownloadedFile(id)?.toString() else null
            return mapOf(
                "id" to id,
                "status" to statusLabel(status),
                "fileName" to title,
                "downloadedBytes" to downloaded,
                "totalBytes" to total,
                "localUri" to localUri,
                "reason" to reason,
            )
        }
        return mapOf("id" to id, "status" to "missing", "fileName" to "WaveZero download")
    }

    fun cancel(context: Context, id: Long) {
        val manager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        manager.remove(id)
    }

    private fun statusLabel(status: Int): String = when (status) {
        DownloadManager.STATUS_PENDING -> "pending"
        DownloadManager.STATUS_RUNNING -> "running"
        DownloadManager.STATUS_PAUSED -> "paused"
        DownloadManager.STATUS_SUCCESSFUL -> "successful"
        DownloadManager.STATUS_FAILED -> "failed"
        else -> "unknown"
    }

    private fun sanitizeFileName(raw: String): String {
        val cleaned = raw
            .replace(Regex("[\\\\/:*?\"<>|]+"), "_")
            .replace(Regex("\\s+"), " ")
            .trim()
            .take(180)
        return cleaned.ifBlank { "wavezero-audio-${System.currentTimeMillis()}.mp3" }
    }

    private fun android.database.Cursor.intColumn(name: String): Int {
        val index = getColumnIndex(name)
        return if (index < 0 || isNull(index)) 0 else getInt(index)
    }

    private fun android.database.Cursor.longColumn(name: String): Long {
        val index = getColumnIndex(name)
        return if (index < 0 || isNull(index)) 0L else getLong(index)
    }

    private fun android.database.Cursor.stringColumn(name: String): String? {
        val index = getColumnIndex(name)
        return if (index < 0 || isNull(index)) null else getString(index)
    }
}
