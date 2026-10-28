package pk.journeyonline.readyflights.ready_flights

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Used by lib/views/tours/tour_whatsapp.dart
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WHATSAPP_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "shareImage") {
                    result.success(
                        shareImageToWhatsApp(
                            phone = call.argument<String>("phone") ?: "",
                            text = call.argument<String>("text") ?: "",
                            path = call.argument<String>("path") ?: "",
                            mimeType = call.argument<String>("mimeType") ?: "image/*",
                        )
                    )
                } else {
                    result.notImplemented()
                }
            }
    }

    /**
     * Opens the WhatsApp chat of [phone] (international format, digits only)
     * with the image at [path] attached and [text] as its caption.
     * Returns false if neither WhatsApp nor WhatsApp Business could take it,
     * so the Dart side can fall back to a wa.me link.
     */
    private fun shareImageToWhatsApp(
        phone: String,
        text: String,
        path: String,
        mimeType: String,
    ): Boolean {
        return try {
            val file = File(path)
            if (phone.isEmpty() || !file.exists()) return false
            val uri = FileProvider.getUriForFile(this, "$packageName.tourshare", file)

            for (whatsAppPackage in listOf("com.whatsapp", "com.whatsapp.w4b")) {
                val intent = Intent(Intent.ACTION_SEND).apply {
                    type = mimeType
                    setPackage(whatsAppPackage)
                    putExtra(Intent.EXTRA_STREAM, uri)
                    putExtra(Intent.EXTRA_TEXT, text)
                    // Opens the chat with this number directly instead of the contact picker.
                    putExtra("jid", "$phone@s.whatsapp.net")
                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                try {
                    startActivity(intent)
                    return true
                } catch (e: ActivityNotFoundException) {
                    // Not installed, try the next WhatsApp app.
                }
            }
            false
        } catch (e: Exception) {
            false
        }
    }

    companion object {
        private const val WHATSAPP_CHANNEL = "flypakistan/whatsapp"
    }
}
