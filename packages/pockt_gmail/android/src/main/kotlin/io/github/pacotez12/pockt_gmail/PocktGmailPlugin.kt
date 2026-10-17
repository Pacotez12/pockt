package io.github.pacotez12.pockt_gmail

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.text.Html
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.auth.api.signin.GoogleSignInOptions
import com.google.android.gms.common.api.Scope
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.concurrent.Executors

class PocktGmailPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware, PluginRegistry.ActivityResultListener {
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var activity: Activity? = null
    private var activityBinding: ActivityPluginBinding? = null

    private var pendingAuthorizeResult: MethodChannel.Result? = null
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    companion object {
        private const val RC_AUTHORIZE = 9021
        private const val GMAIL_READONLY_SCOPE = "https://www.googleapis.com/auth/gmail.readonly"
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "pockt/gmail")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "authorize" -> handleAuthorize(result)
            "fetchSince" -> {
                val sinceMillis = (call.argument<Number>("sinceMillis"))?.toLong() ?: 0L
                handleFetchSince(sinceMillis, result)
            }
            "disconnect" -> handleDisconnect(result)
            else -> result.notImplemented()
        }
    }

    private fun handleAuthorize(result: MethodChannel.Result) {
        val currentContext = activity ?: context
        if (currentContext == null) {
            result.error("no_context", "Context is not available", null)
            return
        }

        val request = AuthorizationRequest.builder()
            .setRequestedScopes(listOf(Scope(GMAIL_READONLY_SCOPE)))
            .build()

        val authClient = Identity.getAuthorizationClient(currentContext)
        authClient.authorize(request)
            .addOnSuccessListener { authResult ->
                if (authResult.hasResolution()) {
                    val currentActivity = activity
                    if (currentActivity == null) {
                        result.error("needsReconnect", "Activity required to resolve authorization", null)
                        return@addOnSuccessListener
                    }
                    val pendingIntent = authResult.pendingIntent
                    if (pendingIntent != null) {
                        pendingAuthorizeResult = result
                        try {
                            currentActivity.startIntentSenderForResult(
                                pendingIntent.intentSender,
                                RC_AUTHORIZE,
                                null,
                                0,
                                0,
                                0
                            )
                        } catch (e: Exception) {
                            pendingAuthorizeResult = null
                            result.error("intent_error", e.localizedMessage, null)
                        }
                    } else {
                        result.success("cancelled")
                    }
                } else if (authResult.accessToken != null) {
                    result.success("connected")
                } else {
                    result.success("cancelled")
                }
            }
            .addOnFailureListener { e ->
                result.error("auth_failure", e.localizedMessage, null)
            }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode == RC_AUTHORIZE) {
            val pendingResult = pendingAuthorizeResult ?: return false
            pendingAuthorizeResult = null
            if (resultCode == Activity.RESULT_OK) {
                pendingResult.success("connected")
            } else {
                pendingResult.success("cancelled")
            }
            return true
        }
        return false
    }

    private fun handleFetchSince(sinceMillis: Long, result: MethodChannel.Result) {
        val currentContext = context
        if (currentContext == null) {
            result.error("no_context", "Context not available", null)
            return
        }

        val request = AuthorizationRequest.builder()
            .setRequestedScopes(listOf(Scope(GMAIL_READONLY_SCOPE)))
            .build()

        val authClient = Identity.getAuthorizationClient(currentContext)
        authClient.authorize(request)
            .addOnSuccessListener { authResult ->
                if (authResult.hasResolution()) {
                    result.error("needsReconnect", "Interaction required for Gmail authorization", null)
                    return@addOnSuccessListener
                }

                val token = authResult.accessToken
                if (token.isNullOrEmpty()) {
                    result.error("needsReconnect", "No access token available", null)
                    return@addOnSuccessListener
                }

                executor.execute {
                    try {
                        val epochSeconds = sinceMillis / 1000
                        val query = "from:info@itau.com.py after:$epochSeconds"
                        val messageIds = mutableListOf<String>()
                        var pageToken: String? = null

                        do {
                            var urlStr = "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=" +
                                    URLEncoder.encode(query, "UTF-8")
                            if (!pageToken.isNullOrEmpty()) {
                                urlStr += "&pageToken=" + URLEncoder.encode(pageToken, "UTF-8")
                            }

                            val conn = (URL(urlStr).openConnection() as HttpURLConnection).apply {
                                requestMethod = "GET"
                                setRequestProperty("Authorization", "Bearer $token")
                                connectTimeout = 15000
                                readTimeout = 15000
                            }

                            val code = conn.responseCode
                            if (code == 401) {
                                mainHandler.post {
                                    result.error("needsReconnect", "Gmail token expired or invalid", null)
                                }
                                return@execute
                            }
                            if (code !in 200..299) {
                                val err = conn.errorStream?.bufferedReader()?.use { it.readText() } ?: "HTTP $code"
                                mainHandler.post {
                                    result.error("httpError", err, null)
                                }
                                return@execute
                            }

                            val jsonStr = conn.inputStream.bufferedReader().use { it.readText() }
                            val json = JSONObject(jsonStr)
                            if (json.has("messages")) {
                                val msgs = json.getJSONArray("messages")
                                for (i in 0 until msgs.length()) {
                                    val m = msgs.getJSONObject(i)
                                    messageIds.add(m.getString("id"))
                                }
                            }
                            pageToken = if (json.has("nextPageToken")) json.optString("nextPageToken") else null
                        } while (!pageToken.isNullOrEmpty())

                        val emails = mutableListOf<Map<String, Any>>()
                        for (id in messageIds) {
                            val msgUrl = "https://gmail.googleapis.com/gmail/v1/users/me/messages/$id?format=full"
                            val conn = (URL(msgUrl).openConnection() as HttpURLConnection).apply {
                                requestMethod = "GET"
                                setRequestProperty("Authorization", "Bearer $token")
                                connectTimeout = 15000
                                readTimeout = 15000
                            }

                            if (conn.responseCode == 200) {
                                val jsonStr = conn.inputStream.bufferedReader().use { it.readText() }
                                val json = JSONObject(jsonStr)
                                val internalDate = json.optLong("internalDate", System.currentTimeMillis())
                                val payload = json.optJSONObject("payload")
                                var subject = ""
                                if (payload != null && payload.has("headers")) {
                                    val headers = payload.getJSONArray("headers")
                                    for (h in 0 until headers.length()) {
                                        val header = headers.getJSONObject(h)
                                        if ("Subject".equals(header.optString("name"), ignoreCase = true)) {
                                            subject = header.optString("value")
                                            break
                                        }
                                    }
                                }
                                val rawContent = extractBody(payload)
                                val bodyText = convertHtmlToFormattedText(rawContent)
                                emails.add(
                                    mapOf(
                                        "id" to id,
                                        "internalDate" to internalDate,
                                        "subject" to subject,
                                        "bodyText" to bodyText
                                    )
                                )
                            }
                        }

                        mainHandler.post {
                            result.success(emails)
                        }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("fetch_error", e.localizedMessage, null)
                        }
                    }
                }
            }
            .addOnFailureListener { e ->
                result.error("needsReconnect", e.localizedMessage, null)
            }
    }

    private fun handleDisconnect(result: MethodChannel.Result) {
        val currentContext = context ?: activity
        if (currentContext != null) {
            try {
                val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN).build()
                GoogleSignIn.getClient(currentContext, gso).revokeAccess()
            } catch (_: Exception) {}
        }
        result.success(null)
    }

    private fun extractBody(payload: JSONObject?): String {
        if (payload == null) return ""
        val body = payload.optJSONObject("body")
        val data = body?.optString("data", "") ?: ""
        if (data.isNotEmpty()) {
            val decoded = decodeBase64Url(data)
            if (decoded.isNotEmpty()) return decoded
        }
        val parts = payload.optJSONArray("parts")
        if (parts != null) {
            var htmlCandidate = ""
            var textCandidate = ""
            for (i in 0 until parts.length()) {
                val part = parts.getJSONObject(i)
                val partMime = part.optString("mimeType", "")
                val partBody = extractBody(part)
                if (partMime.equals("text/html", ignoreCase = true)) {
                    htmlCandidate = partBody
                } else if (partMime.equals("text/plain", ignoreCase = true)) {
                    textCandidate = partBody
                } else if (htmlCandidate.isEmpty() && partBody.isNotEmpty()) {
                    htmlCandidate = partBody
                }
            }
            if (htmlCandidate.isNotEmpty()) return htmlCandidate
            if (textCandidate.isNotEmpty()) return textCandidate
        }
        return ""
    }

    private fun decodeBase64Url(data: String): String {
        return try {
            val bytes = android.util.Base64.decode(data, android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP)
            String(bytes, Charsets.UTF_8)
        } catch (_: Exception) {
            ""
        }
    }

    private fun convertHtmlToFormattedText(rawHtml: String): String {
        if (rawHtml.isEmpty()) return ""
        // Solo el cierre de celda separa, así cada fila queda "Campo: | Valor |" como espera el parser.
        var processed = rawHtml.replace(Regex("(?i)</t[dh]>"), " | ")
        processed = processed.replace(Regex("(?i)<tr[^>]*>"), "\n")
        processed = processed.replace(Regex("(?i)</tr>"), "\n")
        val sp = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            Html.fromHtml(processed, Html.FROM_HTML_MODE_COMPACT)
        } else {
            @Suppress("DEPRECATION")
            Html.fromHtml(processed)
        }
        return sp.toString().trim()
    }
}
