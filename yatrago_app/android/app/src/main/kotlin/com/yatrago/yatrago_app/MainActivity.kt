package com.yatrago.yatrago_app

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import com.yatrago.yatrago_app.BuildConfig 

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Screenshot/screen-recording protection: OTPs, KYC documents and
        // wallet balances must never land in the recents thumbnail, screen
        // captures, or casting streams. Debug builds stay capturable so
        // development screenshots keep working.
        if (!BuildConfig.DEBUG) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }
}
