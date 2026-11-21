package com.anywherelan.awl

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.SystemClock
import android.util.Log
import anywherelan.Anywherelan
import anywherelan.SocketProtector
import java.net.URI
import java.net.URISyntaxException

// MyVpnService owns the awl backend and its VPN interface. It runs as a
// foreground service, so awl keeps running while the app is in the background,
// and it is what Android starts on its own: at boot when Always-on VPN is
// enabled for the app. The Flutter UI does not start awl itself; MainActivity
// asks this service to (see start).
//
// START_STICKY brings awl back after its process died only while it runs
// without a VPN interface. With one, Android unbinds from the service as soon
// as the interface goes away with the dead process, before it handles the
// death, and then schedules no restart; awl stays down until the app is opened
// or the device reboots. Neither Always-on VPN nor a network change restarts
// it (seen on Android 16).
class MyVpnService : VpnService() {
    companion object {
        private const val TAG = "MyVpnService"

        // Marks a start requested by the app. The app then calls startAwl itself
        // to get the API address (or the error) back; any other start comes from
        // the system and starts awl from onStartCommand.
        private const val ACTION_START_FROM_APP = "com.anywherelan.awl.START_FROM_APP"

        private const val NOTIFICATION_CHANNEL_ID = "awl_vpn_service"
        private const val NOTIFICATION_ID = 1

        private val instanceLock = Object()

        // The instance that handled the latest start. Null once it stopped. A
        // stopped instance may linger until onDestroy, so a restart must not
        // pick it up: it is cleared in stop, not in onDestroy.
        @Volatile
        var instance: MyVpnService? = null
            private set

        // start starts the service in the foreground and returns its instance,
        // ready for startAwl. Blocks until the service handled the start, so it
        // must not be called on the main thread (onStartCommand runs there).
        fun start(context: Context): MyVpnService {
            val intent = Intent(context, MyVpnService::class.java).setAction(ACTION_START_FROM_APP)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
            return awaitInstance(5000) ?: throw Exception("VPN service did not start")
        }

        private fun publishInstance(service: MyVpnService?) {
            synchronized(instanceLock) {
                instance = service
                instanceLock.notifyAll()
            }
        }

        private fun awaitInstance(timeoutMs: Long): MyVpnService? {
            val deadline = SystemClock.elapsedRealtime() + timeoutMs
            synchronized(instanceLock) {
                while (true) {
                    instance?.let { return it }
                    val left = deadline - SystemClock.elapsedRealtime()
                    if (left <= 0) return null
                    instanceLock.wait(left)
                }
            }
        }
    }

    // Whether this instance started the running backend. An instance stopped
    // for a restart is destroyed after the new one already started awl again;
    // its onDestroy must leave that backend alone.
    private var ownsAwl = false

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        publishInstance(this)

        if (intent?.action != ACTION_START_FROM_APP) {
            // Started by the system: Always-on VPN (action
            // android.net.VpnService) or a sticky restart (null intent). Nobody
            // waits for the result, so a failure stops the service.
            Thread {
                try {
                    startAwl()
                } catch (e: Exception) {
                    Log.e(TAG, "Start awl on system request", e)
                    stop()
                }
            }.start()
        }
        return START_STICKY
    }

    override fun onRevoke() {
        // Another VPN app took over, or the user disconnected awl in the system
        // VPN settings. The interface is gone, so stop the backend with it. Off
        // the main thread: stop waits for a start that may still be running.
        Thread { stop() }.start()
    }

    override fun onDestroy() {
        if (ownsAwl) {
            stopAwl()
        }
        super.onDestroy()
    }

    // startAwl starts the backend with a VPN interface built from its config
    // and returns its API address. Does nothing but return the address when
    // awl already runs, e.g. when the app opens after Always-on VPN started it.
    @Synchronized
    fun startAwl(): String {
        val startedApiAddress = Anywherelan.getApiAddress()
        if (startedApiAddress != "") {
            ownsAwl = true
            return startedApiAddress
        }

        Anywherelan.setup(filesDir.absolutePath)
        val config = AppConfig.fromJson(Anywherelan.getConfig())
        var tunFd = 0

        if (!config.vpn.disableVPNInterface) {
            // The app asks for the VPN permission before starting the service;
            // a system start cannot ask, so it fails here instead.
            if (prepare(this) != null) {
                throw Exception("vpn not authorized")
            }
            tunFd = establishTun(config)
        }

        // Always register the protector when a VPN interface is active,
        // regardless of the current gateway state. The Go side marks every
        // libp2p socket at dial time; if the user later toggles gateway client
        // mode on at runtime, the connections opened before the toggle must
        // already be protected, otherwise they would loop back through the
        // 0.0.0.0/0 route. When gateway is off, protect() is a no-op (libp2p
        // traffic does not traverse the TUN anyway).
        val protector: SocketProtector? = if (tunFd != 0) VpnSocketProtector(this) else null
        Anywherelan.startServer(tunFd, protector)
        ownsAwl = true
        if (tunFd != 0) {
            rebuildTunIfConfigChanged(config)
            updateNotification()
        }
        return Anywherelan.getApiAddress()
    }

    @Synchronized
    private fun stopAwl() {
        Anywherelan.stopServer()
        ownsAwl = false
    }

    // stop stops the backend and the service with it, removing the VPN
    // interface and the notification.
    fun stop() {
        stopAwl()
        synchronized(instanceLock) {
            if (instance === this) publishInstance(null)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(Service.STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
        stopSelf()
    }

    // reconfigure re-applies the VPN routes for the current (already-persisted)
    // config, e.g. after the user toggled gateway client mode.
    @Synchronized
    fun reconfigure() {
        if (Anywherelan.getApiAddress() == "") {
            return
        }
        val config = AppConfig.fromJson(Anywherelan.getConfig())
        if (config.vpn.disableVPNInterface) {
            // No active VPN interface to reconfigure.
            return
        }
        replaceTun(config)
        updateNotification()
    }

    // Always-on VPN and its "Block connections without VPN" option as set for
    // this app in the system VPN settings. Android only tells a running VPN
    // service, and only since Android 10.
    fun isAlwaysOnEnabled(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && isAlwaysOn

    fun isLockdownModeEnabled(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && isLockdownEnabled

    // Whether the VPN interface routes all traffic (gateway client mode), set
    // by establishTun. Without it, awl routes only its own subnet, so with
    // "Block connections without VPN" only awl peers are reachable.
    @Volatile
    var routesAllTraffic = false
        private set

    // updateNotification shows in the notification whether connections
    // without VPN are blocked. Called after the VPN interface changes and when
    // the app reads the status, e.g. on return from the VPN settings, where
    // the option may have changed.
    fun updateNotification() {
        if (instance !== this) return
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, buildNotification())
    }

    // establishTun (re)creates the VpnService TUN interface from config and
    // returns its file descriptor. Routes depend on gateway client mode: when
    // on, route everything (0.0.0.0/0 + ::/0); when off, addAddress already
    // routes the awl subnet on-link, so no explicit route is added. The fd is
    // detached and handed to the Go side, which owns and closes it. Used at
    // startup and by replaceTun, where a fresh establish() is a seamless
    // handover that swaps only the tun fd.
    private fun establishTun(config: AppConfig): Int {
        val ipNetParts = config.vpn.ipNet.split("/")
        if (ipNetParts.size != 2) {
            throw Exception("Invalid ipNet format: ${config.vpn.ipNet}")
        }
        val networkAddress = ipNetParts[0]
        val networkAddressMask = ipNetParts[1].toInt()

        val builder = Builder()
        builder.setSession(config.vpn.interfaceName)
        builder.addAddress(networkAddress, networkAddressMask)
        builder.setMtu(config.vpn.mtu)
        // "Configure" in the system VPN settings opens the app.
        builder.setConfigureIntent(openAppIntent())

        if (config.vpnGateway.clientEnabled) {
            builder.addRoute("0.0.0.0", 0)
            builder.addRoute("::", 0)
        }
        routesAllTraffic = config.vpnGateway.clientEnabled

        // The Go core owns an in-tunnel DNS IP (netstack interceptor in the
        // TUN read path): .awl names are answered locally, everything else is
        // forwarded to the configured upstream — in gateway client mode
        // through the tunnel, so DNS does not leak. The IP is inside the awl
        // subnet that addAddress already routes on-link, so no extra addRoute
        // is needed. An empty string means DNS is off or the Go side could
        // not set the interceptor up (e.g. no free IP in the subnet).
        val dnsServerIP = if (!config.dns.disableDNS) Anywherelan.dnsServerIP() else ""
        if (dnsServerIP.isNotEmpty()) {
            builder.addDnsServer(dnsServerIP)
            // TODO: builder.addSearchDomain("awl") — would resolve bare
            //  short names (e.g. "mypeer") without the .awl suffix.
        } else if (config.vpnGateway.clientEnabled) {
            // No interceptor (DNS disabled — the kill switch — or the Go side
            // failed to set it up) while full-tunnel mode is on: pin DNS to
            // the configured upstream so queries go through the TUN (and the
            // exit node) instead of leaking to the device's own resolver.
            val dnsHost = hostFromAddress(config.dns.upstreamDNSAddress)
            if (dnsHost.isNotEmpty()) {
                builder.addDnsServer(dnsHost)
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            builder.setBlocking(true)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            builder.setMetered(false)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            setUnderlyingNetworks(null)
        }

        var tunFd = 0
        builder.establish().use { tun ->
            if (tun == null) throw Exception("TUN_CREATION_ERROR")
            tunFd = tun.detachFd()
        }
        return tunFd
    }

    // replaceTun builds a TUN from config and hot-swaps its fd into the running
    // backend. P2P stays up: its sockets are already protected and the swap
    // replaces only the fd.
    private fun replaceTun(config: AppConfig) {
        val newFd = establishTun(config)
        Anywherelan.updateTunDevice(newFd)
    }

    // The Go side may change the config while starting: on the first start it
    // derives this device's address, and it turns gateway client mode off when
    // the gateway peer is unusable. The TUN was built before that, so it is
    // rebuilt from the running config. A failure is only logged: the server is
    // already up and keeps the old interface.
    private fun rebuildTunIfConfigChanged(startConfig: AppConfig) {
        try {
            val config = AppConfig.fromJson(Anywherelan.getConfig())
            if (config != startConfig) {
                replaceTun(config)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Rebuild VPN interface after server start", e)
        }
    }

    // hostFromAddress extracts the bare IP from a "host:port" upstream DNS
    // address (config stores host:port for the Go resolver; VpnService.addDnsServer
    // wants a bare IP). Parsing is delegated to java.net.URI: the "//" prefix
    // makes the string a network authority, so getHost() splits off the port.
    // URI returns IPv6 hosts bracketed per RFC 2732, so strip the brackets.
    // Returns "" for blank input and falls back to the trimmed input if it is
    // not a parseable authority.
    private fun hostFromAddress(addr: String): String {
        val trimmed = addr.trim()
        if (trimmed.isEmpty()) return ""
        return try {
            URI("//$trimmed").host?.removeSurrounding("[", "]") ?: trimmed
        } catch (e: URISyntaxException) {
            trimmed
        }
    }

    private fun openAppIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_IMMUTABLE)
    }

    private fun buildNotification(): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "VPN service",
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.description = "Shown while Anywherelan is running"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
            Notification.Builder(this, NOTIFICATION_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        builder
            .setSmallIcon(R.drawable.app_icon)
            .setContentTitle("Anywherelan is running")
            .setContentIntent(openAppIntent())
            .setOngoing(true)
        if (isLockdownModeEnabled()) {
            builder.setContentText("Connections without VPN are blocked")
        }
        return builder.build()
    }
}

// VpnSocketProtector adapts the VpnService.protect(fd) method to the
// gomobile-generated anywherelan.SocketProtector interface. Defined as a
// wrapper rather than implemented directly on MyVpnService so that the Go
// method name (protectSocket) does not collide with VpnService.protect when
// the gomobile binding lower-cases it for Java.
//
// Note: SocketProtector is a top-level interface in the gomobile-generated
// `anywherelan` Java package, NOT a nested class of `Anywherelan`. The
// `Anywherelan` class only holds package-level functions (Setup, GetConfig,
// StartServerWithProtector, …); Go interfaces become sibling top-level
// interfaces in the same Java package.
class VpnSocketProtector(private val vpnService: VpnService) : SocketProtector {
    // gomobile maps Go int32 to Java int, so the parameter type here is Int,
    // not Long. (Go int would map to Long; we deliberately used int32 in
    // SocketProtector.ProtectSocket to keep the parameter the same width as
    // VpnService.protect(int) for a clean delegation.)
    override fun protectSocket(fd: Int): Boolean {
        return vpnService.protect(fd)
    }
}
