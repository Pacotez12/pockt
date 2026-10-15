package io.github.pacotez12.pockt

import android.app.Activity
import android.content.ContentUris
import android.content.ContentValues
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Copias de seguridad `.pockt` en una carpeta visible del teléfono
 * (Documentos/Pockt), que sobrevive a desinstalar la app.
 * En Android 10+ usa MediaStore; en 8–9 la carpeta externa de la app.
 */
class BackupFiles(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private var pendingPick: MethodChannel.Result? = null

    private val relativePath = "Documents/Pockt/"
    private val collection: Uri
        get() = MediaStore.Files.getContentUri("external")
    private val legacyDir: File
        get() = File(activity.getExternalFilesDir(null), "Pockt").apply { mkdirs() }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "save" -> result.success(save(call.argument<String>("name")!!, call.argument<ByteArray>("bytes")!!))
                "list" -> result.success(list())
                "read" -> result.success(read(call.argument<String>("id")!!))
                "delete" -> { delete(call.argument<String>("id")!!); result.success(null) }
                "pickFile" -> pickFile(result)
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("backup_files", e.message, null)
        }
    }

    private fun save(name: String, bytes: ByteArray): String {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val file = File(legacyDir, name)
            file.writeBytes(bytes)
            return Uri.fromFile(file).toString()
        }
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, name)
            put(MediaStore.MediaColumns.MIME_TYPE, "application/octet-stream")
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }
        val resolver = activity.contentResolver
        val uri = resolver.insert(collection, values) ?: throw IllegalStateException("No se pudo crear $name")
        resolver.openOutputStream(uri)!!.use { it.write(bytes) }
        values.clear()
        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
        return uri.toString()
    }

    private fun list(): List<Map<String, Any>> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            return legacyDir.listFiles { f -> f.name.endsWith(".pockt") }.orEmpty().map {
                mapOf("id" to Uri.fromFile(it).toString(), "name" to it.name,
                    "size" to it.length(), "modified" to it.lastModified())
            }
        }
        val out = mutableListOf<Map<String, Any>>()
        val projection = arrayOf(
            MediaStore.MediaColumns._ID,
            MediaStore.MediaColumns.DISPLAY_NAME,
            MediaStore.MediaColumns.SIZE,
            MediaStore.MediaColumns.DATE_MODIFIED,
        )
        activity.contentResolver.query(
            collection, projection,
            "${MediaStore.MediaColumns.RELATIVE_PATH}=? AND ${MediaStore.MediaColumns.DISPLAY_NAME} LIKE ?",
            arrayOf(relativePath, "%.pockt"), null,
        )?.use { c ->
            while (c.moveToNext()) {
                val uri = ContentUris.withAppendedId(collection, c.getLong(0))
                out.add(mapOf("id" to uri.toString(), "name" to c.getString(1),
                    "size" to c.getLong(2), "modified" to c.getLong(3) * 1000))
            }
        }
        return out
    }

    private fun read(id: String): ByteArray =
        activity.contentResolver.openInputStream(Uri.parse(id))!!.use { it.readBytes() }

    private fun delete(id: String) {
        val uri = Uri.parse(id)
        if (uri.scheme == "file") File(uri.path!!).delete() else activity.contentResolver.delete(uri, null, null)
    }

    private fun pickFile(result: MethodChannel.Result) {
        pendingPick?.success(null)
        pendingPick = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        @Suppress("DEPRECATION")
        activity.startActivityForResult(intent, PICK_REQUEST)
    }

    /** Devuelve true si el resultado era de este selector. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PICK_REQUEST) return false
        val result = pendingPick ?: return true
        pendingPick = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return true
        }
        try {
            var name = "copia.pockt"
            activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use {
                if (it.moveToFirst()) name = it.getString(0) ?: name
            }
            result.success(mapOf("name" to name, "bytes" to read(uri.toString())))
        } catch (e: Exception) {
            result.error("backup_files", e.message, null)
        }
        return true
    }

    companion object {
        const val PICK_REQUEST = 4721
    }
}
