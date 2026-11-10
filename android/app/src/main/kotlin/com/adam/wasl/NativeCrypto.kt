package com.adam.wasl

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.security.SecureRandom
import java.util.concurrent.Executors
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * AES-256-GCM بتاع أندرويد نفسه (بيستخدم تعليمات المعالج) — أسرع بكتير من التشفير
 * بالـ Dart على الموبايل، وده بيفرق جداً في الفيديوهات والملفات الكبيرة.
 * نفس الصيغة بالظبط: nonce(12) | ciphertext | tag(16).
 */
object NativeCrypto {
    private val pool = Executors.newFixedThreadPool(2)
    private val main = Handler(Looper.getMainLooper())
    private val random = SecureRandom()

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "wasl/crypto").setMethodCallHandler { call, result ->
            val key = call.argument<ByteArray>("key")
            val data = call.argument<ByteArray>("data")
            val aad = call.argument<ByteArray>("aad")
            if (key == null || data == null || aad == null || key.size != 32) {
                result.error("args", "bad arguments", null)
                return@setMethodCallHandler
            }
            pool.execute {
                try {
                    val out: ByteArray? = when (call.method) {
                        "seal" -> seal(key, data, aad)
                        "open" -> open(key, data, aad)
                        else -> {
                            main.post { result.notImplemented() }
                            return@execute
                        }
                    }
                    main.post { result.success(out) }
                } catch (e: Exception) {
                    main.post { result.error("crypto", e.message, null) }
                }
            }
        }
    }

    private fun seal(key: ByteArray, plain: ByteArray, aad: ByteArray): ByteArray {
        val nonce = ByteArray(12).also { random.nextBytes(it) }
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
        c.updateAAD(aad)
        return nonce + c.doFinal(plain) // ciphertext + tag
    }

    /** null = المفتاح غلط أو البيانات اتعدلت. */
    private fun open(key: ByteArray, box: ByteArray, aad: ByteArray): ByteArray? {
        if (box.size < 12 + 16) return null
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, box, 0, 12))
        c.updateAAD(aad)
        return try {
            c.doFinal(box, 12, box.size - 12)
        } catch (e: AEADBadTagException) {
            null
        }
    }
}
