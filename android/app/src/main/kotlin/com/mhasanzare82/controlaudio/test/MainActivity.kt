package com.mhasanzare82.controlaudio.test

import android.media.AudioManager
import android.media.AudioPlaybackConfiguration
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val playbackEventChannel = "control_audio/playback_events"
    private val volumeMethodChannel = "control_audio/volume"
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

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            volumeMethodChannel
        ).setMethodCallHandler { call, result ->
            val manager = getSystemService(AUDIO_SERVICE) as AudioManager
            when (call.method) {
                "getVolume" -> {
                    val maximum = manager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                    val current = manager.getStreamVolume(AudioManager.STREAM_MUSIC)
                    result.success(mapOf("current" to current, "maximum" to maximum))
                }
                "setVolume" -> {
                    val percent = call.argument<Number>("percent")?.toInt()
                    if (percent == null || percent !in 0..100) {
                        result.error("INVALID_VOLUME", "Volume must be between 0 and 100", null)
                    } else {
                        val maximum = manager.getStreamMaxVolume(AudioManager.STREAM_MUSIC)
                        val target = (maximum * percent / 100.0).toInt()
                        manager.setStreamVolume(AudioManager.STREAM_MUSIC, target, 0)
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
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
