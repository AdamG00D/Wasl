package com.adam.wasl

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import java.io.File
import java.io.FileOutputStream

/**
 * تصغير الصور قبل الإرسال (JPEG) مع احترام اتجاه الصورة (EXIF).
 * بنعملها هنا بدل مكتبة اختيار الصور: المكتبة كانت ساعات بتعامل الفيديو
 * كأنه صورة وتبعت أول فريم منه بس.
 */
object ImageCompressor {

    /** يرجّع مسار الصورة المصغرة، أو null لو الملف مش صورة يقدر يفكها. */
    fun compress(path: String, outDir: File, maxSide: Int, quality: Int): String? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

        var sample = 1
        while (bounds.outWidth / (sample * 2) >= maxSide || bounds.outHeight / (sample * 2) >= maxSide) sample *= 2
        val bmp = BitmapFactory.decodeFile(path, BitmapFactory.Options().apply { inSampleSize = sample }) ?: return null

        val scale = minOf(1f, maxSide.toFloat() / maxOf(bmp.width, bmp.height))
        val matrix = Matrix()
        if (scale < 1f) matrix.postScale(scale, scale)
        val rotation = try {
            when (ExifInterface(path).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
        } catch (e: Exception) {
            0f
        }
        if (rotation != 0f) matrix.postRotate(rotation)
        val out = if (scale < 1f || rotation != 0f) {
            Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, matrix, true)
        } else {
            bmp
        }
        outDir.mkdirs()
        val target = File(outDir, "img_${System.nanoTime()}.jpg")
        FileOutputStream(target).use { out.compress(Bitmap.CompressFormat.JPEG, quality, it) }
        if (out !== bmp) out.recycle()
        bmp.recycle()
        return target.path
    }
}
