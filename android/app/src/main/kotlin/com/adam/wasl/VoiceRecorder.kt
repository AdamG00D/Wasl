package com.adam.wasl

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** تسجيل الرسايل الصوتية (AAC في ملف m4a) بأداة أندرويد نفسها. */
object VoiceRecorder {
    private var recorder: MediaRecorder? = null
    private var path: String? = null
    private var startedAt = 0L

    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "wasl/voice").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> result.success(start(context, call.argument<String>("path") ?: ""))
                "stop" -> result.success(stop())
                "cancel" -> {
                    val p = path
                    release()
                    p?.let { File(it).delete() }
                    result.success(null)
                }
                "amplitude" -> result.success(
                    try {
                        (recorder?.maxAmplitude ?: 0) / 32767.0
                    } catch (e: Exception) {
                        0.0
                    }
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun start(context: Context, target: String): Boolean {
        release()
        if (target.isEmpty()) return false
        return try {
            @Suppress("DEPRECATION")
            val r = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) MediaRecorder(context) else MediaRecorder()
            r.setAudioSource(MediaRecorder.AudioSource.MIC)
            r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            r.setAudioChannels(1)
            r.setAudioSamplingRate(44100)
            r.setAudioEncodingBitRate(64000)
            r.setOutputFile(target)
            r.prepare()
            r.start()
            recorder = r
            path = target
            startedAt = SystemClock.elapsedRealtime()
            true
        } catch (e: Exception) {
            release()
            File(target).delete()
            false
        }
    }

    /** مدة التسجيل بالمللي ثانية، أو -1 لو فشل (قصير جداً مثلاً). */
    private fun stop(): Long {
        val r = recorder ?: return -1
        val duration = SystemClock.elapsedRealtime() - startedAt
        return try {
            r.stop()
            duration
        } catch (e: RuntimeException) {
            path?.let { File(it).delete() }
            -1
        } finally {
            r.release()
            recorder = null
        }
    }

    private fun release() {
        try {
            recorder?.release()
        } catch (e: Exception) {
        }
        recorder = null
    }
}
