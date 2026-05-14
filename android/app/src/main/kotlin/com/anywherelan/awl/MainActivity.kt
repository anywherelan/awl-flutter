package com.anywherelan.awl

import android.content.Intent
import android.net.VpnService
import android.os.Build
import androidx.annotation.NonNull
import anywherelan.Anywherelan
import anywherelan.SocketProtector
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger.TaskQueue
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.net.URI
import java.net.URISyntaxException


class MainActivity : FlutterActivity() {
    private val CHANNEL = "anywherelan"

    // The active VpnService instance, retained so the TUN can be re-established
    // at runtime (see establishTun / the "reconfigure_vpn" method). Null when no
    // VPN interface is active.
    private var vpnService: MyVpnService? = null

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Get the binary messenger
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // 2. Create a background task queue from the messenger
        val taskQueue: TaskQueue = messenger.makeBackgroundTaskQueue()

        // 3. Provide the taskQueue when creating the MethodChannel
        val channel = MethodChannel(messenger, CHANNEL, StandardMethodCodec.INSTANCE, taskQueue)

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start_server" -> {
                    val startedApiAddress = Anywherelan.getApiAddress()
                    if (startedApiAddress != "") {
                        result.success(startedApiAddress)
                        return@setMethodCallHandler
                    }

                    Anywherelan.setup(this.filesDir.absolutePath)
                    val config = AppConfig.fromJson(Anywherelan.getConfig())
                    var tunFd = 0

                    if (!config.vpn.disableVPNInterface) {
                        val service = MyVpnService()
                        vpnService = service
                        val requestPermissionIntent = VpnService.prepare(this.context)
                        if (requestPermissionIntent != null) {
                            result.error("error", "vpn not authorized", null)
                            this.startActivityForResult(requestPermissionIntent, 4444)
                            return@setMethodCallHandler
                        }
                        context.startService(Intent(context, MyVpnService::class.java))

                        tunFd = establishTun(service, config)
                    }

                    try {
                        // Always register the protector when a VPN interface is
                        // active, regardless of the current gateway state. The Go
                        // side marks every libp2p socket at dial time; if the user
                        // later toggles gateway client mode on at runtime, the
                        // connections opened before the toggle must already be
                        // protected, otherwise they would loop back through the
                        // 0.0.0.0/0 route. When gateway is off, protect() is a
                        // no-op (libp2p traffic does not traverse the TUN anyway).
                        val service = vpnService
                        val protector: SocketProtector? =
                            if (service != null) VpnSocketProtector(service) else null
                        Anywherelan.startServer(tunFd, protector)
                        val apiAddress = Anywherelan.getApiAddress()
                        result.success(apiAddress)
                    } catch (e: Exception) {
                        result.error("error", e.message, null)
                    }
                }
                "reconfigure_vpn" -> {
                    try {
                        val service = vpnService
                        val config = AppConfig.fromJson(Anywherelan.getConfig())
                        if (config.vpn.disableVPNInterface || service == null) {
                            // No active VPN interface to reconfigure.
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        // Re-establish the TUN with the routes for the current
                        // (already-persisted) gateway state and hot-swap the fresh
                        // fd into the running backend. P2P stays up: its sockets
                        // are already protected and the swap replaces only the fd.
                        val newFd = establishTun(service, config)
                        Anywherelan.updateTunDevice(newFd)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("error", e.message, null)
                    }
                }
                "stop_server" -> {
                    Anywherelan.stopServer()
                    vpnService = null
                    result.success(null)
                }
                "import_config" -> {
                    try {
                        val text = call.argument<String>("config")
                        Anywherelan.importConfig(text)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("error", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // establishTun (re)creates the VpnService TUN interface from config and
    // returns its file descriptor. Routes depend on gateway client mode: when
    // on, route everything (0.0.0.0/0 + ::/0); when off, addAddress already
    // routes the awl subnet on-link, so no explicit route is added. The fd is
    // detached and handed to the Go side, which owns and closes it. Used both at
    // startup and by "reconfigure_vpn" for runtime gateway toggling, where a
    // fresh establish() is a seamless handover that swaps only the tun fd.
    private fun establishTun(service: MyVpnService, config: AppConfig): Int {
        val ipNetParts = config.vpn.ipNet.split("/")
        if (ipNetParts.size != 2) {
            throw Exception("Invalid ipNet format: ${config.vpn.ipNet}")
        }
        val networkAddress = ipNetParts[0]
        val networkAddressMask = ipNetParts[1].toInt()

        val builder: VpnService.Builder = service.builder
        builder.setSession(config.vpn.interfaceName)
        builder.addAddress(networkAddress, networkAddressMask)
        builder.setMtu(3500)

        if (config.vpnGateway.clientEnabled) {
            builder.addRoute("0.0.0.0", 0)
            builder.addRoute("::", 0)

            // Full-tunnel mode: pin DNS to the configured upstream so queries go
            // through the TUN (and the exit node) instead of leaking to the
            // device's own resolver. The Go DNSService cannot take over DNS on
            // Android (no awl :53 listener without root), so the host owns this.
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
            service.setUnderlyingNetworks(null)
        }

        var tunFd = 0
        builder.establish().use { tun ->
            if (tun == null) throw Exception("TUN_CREATION_ERROR")
            tunFd = tun.detachFd()
        }
        return tunFd
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
}

class MyVpnService : android.net.VpnService() {
    val builder: Builder
        get() = Builder()

    override fun onDestroy() {
        Anywherelan.stopServer()
        super.onDestroy()
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
