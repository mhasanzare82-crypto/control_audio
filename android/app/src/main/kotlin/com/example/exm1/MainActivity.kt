package com.example.exm1

import android.media.AudioManager
import android.media.AudioPlaybackConfiguration
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

class MainActivity : FlutterActivity() {
    private val playbackEventChannel = "control_audio/playback_events"
    private val mainHandler = Handler(Looper.getMainLooper())

    private var audioManager: AudioManager? = null
    private var playbackCallback: AudioManager.AudioPlaybackCallback? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            playbackEventChannel
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(
                arguments: Any?,
                events: EventChannel.EventSink
            ) {
                eventSink = events
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startPlaybackMonitoring()
                } else {
                    events.success(0)
                }
            }

            override fun onCancel(arguments: Any?) {
                stopPlaybackMonitoring()
                eventSink = null
            }
        })
    }

    private fun startPlaybackMonitoring() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(AUDIO_SERVICE) as AudioManager
        audioManager = manager

        val callback = object : AudioManager.AudioPlaybackCallback() {
            override fun onPlaybackConfigChanged(
                configs: MutableList<AudioPlaybackConfiguration>
            ) {
                eventSink?.success(configs.size)
            }
        }

        playbackCallback = callback
        manager.registerAudioPlaybackCallback(callback, mainHandler)

        // Public Android APIs expose only anonymized active playback configurations
        // to ordinary applications. This count does not identify other packages.
        eventSink?.success(manager.activePlaybackConfigurations.size)
    }

    private fun stopPlaybackMonitoring() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val callback = playbackCallback
            val manager = audioManager
            if (callback != null && manager != null) {
                manager.unregisterAudioPlaybackCallback(callback)
            }
        }
        playbackCallback = null
        audioManager = null
    }

    override fun onDestroy() {
        stopPlaybackMonitoring()
        super.onDestroy()
    }
}
