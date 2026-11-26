package com.anywherelan.awl

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.util.Log
import anywherelan.Anywherelan
import anywherelan.SocketProtector
import java.net.URI
import java.net.URISyntaxException
import java.util.concurrent.Callable
import java.util.concurrent.CompletableFuture
import java.util.concurrent.Executors
import java.util.concurrent.Future

// MyVpnService owns the awl backend and its VPN interface. It runs as a
// foreground service, so awl keeps running while the app is in the background,
// and it is what Android starts on its own: at boot when Always-on VPN is
// enabled for the app. The Flutter UI does not call the backend itself;
// MainActivity forwards its requests to this service (see start, stop,
// reconfigure and importConfig).
//
// Every call into the backend runs on one worker thread, in the order the
// requests arrive: starts by the app and by Android, stop, revoke,
// reconfigure and import. The gomobile functions share global state without
// locking, and a start by Android may overlap a request from the app.
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

        // Marks a start requested by the app. Any other start comes from the
        // system: Always-on VPN (action android.net.VpnService) or a sticky
        // restart (null intent).
        private const val ACTION_START_FROM_APP = "com.anywherelan.awl.START_FROM_APP"

        private const val NOTIFICATION_CHANNEL_ID = "awl_vpn_service"
        private const val NOTIFICATION_ID = 1

        private val worker = Executors.newSingleThreadScheduledExecutor()

        // The state below is written only on the worker.

        // The instance that handled the latest start, null once it stopped.
        @Volatile
        private var instance: MyVpnService? = null

        // The instance that started the running backend, null while stopped.
        @Volatile
        var owner: MyVpnService? = null
            private set

        // The API address of the running backend, "" while it is stopped or
        // still starting. Published only once the backend and its VPN
        // interface are ready, so the app never reads a half-started API.
        @Volatile
        var apiAddress = ""
            private set

        // False after a stop from the app, so that a start by the app that is
        // still on its way to the service is dropped.
        private var wantRunning = false

        // Starts by the app waiting for the service to start the backend.
        private val pendingStarts = mutableListOf<CompletableFuture<String>>()

        // start asks the service to start the backend and completes with its
        // API address, or the error.
        fun start(context: Context): CompletableFuture<String> {
            val result = CompletableFuture<String>()
            worker.execute {
                wantRunning = true
                if (apiAddress != "") {
                    result.complete(apiAddress)
                    return@execute
                }
                pendingStarts.add(result)
                val intent = Intent(context, MyVpnService::class.java).setAction(ACTION_START_FROM_APP)
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        context.startForegroundService(intent)
                    } else {
                        context.startService(intent)
                    }
                } catch (e: Exception) {
                    failPendingStarts(e)
                }
            }
            return result
        }

        // stop stops the backend and the service, also when a start is still
        // on its way. Safe to repeat.
        fun stop(): Future<*> = worker.submit {
            wantRunning = false
            failPendingStarts(Exception("stopped"))
            instance?.stopOnWorker()
        }

        // reconfigure re-applies the VPN routes for the current
        // (already-persisted) config, e.g. after the user toggled gateway
        // client mode.
        fun reconfigure(): Future<*> = worker.submit { owner?.reconfigureOnWorker() }

        // needsVpnInterface tells whether the config has the VPN interface
        // enabled, so that starting the backend needs the VPN permission.
        fun needsVpnInterface(context: Context): Boolean = worker.submit(Callable {
            Anywherelan.setup(context.filesDir.absolutePath)
            !AppConfig.fromJson(Anywherelan.getConfig()).vpn.disableVPNInterface
        }).get()

        // importConfig fails when the backend runs, e.g. when Always-on VPN
        // started it again after the app stopped it for the import.
        fun importConfig(context: Context, config: String?): Future<*> = worker.submit {
            Anywherelan.setup(context.filesDir.absolutePath)
            Anywherelan.importConfig(config)
        }

        private fun completePendingStarts(apiAddress: String) {
            pendingStarts.forEach { it.complete(apiAddress) }
            pendingStarts.clear()
        }

        private fun failPendingStarts(e: Exception) {
            pendingStarts.forEach { it.completeExceptionally(e) }
            pendingStarts.clear()
        }
    }

    // The start id of the latest start this instance handled, to stop the
    // service only when no newer start is on its way.
    private var handledStartId = 0

    override fun onCreate() {
        super.onCreate()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "VPN service",
                NotificationManager.IMPORTANCE_LOW,
            )
            channel.description = "Shown while Anywherelan is running"
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        val fromApp = intent?.action == ACTION_START_FROM_APP
        worker.execute { startOnWorker(fromApp, startId) }
        return START_STICKY
    }

    override fun onRevoke() {
        // Another VPN app took over, or the user disconnected awl in the system
        // VPN settings. The interface is gone, so stop the backend with it.
        worker.execute { if (instance === this) stopOnWorker() }
    }

    override fun onDestroy() {
        worker.execute {
            stopBackendIfOwner()
            if (instance === this) instance = null
        }
        super.onDestroy()
    }

    private fun startOnWorker(fromApp: Boolean, startId: Int) {
        instance = this
        handledStartId = startId
        if (fromApp && !wantRunning) {
            // The app stopped awl before this start arrived.
            removeService()
            return
        }
        // A start by Android counts as wanted: Always-on VPN asked for it.
        wantRunning = true
        try {
            if (apiAddress == "") {
                startBackend()
            } else {
                // Already running, e.g. the app asked after Always-on VPN
                // started it.
                owner = this
            }
            completePendingStarts(apiAddress)
        } catch (e: Exception) {
            Log.e(TAG, "Start awl", e)
            failPendingStarts(e)
            removeService()
        }
    }

    // startBackend starts the backend with a VPN interface built from its
    // config and publishes its API address.
    private fun startBackend() {
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
        owner = this
        routesAllTraffic = tunFd != 0 && config.vpnGateway.clientEnabled
        if (tunFd != 0) {
            rebuildTunIfConfigChanged(config)
        }
        apiAddress = Anywherelan.getApiAddress()
        updateNotification()
    }

    // stopBackendIfOwner stops the backend if this instance started it. An
    // instance stopped for a restart may be destroyed after a new one started
    // the backend again; it must leave that backend alone.
    private fun stopBackendIfOwner() {
        if (owner !== this) return
        apiAddress = ""
        owner = null
        routesAllTraffic = false
        Anywherelan.stopServer()
    }

    // stopOnWorker stops the backend and the service with it, removing the
    // VPN interface and the notification.
    private fun stopOnWorker() {
        stopBackendIfOwner()
        removeService()
    }

    // removeService stops the service unless a newer start is on its way,
    // which then runs on the worker after this.
    private fun removeService() {
        if (instance === this) instance = null
        stopSelfResult(handledStartId)
    }

    private fun reconfigureOnWorker() {
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
    // once the interface is installed in the backend. Without it, awl routes
    // only its own subnet, so with "Block connections without VPN" only awl
    // peers are reachable.
    @Volatile
    var routesAllTraffic = false
        private set

    // updateNotification shows in the notification whether connections
    // without VPN are blocked. Called after the VPN interface changes and when
    // the app returns to the foreground, e.g. from the VPN settings, where the
    // option may have changed.
    fun updateNotification() {
        if (owner !== this) return
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
        routesAllTraffic = config.vpnGateway.clientEnabled
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
