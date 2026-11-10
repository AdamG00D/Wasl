package com.adam.wasl

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.ParcelFileDescriptor
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.webkit.MimeTypeMap
import java.io.File
import java.io.FileNotFoundException

/**
 * بيدّي التطبيقات التانية إذن **قراءة بس** لملف واحد من ملفات الدردشة
 * (عشان تفتح PDF أو مستند بالتطبيق المناسب). مبيقدرش يوصل لأي حاجة برا
 * فولدر الكاش بتاع التطبيق.
 */
class ChatFileProvider : ContentProvider() {

    override fun onCreate(): Boolean = true

    private fun fileFor(uri: Uri): File? {
        val ctx = context ?: return null
        val rel = uri.path?.trimStart('/') ?: return null
        val base = ctx.cacheDir.canonicalFile
        val f = File(base, rel).canonicalFile
        if (!f.path.startsWith(base.path + File.separator)) return null
        return f.takeIf { it.isFile }
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw SecurityException("read only")
        val f = fileFor(uri) ?: throw FileNotFoundException()
        return ParcelFileDescriptor.open(f, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun getType(uri: Uri): String =
        ChatFiles.mimeFor(uri.getQueryParameter("name") ?: uri.lastPathSegment ?: "")

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        val f = fileFor(uri)
        val name = uri.getQueryParameter("name") ?: f?.name ?: "file"
        val cols = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val cursor = MatrixCursor(cols)
        cursor.addRow(cols.map {
            when (it) {
                OpenableColumns.DISPLAY_NAME -> name
                OpenableColumns.SIZE -> f?.length() ?: 0L
                else -> null
            }
        })
        return cursor
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?) = 0
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?) = 0
}

object ChatFiles {

    fun mimeFor(name: String): String {
        val ext = name.substringAfterLast('.', "").lowercase()
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(ext) ?: "application/octet-stream"
    }

    private fun safeName(name: String): String =
        name.replace(Regex("[\\\\/:*?\"<>|\\u0000-\\u001f]"), "_").ifBlank { "Wasl_file" }.take(100)

    /** يفتح الملف بالتطبيق المناسب. false = مفيش تطبيق يفتح النوع ده. */
    fun open(context: Context, path: String, name: String): Boolean {
        var f = File(path).canonicalFile
        val base = context.cacheDir.canonicalFile
        if (!f.path.startsWith(base.path + File.separator)) {
            // ملف برا الكاش (ملف أصلي عندي): ننسخه الأول عشان نقدر نديه للتطبيق التاني
            val dir = File(base, "wasl_open").apply { mkdirs() }
            val copy = File(dir, safeName(name))
            f.copyTo(copy, overwrite = true)
            f = copy.canonicalFile
        }
        val rel = f.path.removePrefix(base.path + File.separator)
        val uri = Uri.Builder()
            .scheme("content")
            .authority("${context.packageName}.chatfiles")
            .path(rel)
            .appendQueryParameter("name", name)
            .build()
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, mimeFor(name))
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        return try {
            context.startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }

    /** نسخة في Download/Wasl. */
    fun saveToDownloads(context: Context, path: String, name: String): Boolean {
        val src = File(path)
        if (!src.isFile) return false
        val clean = safeName(name)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = context.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, clean)
                put(MediaStore.Downloads.MIME_TYPE, mimeFor(clean))
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Wasl")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values) ?: return false
            try {
                resolver.openOutputStream(uri)?.use { out -> src.inputStream().use { it.copyTo(out) } }
                    ?: throw FileNotFoundException()
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
                true
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                false
            }
        } else {
            @Suppress("DEPRECATION")
            val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "Wasl")
            if (!dir.exists() && !dir.mkdirs()) return false
            var target = File(dir, clean)
            var i = 1
            val stem = clean.substringBeforeLast('.')
            val ext = clean.substringAfterLast('.', "")
            while (target.exists()) {
                target = File(dir, if (ext.isEmpty()) "$stem ($i)" else "$stem ($i).$ext")
                i++
            }
            try {
                src.copyTo(target)
                true
            } catch (e: Exception) {
                false
            }
        }
    }
}
