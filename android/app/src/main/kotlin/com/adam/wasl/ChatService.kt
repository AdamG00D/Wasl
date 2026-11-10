package com.adam.wasl

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.Process

/**
 * خدمة في المقدمة تخلي الدردشة شغالة لما التطبيق يروح الخلفية.
 * أندرويد بيشترط إشعار ثابت طول ما الخدمة شغالة.
 * لو المستخدم قفل التطبيق نهائياً (سحبه من التطبيقات الأخيرة) الخدمة بتقفل معاه.
 */
class ChatService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val mic = intent?.getBooleanExtra(EXTRA_MIC, false) ?: false
        val camera = intent?.getBooleanExtra(EXTRA_CAMERA, false) ?: false
        val notification = Notifications.ongoing(this, inCall = mic)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            var types = ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                // أثناء المكالمة: لازم نعلن عن الميكروفون/الكاميرا عشان تكمل في الخلفية
                if (mic) types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
                if (camera) types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
            }
            try {
                startForeground(Notifications.ONGOING_ID, notification, types)
            } catch (e: Exception) {
                // الإذن مش متاح لسه — نكمل بالنوع الأساسي
                startForeground(
                    Notifications.ONGOING_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE,
                )
            }
        } else {
            startForeground(Notifications.ONGOING_ID, notification)
        }
        return START_NOT_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        // التطبيق اتقفل نهائياً — نقفل الدردشة معاه.
        // بنقفل العملية كلها بعد لحظة (عشان رسالة الوداع تلحق تخرج): كده الاتصال
        // بيتقطع فوراً والطرف التاني يعرف على طول إن إحنا فصلنا، بدل ما يفضل مستني.
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
        super.onTaskRemoved(rootIntent)
        Handler(Looper.getMainLooper()).postDelayed({ Process.killProcess(Process.myPid()) }, 800)
    }

    companion object {
        private const val EXTRA_MIC = "mic"
        private const val EXTRA_CAMERA = "camera"

        fun start(context: Context, mic: Boolean = false, camera: Boolean = false) {
            val intent = Intent(context, ChatService::class.java)
                .putExtra(EXTRA_MIC, mic)
                .putExtra(EXTRA_CAMERA, camera)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, ChatService::class.java))
        }
    }
}

/** إشعارات التطبيق — من غير أي اسم أو محتوى للخصوصية. */
object Notifications {
    const val ONGOING_ID = 1001
    private const val MESSAGE_ID = 1002
    private const val SERVICE_CHANNEL = "wasl_chat_service"
    private const val MESSAGE_CHANNEL = "wasl_chat_messages"

    private fun manager(context: Context) =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val m = manager(context)
        if (m.getNotificationChannel(SERVICE_CHANNEL) == null) {
            m.createNotificationChannel(
                NotificationChannel(SERVICE_CHANNEL, "الدردشة الشغالة", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "بيفضل ظاهر طول ما الدردشة شغالة في الخلفية"
                    setShowBadge(false)
                }
            )
        }
        if (m.getNotificationChannel(MESSAGE_CHANNEL) == null) {
            m.createNotificationChannel(
                NotificationChannel(MESSAGE_CHANNEL, "رسايل جديدة", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "تنبيه برسالة جديدة من غير أي تفاصيل"
                    lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                }
            )
        }
    }

    private fun openApp(context: Context): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    @Suppress("DEPRECATION")
    private fun builder(context: Context, channel: String): Notification.Builder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, channel)
        } else {
            Notification.Builder(context)
        }

    fun ongoing(context: Context, inCall: Boolean = false): Notification {
        ensureChannels(context)
        return builder(context, SERVICE_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_wasl)
            .setContentTitle("Wasl")
            .setContentText(if (inCall) "مكالمة شغالة" else "الدردشة شغالة")
            .setContentIntent(openApp(context))
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }

    @Suppress("DEPRECATION")
    fun show(context: Context, kind: String) {
        ensureChannels(context)
        val text = when (kind) {
            "request" -> "طلب محادثة جديد"
            "call" -> "مكالمة واردة"
            else -> "رسالة جديدة"
        }
        val n = builder(context, MESSAGE_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_wasl)
            .setContentTitle("Wasl")
            .setContentText(text)
            .setContentIntent(openApp(context))
            .setAutoCancel(true)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .apply {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                    setPriority(Notification.PRIORITY_HIGH)
                    setDefaults(Notification.DEFAULT_ALL)
                }
            }
            .build()
        try {
            manager(context).notify(MESSAGE_ID, n)
        } catch (ignored: SecurityException) {
            // إذن الإشعارات مرفوض
        }
    }

    fun clear(context: Context) {
        manager(context).cancel(MESSAGE_ID)
    }
}
