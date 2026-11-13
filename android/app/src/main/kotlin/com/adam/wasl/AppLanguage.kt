package com.adam.wasl

import android.content.Context
import android.content.res.Configuration
import java.util.Locale

/**
 * لغة نصوص الجزء الـ native (الإشعارات والبصمة) — بتمشي على اللغة اللي اختارها
 * المستخدم جوه التطبيق مش لغة الموبايل. Flutter بيبعتها في [set] كل ما تتغير.
 */
object AppLanguage {
    private const val PREFS = "wasl_native"
    private const val KEY = "language"

    @Volatile
    private var code: String? = null

    fun set(context: Context, value: String) {
        code = value
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, value).apply()
    }

    /** Context بنصوص اللغة المختارة (لو لسه محددتش: لغة الموبايل). */
    fun context(context: Context): Context {
        val lang = code ?: context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null).also {
            code = it
        } ?: return context
        val config = Configuration(context.resources.configuration)
        config.setLocale(Locale.forLanguageTag(lang))
        return context.createConfigurationContext(config)
    }

    fun string(context: Context, id: Int): String = context(context).getString(id)
}
