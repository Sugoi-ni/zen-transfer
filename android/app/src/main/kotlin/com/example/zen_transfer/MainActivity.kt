package com.example.zen_transfer

import android.content.ClipData
import android.content.ClipboardManager
import android.graphics.Bitmap
import android.graphics.ImageDecoder
import android.os.Build
import android.provider.Settings
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterActivity() {
    private val DEVICE_CHANNEL = "com.example.zen_transfer/device_name"
    private val CLIPBOARD_CHANNEL = "com.zen.transfer/clipboard"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

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
