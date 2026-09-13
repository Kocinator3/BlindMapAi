package org.slepamapa.slepa_mapa

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingExport: MethodChannel.Result? = null
    private var exportBytes: ByteArray? = null
    private val exportRequest = 4017

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "org.slepamapa/files")
            .setMethodCallHandler { call, result ->
                if (call.method != "exportJson") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val content = call.argument<String>("content")
                if (pendingExport != null || content == null || content.toByteArray(Charsets.UTF_8).size > 2097152) {
                    result.error("EXPORT_INVALID", "An export is already open, or content exceeds 2 MiB.", null)
                    return@setMethodCallHandler
                }
                pendingExport = result
                exportBytes = content.toByteArray(Charsets.UTF_8)
                try {
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/json"
                        putExtra(Intent.EXTRA_TITLE, "level.json")
                    }
                    @Suppress("DEPRECATION")
                    startActivityForResult(intent, exportRequest)
                } catch (_: Exception) {
                    pendingExport = null
                    exportBytes = null
                    result.error("EXPORT_UNAVAILABLE", "No document application can save this file.", null)
                }
            }
    }

    @Deprecated("Platform callback used for the document chooser")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != exportRequest) return
        val result = pendingExport ?: return
        val bytes = exportBytes
        pendingExport = null
        exportBytes = null
        if (resultCode != Activity.RESULT_OK || data?.data == null || bytes == null) {
            result.success(false)
            return
        }
        val uri = data.data!!
        // File providers can be slow; avoid blocking the UI thread.
        Thread {
            try {
                val stream = contentResolver.openOutputStream(uri, "wt")
                    ?: throw java.io.IOException("No writable output stream")
                stream.use { it.write(bytes); it.flush() }
                runOnUiThread { result.success(true) }
            } catch (_: Exception) {
                runOnUiThread { result.error("EXPORT_WRITE", "Could not write the selected document. Check available storage and permissions.", null) }
            }
        }.start()
    }
}
