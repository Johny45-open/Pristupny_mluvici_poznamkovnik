package com.example.mluvici_pristupny_poznamkovnik

import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Context
import android.view.accessibility.AccessibilityManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.example.mluvici_pristupny_poznamkovnik/accessibility"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "screenReaderActive" -> result.success(screenReaderActive())
                    "announce" -> result.success(
                        announceForScreenReader(call.argument<String>("text") ?: "")
                    )
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Vrátí true, pokud je na zařízení zapnutá čtečka obrazovky,
     * tedy přístupnost služba se slovní zpětnou vazbou (např. TalkBack).
     */
    private fun screenReaderActive(): Boolean {
        val manager =
            getSystemService(Context.ACCESSIBILITY_SERVICE) as? AccessibilityManager
                ?: return false
        if (!manager.isEnabled) return false
        val services = manager.getEnabledAccessibilityServiceList(
            AccessibilityServiceInfo.FEEDBACK_SPOKEN
        )
        return services.isNotEmpty()
    }

    /**
     * Předá hlášku [text] běžící čtečce obrazovky.
     * Metoda [android.view.View.announceForAccessibility] vrací void,
     * takže o „doručení“ se staráme detekcí běžící čtečky
     * (pokud čtečka neběží, hlášku by si stejně nikdo nepřečetl).
     * Vrátí false, když předání nešlo, a Flutter side si tak
     * může předčíst hlášku vestavěným hlasem.
     */
    private fun announceForScreenReader(text: String): Boolean {
        if (!screenReaderActive()) return false
        val root = window.decorView ?: return false
        return try {
            root.announceForAccessibility(text)
            true
        } catch (_: Exception) {
            false
        }
    }
}
