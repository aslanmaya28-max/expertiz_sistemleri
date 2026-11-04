package com.yerimebak.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * "Paylaş → YerimeBak": ilan uygulamasından gelen metin (link) Flutter'a iletilir.
 * Uygulama kapalıyken gelen paylaşım ilk açılışta "ilkPaylasim" ile alınır; açıkken gelen
 * paylaşım "yeniPaylasim" olarak gönderilir. Yalnız düz metin kabul edilir; dosya alınmaz.
 */
class MainActivity : FlutterActivity() {
    private var kanal: MethodChannel? = null
    private var bekleyen: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bekleyen = paylasilanMetin(intent)
        kanal = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "yerimebak/paylasim").also {
            it.setMethodCallHandler { cagri, sonuc ->
                if (cagri.method == "ilkPaylasim") {
                    sonuc.success(bekleyen)
                    bekleyen = null
                } else {
                    sonuc.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val metin = paylasilanMetin(intent) ?: return
        kanal?.invokeMethod("yeniPaylasim", metin) ?: run { bekleyen = metin }
    }

    private fun paylasilanMetin(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_SEND || intent.type?.startsWith("text/") != true) return null
        val metin = intent.getStringExtra(Intent.EXTRA_TEXT)?.take(4000)
        return if (metin.isNullOrBlank()) null else metin
    }
}
