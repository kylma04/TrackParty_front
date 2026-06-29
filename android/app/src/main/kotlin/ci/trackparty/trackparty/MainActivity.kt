package ci.trackparty.trackparty

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private var notifId = 2000

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    // Canal de méthode pour afficher une notif locale quand l'app est au premier
    // plan (FCM ne le fait pas tout seul sur Android). Appelé depuis app.dart.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "show") {
                    showLocalNotification(
                        call.argument<String>("title") ?: "TrackParty",
                        call.argument<String>("body") ?: "",
                    )
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun showLocalNotification(title: String, body: String) {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pending = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notif = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(getColor(R.color.notification_color)) // orange TrackParty #FF6B35
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        try {
            NotificationManagerCompat.from(this).notify(notifId++, notif)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS non accordée : on ignore silencieusement.
        }
    }

    /**
     * Crée le canal de notification "haute importance" AVEC son.
     * Depuis Android 8 (API 26), le son d'une notification est porté par le
     * canal, pas par le message FCM. Sans ce canal, les notifications arrivent
     * en silencieux. L'id doit correspondre au meta-data
     * `default_notification_channel_id` du manifest ET au `channel_id` envoyé
     * par le serveur (apps/utils/firebase.py).
     */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return
        // Ne pas recréer si déjà présent (Android ignore les changements
        // d'importance d'un canal existant de toute façon).
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Notifications TrackParty",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Messages, invitations, événements et alertes"
            enableVibration(true)
            val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val attrs = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()
            setSound(soundUri, attrs)
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        const val CHANNEL_ID = "high_importance_channel"
        const val METHOD_CHANNEL = "trackparty/notifications"
    }
}
