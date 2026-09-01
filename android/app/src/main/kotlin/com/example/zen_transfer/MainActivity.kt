package com.example.zen_transfer

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.provider.Settings
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.InputStream

class MainActivity : FlutterActivity() {
    private val DEVICE_CHANNEL = "com.example.zen_transfer/device_name"
    private val CLIPBOARD_CHANNEL = "com.zen.transfer/clipboard"
    private val SHARE_CHANNEL = "com.zen.transfer/share"
    private val SHARE_EVENT_CHANNEL = "com.zen.transfer/share_events"

    private var sharedText: String? = null
    private var sharedUris: MutableList<Uri>? = null

    private var shareEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Share events channel — pushes a signal to Dart whenever a new
        // ACTION_SEND intent arrives while the app is already running.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    shareEventSink = events
                }
                override fun onCancel(arguments: Any?) {
                    shareEventSink = null
                }
            })


        // Device name channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DEVICE_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getDeviceName") {
                    val name = Settings.Global.getString(contentResolver, "device_name")
                        ?: android.os.Build.MODEL
                        ?: "Android"
                    result.success(name)
                } else {
                    result.notImplemented()
                }
            }

        // Clipboard image channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CLIPBOARD_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getClipboardImage") {
                    val imageData = getClipboardImage()
                    if (imageData != null) {
                        result.success(imageData)
                    } else {
                        result.success(null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        // Share sheet channel — returns content shared from other apps
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getSharedContent" -> {
                        val payload = buildSharedPayload()
                        result.success(payload)
                        // Clear after delivery so re-entry shows fresh state
                        sharedText = null
                        sharedUris = null
                    }
                    "readSharedFile" -> {
                        val uriString = call.argument<String>("uri")
                        if (uriString == null) {
                            result.error("NO_URI", "Missing uri argument", null)
                        } else {
                            try {
                                val bytes = readUriBytes(Uri.parse(uriString))
                                result.success(bytes)
                            } catch (e: Exception) {
                                result.error("READ_FAILED", e.message, null)
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Read a content:// uri fully into a byte array */
    private fun readUriBytes(uri: Uri): ByteArray {
        val stream: InputStream = contentResolver.openInputStream(uri)
            ?: throw Exception("Cannot open stream for $uri")
        return stream.use { it.readBytes() }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        processIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        processIntent(intent)
    }

    /** Capture ACTION_SEND / ACTION_SEND_MULTIPLE content */
    private fun processIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action ?: return
        android.util.Log.d("ZenShare", "processIntent action=$action type=${intent.type}")

        var captured = false

        when (action) {
            Intent.ACTION_SEND -> {
                val type = intent.type ?: ""
                if (type.startsWith("text/")) {
                    sharedText = intent.getStringExtra(Intent.EXTRA_TEXT)
                    android.util.Log.d("ZenShare", "Captured text: $sharedText")
                    sharedUris = null
                } else {
                    // Single file share (image/*, application/*, etc.)
                    val uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                    } else {
                        @Suppress("DEPRECATION")
                        intent.getParcelableExtra(Intent.EXTRA_STREAM)
                    }
                    if (uri != null) {
                        sharedUris = mutableListOf(uri)
                    }
                    sharedText = null
                }
                captured = true
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = mutableListOf<Uri>()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                        ?.let { uris.addAll(it) }
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                        ?.let { uris.addAll(it) }
                }
                sharedUris = uris
                sharedText = null
                captured = true
            }
        }

        // If a new share just landed (e.g. via onNewIntent while the app is
        // already open), nudge the Dart side so it re-reads the content.
        if (captured && action == Intent.ACTION_SEND || captured && action == Intent.ACTION_SEND_MULTIPLE) {
            shareEventSink?.success(1)
        }
    }

    /** Build JSON payload for Flutter: {type: "text"|"files", text, files:[{uri,name,mime}]} */
    private fun buildSharedPayload(): String {
        val root = JSONObject()

        if (sharedText != null) {
            root.put("type", "text")
            root.put("text", sharedText)
            return root.toString()
        }

        val uris = sharedUris ?: return "{\"type\":\"none\"}"
        val files = JSONArray()
        for (uri in uris) {
            try {
                val name = queryDisplayName(uri) ?: "shared_file"
                files.put(JSONObject()
                    .put("uri", uri.toString())
                    .put("name", name)
                    .put("mime", contentResolver.getType(uri) ?: "application/octet-stream"))
            } catch (e: Exception) {
                // skip unreadable uri
            }
        }
        if (files.length() == 0) return "{\"type\":\"none\"}"
        root.put("type", "files")
        root.put("files", files)
        return root.toString()
    }

    private fun queryDisplayName(uri: Uri): String? {
        return try {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val idx = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (idx >= 0) cursor.getString(idx) else null
                    } else null
                }
        } catch (e: Exception) {
            null
        }
    }

    private fun getClipboardImage(): ByteArray? {
        val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
        val clipData: ClipData? = clipboard.primaryClip

        if (clipData != null && clipData.itemCount > 0) {
            val item = clipData.getItemAt(0)

            // Try to get URI (modern Android)
            val uri = item.uri
            if (uri != null) {
                try {
                    val bitmap = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        val source = ImageDecoder.createSource(contentResolver, uri)
                        ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
                            decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                        }
                    } else {
                        @Suppress("DEPRECATION")
                        android.provider.MediaStore.Images.Media.getBitmap(contentResolver, uri)
                    }

                    val stream = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                    bitmap.recycle()
                    return stream.toByteArray()
                } catch (e: Exception) {
                    // Failed to decode image
                }
            }

            // Try to get text that might be an image
            val text = item.text?.toString()
            if (text != null && text.startsWith("data:image")) {
                // Base64 encoded image data
                try {
                    val base64Data = text.substringAfter("base64,")
                    return Base64.decode(base64Data, Base64.DEFAULT)
                } catch (e: Exception) {
                    // Failed to decode base64
                }
            }
        }

        return null
    }
}