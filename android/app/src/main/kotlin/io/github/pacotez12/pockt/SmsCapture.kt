package io.github.pacotez12.pockt

import android.Manifest
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class SmsCapture(
    private val activity: Activity,
    private val channel: MethodChannel,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val REQUEST_CODE_SMS_PERMISSIONS = 4828
        @Volatile
        var activeChannel: MethodChannel? = null

        fun hasSmsPermissions(context: Context): Boolean {
            val receive = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.RECEIVE_SMS,
            ) == PackageManager.PERMISSION_GRANTED
            val read = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_SMS,
            ) == PackageManager.PERMISSION_GRANTED
            return receive && read
        }
    }

    private var pendingPermissionResult: MethodChannel.Result? = null

    init {
        activeChannel = channel
    }

    fun detach() {
        if (activeChannel === channel) {
            activeChannel = null
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermissions" -> {
                result.success(hasSmsPermissions(activity))
            }
            "requestPermissions" -> {
                if (hasSmsPermissions(activity)) {
                    result.success(true)
                    return
                }
                if (pendingPermissionResult != null) {
                    result.success(false)
                    return
                }
                pendingPermissionResult = result
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(
                        Manifest.permission.RECEIVE_SMS,
                        Manifest.permission.READ_SMS,
                    ),
                    REQUEST_CODE_SMS_PERMISSIONS,
                )
            }
            "readInboxSince" -> {
                if (!hasSmsPermissions(activity)) {
                    result.success(emptyList<Map<String, Any>>())
                    return
                }
                val sinceEpochMs = call.argument<Number>("sinceEpochMs")?.toLong() ?: 0L
                val messages = readItauInboxSince(activity, sinceEpochMs)
                result.success(messages)
            }
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != REQUEST_CODE_SMS_PERMISSIONS) return false
        val pending = pendingPermissionResult ?: return true
        pendingPermissionResult = null
        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        pending.success(granted)
        return true
    }

    private fun readItauInboxSince(
        context: Context,
        sinceEpochMs: Long,
    ): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        try {
            val uri = Uri.parse("content://sms/inbox")
            val projection = arrayOf("address", "body", "date")
            val selection = "address LIKE ? AND date >= ?"
            val selectionArgs = arrayOf("%4828", sinceEpochMs.toString())
            context.contentResolver.query(
                uri,
                projection,
                selection,
                selectionArgs,
                "date ASC",
            )?.use { cursor ->
                val addrIdx = cursor.getColumnIndex("address")
                val bodyIdx = cursor.getColumnIndex("body")
                val dateIdx = cursor.getColumnIndex("date")
                while (cursor.moveToNext()) {
                    val sender = if (addrIdx >= 0) cursor.getString(addrIdx) ?: "" else ""
                    val body = if (bodyIdx >= 0) cursor.getString(bodyIdx) ?: "" else ""
                    val dateMs = if (dateIdx >= 0) cursor.getLong(dateIdx) else 0L
                    if (sender.trim().endsWith("4828") && body.isNotBlank()) {
                        list.add(
                            mapOf(
                                "sender" to sender.trim(),
                                "body" to body,
                                "receivedAtMs" to dateMs,
                            ),
                        )
                    }
                }
            }
        } catch (_: Exception) {
        }
        return list
    }
}

class SmsCaptureReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return
        val pdus = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (pdus.isEmpty()) return

        val bySender = linkedMapOf<String, Pair<StringBuilder, Long>>()
        for (msg in pdus) {
            val sender = msg.originatingAddress?.trim() ?: continue
            if (!sender.endsWith("4828")) continue
            val bodyPart = msg.messageBody ?: continue
            val ts = if (msg.timestampMillis > 0) msg.timestampMillis else System.currentTimeMillis()
            val entry = bySender.getOrPut(sender) { Pair(StringBuilder(), ts) }
            entry.first.append(bodyPart)
        }

        if (bySender.isEmpty()) return

        val fgChannel = SmsCapture.activeChannel
        if (fgChannel != null) {
            val mainHandler = Handler(Looper.getMainLooper())
            for ((sender, pair) in bySender) {
                val payload = mapOf(
                    "sender" to sender,
                    "body" to pair.first.toString(),
                    "receivedAtMs" to pair.second,
                )
                mainHandler.post {
                    try {
                        fgChannel.invokeMethod("onSmsReceived", payload)
                    } catch (_: Exception) {
                    }
                }
            }
            return
        }

        // App cerrada: levantar un isolate de fondo para guardar en Drift y notificar
        val pendingResult = goAsync()
        val appContext = context.applicationContext
        Handler(Looper.getMainLooper()).post {
            try {
                val loader = FlutterInjector.instance().flutterLoader()
                loader.startInitialization(appContext)
                loader.ensureInitializationComplete(appContext, null)

                val firstEntry = bySender.entries.first()
                val sender = firstEntry.key
                val body = firstEntry.value.first.toString()
                val tsMs = firstEntry.value.second.toString()

                val engine = FlutterEngine(appContext)
                val entrypoint = DartExecutor.DartEntrypoint(
                    loader.findAppBundlePath(),
                    "package:pockt/features/capture/data/android_sms_source.dart",
                    "smsBackgroundMain",
                )
                engine.dartExecutor.executeDartEntrypoint(
                    entrypoint,
                    listOf(sender, body, tsMs),
                )

                Handler(Looper.getMainLooper()).postDelayed({
                    try {
                        engine.destroy()
                    } catch (_: Exception) {
                    }
                    try {
                        pendingResult.finish()
                    } catch (_: Exception) {
                    }
                }, 4500L)
            } catch (_: Exception) {
                try {
                    pendingResult.finish()
                } catch (_: Exception) {
                }
            }
        }
    }
}
