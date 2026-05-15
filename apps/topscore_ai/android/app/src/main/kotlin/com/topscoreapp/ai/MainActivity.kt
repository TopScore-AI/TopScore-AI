package com.topscoreapp.ai

import android.os.Bundle
import androidx.activity.enableEdgeToEdge
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Aligns with Android 15's default edge-to-edge behavior.
        // For Android 14 and below, this explicitly enables it.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
    }
}
