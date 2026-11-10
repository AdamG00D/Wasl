package com.adam.wasl

import android.content.Context
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import androidx.annotation.OptIn
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * ضغط الفيديو قبل الإرسال (زي الواتساب): H.264، أطول ضلع 1280، بت ريت معقول.
 *
 * ليه؟ فيديو 1080×2340 (تسجيل شاشة موبايل مثلاً) بيشتغل على الموبايل اللي صوّره،
 * بس أجهزة كتير (زي Galaxy Tab A7) مفيهاش decoder يقدر عليه، فمش بيشتغل عندها خالص.
 * بعد الضغط بيشتغل في أي حتة وبيتبعت أسرع كمان.
 */
@OptIn(UnstableApi::class)
object VideoCompressor {
    private const val MAX_SIDE = 1280
    private const val BITRATE = 2_500_000

    private var transformer: Transformer? = null
    private var pending: MethodChannel.Result? = null

    /** يرد على الطلب الحالي مرة واحدة بس. */
    private fun finish(value: String?) {
        val r = pending
        pending = null
        transformer = null
        r?.success(value)
    }

    fun register(context: Context, messenger: BinaryMessenger) {
        MethodChannel(messenger, "wasl/video").setMethodCallHandler { call, result ->
            when (call.method) {
                "needsCompression" -> {
                    val path = call.argument<String>("path") ?: ""
                    Thread {
                        val needs = try { needsCompression(path) } catch (e: Exception) { true }
                        android.os.Handler(android.os.Looper.getMainLooper()).post { result.success(needs) }
                    }.start()
                }
                "compress" -> compress(
                    context,
                    call.argument<String>("path") ?: "",
                    result,
                )
                "progress" -> {
                    val t = transformer
                    if (t == null) {
                        result.success(-1)
                    } else {
                        val holder = ProgressHolder()
                        val state = t.getProgress(holder)
                        result.success(if (state == Transformer.PROGRESS_STATE_AVAILABLE) holder.progress else -1)
                    }
                }
                "cancel" -> {
                    transformer?.cancel()
                    finish(null)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** الفيديو كبير أو مش H.264 أو بت ريت عالي ⇒ محتاج ضغط. */
    private fun needsCompression(path: String): Boolean {
        val (w, h) = displaySize(path) ?: return true
        if (maxOf(w, h) > MAX_SIDE) return true
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(path)
            for (i in 0 until extractor.trackCount) {
                val f = extractor.getTrackFormat(i)
                val mime = f.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("video/") && mime != MimeTypes.VIDEO_H264) return true
            }
        } finally {
            extractor.release()
        }
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(path)
            val bitrate = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_BITRATE)?.toIntOrNull() ?: 0
            return bitrate > 4_000_000
        } finally {
            r.release()
        }
    }

    /** المقاس زي ما بيتعرض (بعد الدوران). */
    private fun displaySize(path: String): Pair<Int, Int>? {
        val r = MediaMetadataRetriever()
        try {
            r.setDataSource(path)
            val w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: return null
            val h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: return null
            val rot = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
            return if (rot == 90 || rot == 270) Pair(h, w) else Pair(w, h)
        } finally {
            r.release()
        }
    }

    private fun compress(context: Context, path: String, result: MethodChannel.Result) {
        transformer?.cancel()
        finish(null)
        pending = result
        val size = try { displaySize(path) } catch (e: Exception) { null }
        val out = File(File(context.cacheDir, "wasl_out").apply { mkdirs() }, "video_${System.nanoTime()}.mp4")

        val effects = if (size != null && maxOf(size.first, size.second) > MAX_SIDE) {
            val scale = MAX_SIDE.toFloat() / maxOf(size.first, size.second)
            val targetH = ((size.second * scale).toInt() / 2) * 2
            Effects(listOf(), listOf(Presentation.createForHeight(targetH)))
        } else {
            Effects.EMPTY
        }

        val t = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(
                DefaultEncoderFactory.Builder(context)
                    .setRequestedVideoEncoderSettings(
                        VideoEncoderSettings.Builder().setBitrate(BITRATE).build()
                    )
                    .build()
            )
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, exportResult: ExportResult) {
                    if (pending === result) finish(out.path) else out.delete()
                }

                override fun onError(
                    composition: Composition,
                    exportResult: ExportResult,
                    exportException: ExportException,
                ) {
                    out.delete()
                    if (pending === result) finish(null)
                }
            })
            .build()
        transformer = t
        try {
            val item = EditedMediaItem.Builder(MediaItem.fromUri(Uri.fromFile(File(path))))
                .setEffects(effects)
                .build()
            t.start(item, out.path)
        } catch (e: Exception) {
            finish(null)
        }
    }
}
