package com.adam.wasl

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Person
import android.app.RemoteInput
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.drawable.Icon
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

/**
 * إشعارات التطبيق.
 *
 * • رسالة جديدة: شكل تطبيقات الشات (MessagingStyle) — اسم المحادثة وصورتها ونص الرسالة،
 *   الرسايل متجمعة لكل محادثة، ومعاها رد سريع و"تمت القراءة".
 * • لو قفل التطبيق متفعّل Flutter بيطلب [show] بدلها: "رسالة جديدة" من غير اسم ولا محتوى.
 * • على شاشة القفل بتاعة الموبايل بيظهر دايماً النص العام بس (VISIBILITY_PRIVATE).
 */
object Notifications {
    const val ONGOING_ID = 1001
    private const val MESSAGE_ID = 1002
    private const val SUMMARY_ID = 1003
    private const val SERVICE_CHANNEL = "wasl_chat_service"
    private const val MESSAGE_CHANNEL = "wasl_chat_messages"
    private const val GROUP_KEY = "wasl_messages"
    private const val MAX_LINES = 8

    const val EXTRA_CHAT = "wasl_chat"
    const val EXTRA_REPLY = "wasl_reply"
    const val ACTION_REPLY = "com.adam.wasl.NOTIF_REPLY"
    const val ACTION_READ = "com.adam.wasl.NOTIF_READ"

    private class Line(val sender: String?, val text: String, val time: Long)
    private class Convo(var title: String, var group: Boolean, var avatar: Bitmap?) {
        val lines = ArrayList<Line>()
    }

    /** آخر رسايل كل محادثة ليها إشعار ظاهر (في الذاكرة بس). */
    private val threads = HashMap<String, Convo>()

    private fun manager(context: Context) =
        context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    private fun idOf(chat: String) = 2000 + (chat.hashCode() and 0xFFFFF)

    private fun str(context: Context, id: Int) = AppLanguage.string(context, id)

    /** القنوات بتتعمل أول مرة، ولو موجودة اسمها ووصفها بيتحدّثوا (مثلاً لما اللغة تتغير). */
    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val m = manager(context)
        m.createNotificationChannel(
            NotificationChannel(SERVICE_CHANNEL, str(context, R.string.channel_service), NotificationManager.IMPORTANCE_LOW)
                .apply {
                    description = str(context, R.string.channel_service_desc)
                    setShowBadge(false)
                }
        )
        m.createNotificationChannel(
            NotificationChannel(MESSAGE_CHANNEL, str(context, R.string.channel_messages), NotificationManager.IMPORTANCE_HIGH)
                .apply {
                    description = str(context, R.string.channel_messages_desc)
                    lockscreenVisibility = Notification.VISIBILITY_PRIVATE
                }
        )
    }

    private fun immutable() = PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE

    private fun openApp(context: Context, chat: String? = null): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            if (chat != null) {
                putExtra(EXTRA_CHAT, chat)
                // عشان كل محادثة يبقى ليها PendingIntent مختلف
                action = "com.adam.wasl.OPEN_$chat"
            }
        }
        return PendingIntent.getActivity(context, if (chat == null) 0 else idOf(chat), intent, immutable())
    }

    private fun actionIntent(context: Context, action: String, chat: String, mutable: Boolean): PendingIntent {
        val intent = Intent(context, NotificationActionReceiver::class.java)
            .setAction(action)
            .putExtra(EXTRA_CHAT, chat)
        // الرد السريع لازم PendingIntent قابل للتعديل (النظام بيحط فيه النص)
        val flags = if (mutable && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT or (if (mutable) 0 else PendingIntent.FLAG_IMMUTABLE)
        }
        return PendingIntent.getBroadcast(context, idOf(chat) + (if (mutable) 1 else 2), intent, flags)
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
            .setContentText(str(context, if (inCall) R.string.ongoing_call else R.string.ongoing_chat))
            .setContentIntent(openApp(context))
            .setOngoing(true)
            .setShowWhen(false)
            .build()
    }

    @Suppress("DEPRECATION")
    private fun generic(context: Context, text: String): Notification.Builder =
        builder(context, MESSAGE_CHANNEL)
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

    /** إشعار من غير أي اسم أو محتوى (قفل التطبيق متفعّل، أو طلب انضمام / مكالمة). */
    fun show(context: Context, kind: String) {
        ensureChannels(context)
        val text = str(
            context,
            when (kind) {
                "request" -> R.string.new_request
                "call" -> R.string.incoming_call
                else -> R.string.new_message
            },
        )
        try {
            manager(context).notify(MESSAGE_ID, generic(context, text).build())
        } catch (ignored: SecurityException) {
            // إذن الإشعارات مرفوض
        }
    }

    private fun circle(source: Bitmap): Bitmap {
        val size = minOf(source.width, source.height)
        val out = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
        paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.SRC_IN)
        canvas.drawBitmap(source, (size - source.width) / 2f, (size - source.height) / 2f, paint)
        return out
    }

    /** إشعار رسالة في محادثة (بيتجمع مع اللي قبله لنفس المحادثة). */
    @Suppress("DEPRECATION")
    fun showMessage(
        context: Context,
        chat: String,
        title: String,
        sender: String?,
        text: String,
        group: Boolean,
        avatar: ByteArray?,
    ) {
        ensureChannels(context)
        val thread = threads.getOrPut(chat) { Convo(title, group, null) }
        thread.title = title
        thread.group = group
        if (avatar != null) {
            try {
                BitmapFactory.decodeByteArray(avatar, 0, avatar.size)?.let { thread.avatar = circle(it) }
            } catch (ignored: Exception) {
            }
        }
        thread.lines.add(Line(sender, text, System.currentTimeMillis()))
        while (thread.lines.size > MAX_LINES) thread.lines.removeAt(0)

        val icon = thread.avatar
        val b = builder(context, MESSAGE_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_wasl)
            .setContentTitle(title)
            .setContentText(if (sender != null) "$sender: $text" else text)
            .setContentIntent(openApp(context, chat))
            .setAutoCancel(true)
            .setShowWhen(true)
            .setWhen(System.currentTimeMillis())
            .setCategory(Notification.CATEGORY_MESSAGE)
            .setGroup(GROUP_KEY)
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            // على شاشة قفل الموبايل: من غير اسم ولا محتوى
            .setPublicVersion(generic(context, str(context, R.string.new_message)).build())
        if (icon != null) b.setLargeIcon(icon)
        if (thread.lines.size > 1) b.setNumber(thread.lines.size)
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            b.setPriority(Notification.PRIORITY_HIGH)
            b.setDefaults(Notification.DEFAULT_ALL)
        }

        val you = str(context, R.string.you)
        val style = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            Notification.MessagingStyle(Person.Builder().setName(you).build()).also { st ->
                st.isGroupConversation = group
                if (group) st.conversationTitle = title
                for (l in thread.lines) {
                    val person = Person.Builder().setName(l.sender ?: title)
                    // في الخاص صورة الشخص بتظهر جنب كل رسالة
                    if (!group && icon != null) person.setIcon(Icon.createWithBitmap(icon))
                    st.addMessage(l.text, l.time, person.build())
                }
            }
        } else {
            Notification.MessagingStyle(you).also { st ->
                if (group) st.conversationTitle = title
                for (l in thread.lines) st.addMessage(l.text, l.time, l.sender ?: title)
            }
        }
        b.setStyle(style)

        val replyLabel = str(context, R.string.reply)
        val remote = RemoteInput.Builder(EXTRA_REPLY).setLabel(replyLabel).build()
        b.addAction(
            Notification.Action.Builder(
                Icon.createWithResource(context, R.drawable.ic_stat_wasl),
                replyLabel,
                actionIntent(context, ACTION_REPLY, chat, mutable = true),
            ).addRemoteInput(remote).setAllowGeneratedReplies(false).build()
        )
        b.addAction(
            Notification.Action.Builder(
                Icon.createWithResource(context, R.drawable.ic_stat_wasl),
                str(context, R.string.mark_read),
                actionIntent(context, ACTION_READ, chat, mutable = false),
            ).build()
        )

        try {
            val m = manager(context)
            m.notify(idOf(chat), b.build())
            // ملخّص بيلمّ إشعارات المحادثات تحت بعض
            if (threads.size > 1) {
                val summary = builder(context, MESSAGE_CHANNEL)
                    .setSmallIcon(R.drawable.ic_stat_wasl)
                    .setContentTitle("Wasl")
                    .setContentText(AppLanguage.context(context).getString(R.string.summary, threads.size))
                    .setGroup(GROUP_KEY)
                    .setGroupSummary(true)
                    .setAutoCancel(true)
                    .setContentIntent(openApp(context))
                    .setVisibility(Notification.VISIBILITY_PRIVATE)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    summary.setGroupAlertBehavior(Notification.GROUP_ALERT_CHILDREN)
                }
                m.notify(SUMMARY_ID, summary.build())
            }
        } catch (ignored: SecurityException) {
            // إذن الإشعارات مرفوض
        }
    }

    /** المحادثة اتفتحت أو اتقرت: إشعارها بيتشال. */
    fun cancel(context: Context, chat: String) {
        threads.remove(chat)
        val m = manager(context)
        m.cancel(idOf(chat))
        if (threads.size <= 1) m.cancel(SUMMARY_ID)
        if (threads.isEmpty()) m.cancel(MESSAGE_ID)
    }

    fun clear(context: Context) {
        val m = manager(context)
        for (chat in threads.keys) m.cancel(idOf(chat))
        threads.clear()
        m.cancel(SUMMARY_ID)
        m.cancel(MESSAGE_ID)
    }
}

/** أزرار إشعار الرسالة: رد سريع / تمت القراءة — بتتسلّم لـ Flutter لو التطبيق شغال. */
class NotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val chat = intent.getStringExtra(Notifications.EXTRA_CHAT) ?: return
        when (intent.action) {
            Notifications.ACTION_REPLY -> {
                val text = RemoteInput.getResultsFromIntent(intent)
                    ?.getCharSequence(Notifications.EXTRA_REPLY)?.toString()?.trim()
                if (!text.isNullOrEmpty()) {
                    MainActivity.send("notifReply", mapOf("chat" to chat, "text" to text))
                }
            }
            Notifications.ACTION_READ -> MainActivity.send("notifRead", mapOf("chat" to chat))
        }
        Notifications.cancel(context, chat)
    }
}
