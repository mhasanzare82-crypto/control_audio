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
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, playbackEventChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    eventSink = events
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startPlaybackMonitoring()
                    else events.success(mapOf("count" to 0, "players" to emptyList<Map<String, Any>>()))
                }
                override fun onCancel(arguments: Any?) {
                    stopPlaybackMonitoring()
                    eventSink = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, volumeMethodChannel)
            .setMethodCallHandler { call, result ->
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
                            manager.setStreamVolume(AudioManager.STREAM_MUSIC, (maximum * percent / 100.0).toInt(), 0)
                            result.success(null)
                        }
                    }
                    "getPlaybackDetails" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            result.success(buildPlaybackSnapshot(manager.activePlaybackConfigurations))
                        } else result.success(mapOf("count" to 0, "players" to emptyList<Map<String, Any>>()))
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
            override fun onPlaybackConfigChanged(configs: MutableList<AudioPlaybackConfiguration>) {
                eventSink?.success(buildPlaybackSnapshot(configs))
            }
        }
        playbackCallback = callback
        manager.registerAudioPlaybackCallback(callback, mainHandler)
        eventSink?.success(buildPlaybackSnapshot(manager.activePlaybackConfigurations))
    }

    private fun buildPlaybackSnapshot(configs: List<AudioPlaybackConfiguration>): Map<String, Any> {
        val players = configs.mapIndexed { index, config ->
            val (uid, uidStatus) = readClientUid(config)
            val packages = if (uid != null && uid >= 0) packageManager.getPackagesForUid(uid)?.toList() ?: emptyList() else emptyList()
            val appLabel = packages.firstOrNull()?.let { packageName ->
                try {
                    packageManager.getApplicationLabel(packageManager.getApplicationInfo(packageName, 0)).toString()
                } catch (_: Exception) { packageName }
            }
            mapOf(
                "index" to index + 1,
                "playerState" to readPlayerState(config),
                "uid" to (uid ?: -1),
                "uidStatus" to uidStatus,
                "packageNames" to packages,
                "appLabel" to (appLabel ?: ""),
                "usage" to config.audioAttributes.usage,
                "contentType" to config.audioAttributes.contentType
            )
        }
        return mapOf("count" to players.size, "players" to players)
    }

    // Diagnostic probe only: this accessor is not exposed by every Android SDK surface.
    // Reflection keeps compilation independent of whether the SDK exposes getPlayerState().
    private fun readPlayerState(config: AudioPlaybackConfiguration): Int {
        return try {
            val method = AudioPlaybackConfiguration::class.java.getMethod("getPlayerState")
            (method.invoke(config) as? Number)?.toInt() ?: -1
        } catch (_: Throwable) {
            -1
        }
    }

    // Diagnostic probe only: Android may hide or anonymize this system API.
    private fun readClientUid(config: AudioPlaybackConfiguration): Pair<Int?, String> {
        return try {
            val method = AudioPlaybackConfiguration::class.java.getMethod("getClientUid")
            val uid = method.invoke(config) as? Int
            if (uid != null && uid >= 0) Pair(uid, "available") else Pair(uid, "anonymized_or_unavailable")
        } catch (_: NoSuchMethodException) {
            Pair(null, "method_hidden")
        } catch (_: SecurityException) {
            Pair(null, "blocked_by_android")
        } catch (_: Throwable) {
            Pair(null, "invocation_blocked")
        }
    }

    private fun stopPlaybackMonitoring() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val callback = playbackCallback
            val manager = audioManager
            if (callback != null && manager != null) manager.unregisterAudioPlaybackCallback(callback)
        }
        playbackCallback = null
        audioManager = null
    }

    override fun onDestroy() {
        stopPlaybackMonitoring()
        super.onDestroy()
    }
}
