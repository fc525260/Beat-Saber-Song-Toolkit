package app.beatspider.reborn

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.documentfile.provider.DocumentFile
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val openDocumentTreeRequest = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.beatspider.reborn/storage"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickDirectory" -> pickDirectory(result)
                "writeFile" -> writeFile(call.arguments, result)
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != openDocumentTreeRequest) {
            return
        }

        val result = pendingResult
        pendingResult = null
        if (result == null) {
            return
        }
        if (resultCode != Activity.RESULT_OK) {
            result.success(null)
            return
        }

        val uri = data?.data
        if (uri == null) {
            result.success(null)
            return
        }

        val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
            Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        contentResolver.takePersistableUriPermission(uri, flags)
        result.success(uri.toString())
    }

    private fun pickDirectory(result: MethodChannel.Result) {
        if (pendingResult != null) {
            result.error("busy", "A directory picker is already open.", null)
            return
        }
        pendingResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            addFlags(Intent.FLAG_GRANT_PREFIX_URI_PERMISSION)
        }
        startActivityForResult(intent, openDocumentTreeRequest)
    }

    private fun writeFile(arguments: Any?, result: MethodChannel.Result) {
        val args = arguments as? Map<*, *>
        val treeUri = args?.get("treeUri") as? String
        val relativePath = args?.get("relativePath") as? String
        val bytes = args?.get("bytes") as? ByteArray

        if (treeUri.isNullOrBlank() || relativePath.isNullOrBlank() || bytes == null) {
            result.error("invalid_args", "treeUri, relativePath, and bytes are required.", null)
            return
        }

        val root = DocumentFile.fromTreeUri(this, Uri.parse(treeUri))
        if (root == null || !root.canWrite()) {
            result.error("no_write_access", "Selected folder is not writable.", null)
            return
        }

        val segments = relativePath.split('/').filter { it.isNotBlank() }
        if (segments.isEmpty() || segments.any { it == "." || it == ".." }) {
            result.error("unsafe_path", "Unsafe relative path.", null)
            return
        }

        var parent: DocumentFile = root
        for (segment in segments.dropLast(1)) {
            parent = parent.findFile(segment) ?: parent.createDirectory(segment)
                ?: run {
                    result.error("mkdir_failed", "Could not create directory $segment.", null)
                    return
                }
        }

        val fileName = segments.last()
        parent.findFile(fileName)?.delete()
        val file = parent.createFile(mimeTypeFor(fileName), fileName)
        if (file == null) {
            result.error("create_failed", "Could not create file $fileName.", null)
            return
        }

        contentResolver.openOutputStream(file.uri, "w")?.use { stream ->
            stream.write(bytes)
        } ?: run {
            result.error("write_failed", "Could not open output stream.", null)
            return
        }

        result.success(null)
    }

    private fun mimeTypeFor(fileName: String): String {
        return when (fileName.substringAfterLast('.', "").lowercase()) {
            "jpg", "jpeg" -> "image/jpeg"
            "png" -> "image/png"
            "dat", "json" -> "application/json"
            "ogg", "egg" -> "audio/ogg"
            else -> "application/octet-stream"
        }
    }
}
