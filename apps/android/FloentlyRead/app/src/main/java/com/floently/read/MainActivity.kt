package com.floently.read

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.net.http.SslError
import android.os.Build
import android.os.Bundle
import android.os.Message
import android.webkit.CookieManager
import android.webkit.PermissionRequest
import android.webkit.RenderProcessGoneDetail
import android.webkit.SslErrorHandler
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import com.floently.shared.design.FloentlyProduct
import com.floently.shared.design.floentlyPalette
import org.json.JSONTokener

class MainActivity : ComponentActivity() {
    private val incomingUrl = mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        incomingUrl.value = resolveIntent(intent)

        setContent {
            MaterialTheme {
                ReadBrowserScreen(
                    initialUrl = incomingUrl.value,
                    onExit = { finish() }
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        resolveIntent(intent)?.let { incomingUrl.value = it }
    }

    private fun resolveIntent(intent: Intent?): String? {
        intent ?: return null
        return when (intent.action) {
            Intent.ACTION_VIEW -> ReadBrowserPolicy.resolveIncomingUri(intent.data)
            Intent.ACTION_SEND -> ReadBrowserPolicy.normalizeAddress(intent.getStringExtra(Intent.EXTRA_TEXT))
            else -> null
        }
    }
}

@Composable
private fun ReadBrowserScreen(
    initialUrl: String?,
    onExit: () -> Unit
) {
    val context = LocalContext.current
    val palette = floentlyPalette(FloentlyProduct.Read)

    var webView by remember { mutableStateOf<WebView?>(null) }
    var currentUrl by remember { mutableStateOf<String?>(initialUrl) }
    var addressText by remember { mutableStateOf(initialUrl.orEmpty()) }
    var canGoBack by remember { mutableStateOf(false) }
    var canGoForward by remember { mutableStateOf(false) }
    var isLoading by remember { mutableStateOf(false) }
    var progress by remember { mutableIntStateOf(0) }
    var readingStatus by remember { mutableStateOf("Ready") }
    var extractedText by remember { mutableStateOf("") }
    var selectedText by remember { mutableStateOf("") }
    var rendererGeneration by remember { mutableIntStateOf(0) }
    var rendererCrashUrl by remember { mutableStateOf<String?>(null) }
    var rendererCrashCount by remember { mutableIntStateOf(0) }
    var rendererRecoveryBlocked by remember { mutableStateOf(false) }
    var filePathCallback by remember { mutableStateOf<ValueCallback<Array<Uri>>?>(null) }
    var pendingPermissionRequest by remember { mutableStateOf<PermissionRequest?>(null) }

    val fileChooserLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.StartActivityForResult()
    ) { result ->
        val value = WebChromeClient.FileChooserParams.parseResult(result.resultCode, result.data)
        filePathCallback?.onReceiveValue(value)
        filePathCallback = null
    }

    val webPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestMultiplePermissions()
    ) { grants ->
        val request = pendingPermissionRequest
        if (request != null) {
            val approved = request.resources.filter { resource ->
                when (resource) {
                    PermissionRequest.RESOURCE_VIDEO_CAPTURE -> grants[Manifest.permission.CAMERA] == true
                    PermissionRequest.RESOURCE_AUDIO_CAPTURE -> grants[Manifest.permission.RECORD_AUDIO] == true
                    else -> false
                }
            }
            if (approved.isEmpty()) request.deny() else request.grant(approved.toTypedArray())
        }
        pendingPermissionRequest = null
    }

    fun updateNavigation(view: WebView, url: String? = view.url) {
        url?.let {
            currentUrl = it
            addressText = it
        }
        canGoBack = view.canGoBack()
        canGoForward = view.canGoForward()
    }

    fun resetRendererRecovery() {
        rendererCrashUrl = null
        rendererCrashCount = 0
        rendererRecoveryBlocked = false
    }

    fun openExternal(uri: Uri) {
        try {
            context.startActivity(Intent(Intent.ACTION_VIEW, uri))
        } catch (_: ActivityNotFoundException) {
            readingStatus = "No app is available for this link."
        }
    }

    fun openAddress(raw: String) {
        val target = ReadBrowserPolicy.normalizeAddress(raw)
        if (target == null) {
            readingStatus = "Enter a valid website address or search term."
            return
        }
        resetRendererRecovery()
        addressText = target
        currentUrl = target
        extractedText = ""
        selectedText = ""
        readingStatus = "Loading…"
        webView?.loadUrl(target)
    }

    fun decodeJavascriptString(value: String?): String {
        if (value.isNullOrBlank() || value == "null") return ""
        return runCatching { JSONTokener(value).nextValue() as? String ?: "" }.getOrDefault("")
    }

    LaunchedEffect(initialUrl) {
        if (!initialUrl.isNullOrBlank() && initialUrl != currentUrl) {
            openAddress(initialUrl)
        }
    }

    BackHandler(enabled = canGoBack) {
        webView?.goBack()
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.backgroundTop)
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .background(palette.backgroundBottom)
                .padding(horizontal = 8.dp, vertical = 6.dp)
        ) {
            BrowserButton(
                label = if (canGoBack) "‹" else "×",
                enabled = true,
                contentDescription = if (canGoBack) "Back" else "Close browser"
            ) {
                if (canGoBack) webView?.goBack() else onExit()
            }

            BrowserButton(label = "›", enabled = canGoForward, contentDescription = "Forward") {
                webView?.goForward()
            }

            OutlinedTextField(
                value = addressText,
                onValueChange = { addressText = it },
                singleLine = true,
                placeholder = { Text("Search or enter website") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri, imeAction = ImeAction.Go),
                keyboardActions = KeyboardActions(onGo = { openAddress(addressText) }),
                shape = RoundedCornerShape(16.dp),
                modifier = Modifier
                    .weight(1f)
                    .height(52.dp)
            )

            BrowserButton(
                label = if (isLoading) "×" else "↻",
                enabled = currentUrl != null,
                contentDescription = if (isLoading) "Stop loading" else "Reload"
            ) {
                if (isLoading) webView?.stopLoading() else webView?.reload()
            }
        }

        if (isLoading) {
            LinearProgressIndicator(
                progress = { progress.coerceIn(0, 100) / 100f },
                color = palette.accent,
                modifier = Modifier.fillMaxWidth()
            )
        }

        Box(modifier = Modifier.weight(1f).fillMaxWidth()) {
            when {
                currentUrl == null -> {
                    BrowserStart(
                        paletteText = palette.text,
                        paletteMuted = palette.muted,
                        paletteAccent = palette.accent
                    )
                }

                rendererRecoveryBlocked -> {
                    RendererRecovery(
                        url = currentUrl.orEmpty(),
                        paletteText = palette.text,
                        paletteMuted = palette.muted,
                        paletteAccent = palette.accent,
                        onRetry = {
                            rendererCrashCount = 0
                            rendererRecoveryBlocked = false
                            rendererGeneration += 1
                            readingStatus = "Trying the page again…"
                        }
                    )
                }

                else -> {
                    key(rendererGeneration) {
                        AndroidView(
                            factory = { androidContext ->
                                WebView(androidContext).apply {
                                    webView = this
                                    settings.javaScriptEnabled = true
                                    settings.domStorageEnabled = true
                                    settings.databaseEnabled = true
                                    settings.setSupportMultipleWindows(true)
                                    settings.javaScriptCanOpenWindowsAutomatically = true
                                    settings.allowFileAccess = false
                                    settings.allowContentAccess = true
                                    settings.mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
                                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                        settings.safeBrowsingEnabled = true
                                    }

                                    CookieManager.getInstance().setAcceptCookie(true)
                                    CookieManager.getInstance().setAcceptThirdPartyCookies(this, true)

                                    webViewClient = object : WebViewClient() {
                                        override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean {
                                            val uri = request.url
                                            return when (uri.scheme?.lowercase()) {
                                                "http", "https", "about", "data", "blob" -> false
                                                else -> {
                                                    openExternal(uri)
                                                    true
                                                }
                                            }
                                        }

                                        override fun onPageStarted(view: WebView, url: String?, favicon: Bitmap?) {
                                            isLoading = true
                                            readingStatus = "Loading…"
                                            updateNavigation(view, url)
                                        }

                                        override fun onPageFinished(view: WebView, url: String?) {
                                            isLoading = false
                                            updateNavigation(view, url)
                                            // A completed page proves the replacement renderer is healthy.
                                            rendererCrashUrl = null
                                            rendererCrashCount = 0
                                            rendererRecoveryBlocked = false
                                            readingStatus = if (ReadBrowserPolicy.isProtectedAuthenticationUrl(url)) {
                                                "Finish signing in. Read will wait until you return to the website."
                                            } else {
                                                "Ready"
                                            }
                                        }

                                        override fun doUpdateVisitedHistory(view: WebView, url: String?, isReload: Boolean) {
                                            updateNavigation(view, url)
                                        }

                                        override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                                            if (request.isForMainFrame) {
                                                readingStatus = "Page failed to load: ${error.description}"
                                            }
                                        }

                                        override fun onReceivedSslError(view: WebView, handler: SslErrorHandler, error: SslError) {
                                            handler.cancel()
                                            readingStatus = "This website has a certificate problem. Read did not bypass it."
                                        }

                                        override fun onRenderProcessGone(view: WebView, detail: RenderProcessGoneDetail): Boolean {
                                            val crashedUrl = view.url ?: currentUrl
                                            currentUrl = crashedUrl
                                            if (crashedUrl != null && crashedUrl == rendererCrashUrl) {
                                                rendererCrashCount += 1
                                            } else {
                                                rendererCrashUrl = crashedUrl
                                                rendererCrashCount = 1
                                            }

                                            webView = null
                                            view.destroy()

                                            if (detail.didCrash() && rendererCrashCount >= 2) {
                                                // Android explicitly warns against endlessly reloading a page that
                                                // repeatedly crashes the renderer. Stop and require a user retry.
                                                rendererRecoveryBlocked = true
                                                isLoading = false
                                                readingStatus = "This page repeatedly crashed the web renderer. Automatic reload was stopped."
                                            } else {
                                                readingStatus = "The page renderer restarted. Restoring the page…"
                                                rendererGeneration += 1
                                            }
                                            return true
                                        }
                                    }

                                    webChromeClient = object : WebChromeClient() {
                                        override fun onProgressChanged(view: WebView, newProgress: Int) {
                                            progress = newProgress
                                            isLoading = newProgress < 100
                                            updateNavigation(view)
                                        }

                                        override fun onReceivedTitle(view: WebView, title: String?) {
                                            updateNavigation(view)
                                        }

                                        override fun onCreateWindow(
                                            view: WebView,
                                            isDialog: Boolean,
                                            isUserGesture: Boolean,
                                            resultMsg: Message
                                        ): Boolean {
                                            val popup = WebView(view.context)
                                            popup.webViewClient = object : WebViewClient() {
                                                override fun shouldOverrideUrlLoading(popupView: WebView, request: WebResourceRequest): Boolean {
                                                    val uri = request.url
                                                    when (uri.scheme?.lowercase()) {
                                                        "http", "https" -> view.loadUrl(uri.toString())
                                                        else -> openExternal(uri)
                                                    }
                                                    popupView.stopLoading()
                                                    popupView.destroy()
                                                    return true
                                                }

                                                override fun onPageStarted(popupView: WebView, url: String?, favicon: Bitmap?) {
                                                    if (!url.isNullOrBlank() && url != "about:blank") {
                                                        ReadBrowserPolicy.normalizeAddress(url)?.let(view::loadUrl)
                                                        popupView.stopLoading()
                                                        popupView.destroy()
                                                    }
                                                }
                                            }
                                            (resultMsg.obj as? WebView.WebViewTransport)?.webView = popup
                                            resultMsg.sendToTarget()
                                            return true
                                        }

                                        override fun onShowFileChooser(
                                            webView: WebView,
                                            filePath: ValueCallback<Array<Uri>>,
                                            fileChooserParams: FileChooserParams
                                        ): Boolean {
                                            filePathCallback?.onReceiveValue(null)
                                            filePathCallback = filePath
                                            return try {
                                                fileChooserLauncher.launch(fileChooserParams.createIntent())
                                                true
                                            } catch (_: ActivityNotFoundException) {
                                                filePathCallback?.onReceiveValue(null)
                                                filePathCallback = null
                                                false
                                            }
                                        }

                                        override fun onPermissionRequest(request: PermissionRequest) {
                                            val permissions = buildList {
                                                if (PermissionRequest.RESOURCE_VIDEO_CAPTURE in request.resources) add(Manifest.permission.CAMERA)
                                                if (PermissionRequest.RESOURCE_AUDIO_CAPTURE in request.resources) add(Manifest.permission.RECORD_AUDIO)
                                            }
                                            if (permissions.isEmpty()) {
                                                request.deny()
                                                return
                                            }
                                            pendingPermissionRequest = request
                                            webPermissionLauncher.launch(permissions.distinct().toTypedArray())
                                        }

                                        override fun onPermissionRequestCanceled(request: PermissionRequest) {
                                            if (pendingPermissionRequest === request) pendingPermissionRequest = null
                                        }
                                    }

                                    setDownloadListener { url, _, _, _, _ ->
                                        runCatching { openExternal(Uri.parse(url)) }
                                    }

                                    currentUrl?.let { loadUrl(it) }
                                }
                            },
                            update = { view ->
                                webView = view
                                updateNavigation(view)
                            },
                            modifier = Modifier.fillMaxSize()
                        )
                    }

                    ReadStrip(
                        status = readingStatus,
                        accent = palette.accent,
                        surface = palette.backgroundBottom,
                        textColor = palette.text,
                        onReadPage = {
                            val view = webView
                            val url = view?.url
                            if (view == null || url.isNullOrBlank()) return@ReadStrip
                            if (ReadBrowserPolicy.isProtectedAuthenticationUrl(url)) {
                                readingStatus = "Finish signing in before using Read on this page."
                                return@ReadStrip
                            }
                            readingStatus = "Finding the main reading area…"
                            view.evaluateJavascript(ReadBrowserPolicy.pageExtractionJavaScript) { result ->
                                val text = decodeJavascriptString(result).trim()
                                extractedText = text
                                val words = text.split(Regex("\\s+")).count { it.isNotBlank() }
                                readingStatus = if (words == 0) {
                                    "No readable lesson or article text was found on the visible page."
                                } else {
                                    "Ready to read $words words from the live page."
                                }
                            }
                        },
                        onReadSelection = {
                            val view = webView
                            val url = view?.url
                            if (view == null || url.isNullOrBlank()) return@ReadStrip
                            if (ReadBrowserPolicy.isProtectedAuthenticationUrl(url)) {
                                readingStatus = "Finish signing in before using Read on this page."
                                return@ReadStrip
                            }
                            view.evaluateJavascript(ReadBrowserPolicy.selectionExtractionJavaScript) { result ->
                                selectedText = decodeJavascriptString(result).trim()
                                readingStatus = if (selectedText.isBlank()) "Select text on the page first." else "Selection ready to read."
                            }
                        },
                        modifier = Modifier
                            .align(Alignment.BottomCenter)
                            .padding(horizontal = 12.dp, vertical = 10.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun BrowserStart(paletteText: Color, paletteMuted: Color, paletteAccent: Color) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier
            .fillMaxSize()
            .padding(28.dp)
    ) {
        Text("◎", color = paletteAccent, style = MaterialTheme.typography.displayMedium)
        Spacer(Modifier.height(16.dp))
        Text("Browse the real website", color = paletteText, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(10.dp))
        Text(
            "Enter a course, article or website above. Read keeps the original page interactive and stays available while you navigate.",
            color = paletteMuted,
            style = MaterialTheme.typography.bodyLarge
        )
    }
}

@Composable
private fun RendererRecovery(
    url: String,
    paletteText: Color,
    paletteMuted: Color,
    paletteAccent: Color,
    onRetry: () -> Unit
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier
            .fillMaxSize()
            .padding(28.dp)
    ) {
        Text("Page paused", color = paletteText, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.SemiBold)
        Spacer(Modifier.height(10.dp))
        Text(
            "The web renderer crashed more than once while loading ${Uri.parse(url).host ?: "this site"}. Read stopped automatic reloads to avoid a crash loop.",
            color = paletteMuted,
            style = MaterialTheme.typography.bodyLarge
        )
        Spacer(Modifier.height(18.dp))
        Button(onClick = onRetry, colors = ButtonDefaults.buttonColors(containerColor = paletteAccent)) {
            Text("Try again")
        }
    }
}

@Composable
private fun BrowserButton(
    label: String,
    enabled: Boolean,
    contentDescription: String,
    onClick: () -> Unit
) {
    Button(
        onClick = onClick,
        enabled = enabled,
        contentPadding = androidx.compose.foundation.layout.PaddingValues(0.dp),
        colors = ButtonDefaults.buttonColors(containerColor = Color.Transparent),
        modifier = Modifier.size(48.dp)
    ) {
        Text(label, style = MaterialTheme.typography.headlineSmall)
    }
}

@Composable
private fun ReadStrip(
    status: String,
    accent: Color,
    surface: Color,
    textColor: Color,
    onReadPage: () -> Unit,
    onReadSelection: () -> Unit,
    modifier: Modifier = Modifier
) {
    Surface(
        color = surface.copy(alpha = 0.96f),
        shape = RoundedCornerShape(24.dp),
        tonalElevation = 8.dp,
        shadowElevation = 12.dp,
        modifier = modifier.fillMaxWidth()
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.padding(8.dp)
        ) {
            Button(
                onClick = onReadPage,
                colors = ButtonDefaults.buttonColors(containerColor = accent),
                shape = RoundedCornerShape(24.dp),
                modifier = Modifier.height(48.dp)
            ) {
                Text("Read page", fontWeight = FontWeight.SemiBold)
            }

            Button(
                onClick = onReadSelection,
                colors = ButtonDefaults.buttonColors(containerColor = surface),
                modifier = Modifier.height(48.dp)
            ) {
                Text("Select")
            }

            Text(
                text = status,
                color = textColor.copy(alpha = 0.84f),
                style = MaterialTheme.typography.bodySmall,
                maxLines = 2,
                modifier = Modifier.weight(1f)
            )
        }
    }
}
