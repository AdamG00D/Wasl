package com.adam.wasl

import android.app.Activity
import android.content.pm.PackageManager
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * مفتاح AES جوه Android Keystore بيشفّر "مفتاح التخزين" بتاع التطبيق
 * (المحادثات المحفوظة ومفتاح الهوية). المفتاح نفسه مبيطلعش برا الجهاز.
 */
object KeyVault {
    private const val ALIAS = "wasl_storage_key"

    private fun key(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        val gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        gen.init(
            KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build()
        )
        return gen.generateKey()
    }

    fun wrap(plain: ByteArray): ByteArray {
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.ENCRYPT_MODE, key())
        return c.iv + c.doFinal(plain)
    }

    fun unwrap(box: ByteArray): ByteArray {
        val c = Cipher.getInstance("AES/GCM/NoPadding")
        c.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, box, 0, 12))
        return c.doFinal(box, 12, box.size - 12)
    }
}

/** فتح قفل التطبيق بالبصمة (اختياري) — نافذة النظام نفسها. */
object BiometricGate {
    fun available(activity: Activity): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return false
        val pm = activity.packageManager
        val has = pm.hasSystemFeature(PackageManager.FEATURE_FINGERPRINT) ||
            (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                (pm.hasSystemFeature(PackageManager.FEATURE_FACE) || pm.hasSystemFeature(PackageManager.FEATURE_IRIS)))
        if (!has) return false
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val bm = activity.getSystemService(android.hardware.biometrics.BiometricManager::class.java)
            @Suppress("DEPRECATION")
            return bm?.canAuthenticate() == android.hardware.biometrics.BiometricManager.BIOMETRIC_SUCCESS
        }
        return true
    }

    fun authenticate(activity: Activity, title: String, subtitle: String, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            result.success(false)
            return
        }
        var answered = false
        fun answer(ok: Boolean) {
            if (answered) return
            answered = true
            result.success(ok)
        }
        val prompt = BiometricPrompt.Builder(activity)
            .setTitle(title)
            .apply { if (subtitle.isNotEmpty()) setSubtitle(subtitle) }
            .setNegativeButton("إلغاء", activity.mainExecutor) { _, _ -> answer(false) }
            .build()
        prompt.authenticate(
            CancellationSignal(),
            activity.mainExecutor,
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(r: BiometricPrompt.AuthenticationResult?) = answer(true)
                override fun onAuthenticationError(code: Int, msg: CharSequence?) = answer(false)
            },
        )
    }
}
