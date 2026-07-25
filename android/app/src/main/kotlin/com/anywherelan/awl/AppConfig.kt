package com.anywherelan.awl

import org.json.JSONObject

data class AppConfig(
    val vpn: VpnConfig,
    val vpnGateway: VPNGatewayConfig,
    val dns: DnsConfig,
) {
    companion object {
        fun fromJson(jsonString: String): AppConfig {
            val root = JSONObject(jsonString)
            val vpnJson = root.getJSONObject("vpn")

            val vpnConfig = VpnConfig(
                disableVPNInterface = vpnJson.getBoolean("disableVPNInterface"),
                interfaceName = vpnJson.getString("interfaceName"),
                ipNet = vpnJson.getString("ipNet")
            )

            val dnsJson = root.optJSONObject("dns")
            val dnsConfig = DnsConfig(
                disableDNS = dnsJson?.optBoolean("disableDNS", false) ?: false,
                upstreamDNSAddress = dnsJson?.optString("upstreamDNSAddress", "") ?: ""
            )

            // gateway is optional for forward-compat with older configs that
            // pre-date this section; treat a missing object as all-defaults.
            val gatewayJson = root.optJSONObject("vpnGateway")
            val gatewayConfig = if (gatewayJson != null) {
                VPNGatewayConfig(
                    clientEnabled = gatewayJson.optBoolean("clientEnabled", false),
                    gatewayPeerID = gatewayJson.optString("gatewayPeerID", ""),
                    serverEnabled = gatewayJson.optBoolean("serverEnabled", false),
                )
            } else {
                VPNGatewayConfig(false, "", false)
            }

            return AppConfig(vpnConfig, gatewayConfig, dnsConfig)
        }
    }
}

data class VpnConfig(
    val disableVPNInterface: Boolean,
    val interfaceName: String,
    val ipNet: String
)

// GatewayConfig mirrors GatewayConfig in github.com/anywherelan/awl/config.
//
// `clientEnabled` — full-tunnel mode is on; we should add a 0.0.0.0/0 route to the
//   VpnService.Builder and register a SocketProtector so libp2p traffic
//   bypasses the TUN. Without the protector AWL would route its own peer
//   connections back into itself and never reach the exit node.
//
// `gatewayPeerID` — selected exit node, informational on the Android side.
//
// `serverEnabled` — this device offers itself as a VPN gateway. Acting
//   as an exit node from Android is not supported (no MASQUERADE on a
//   non-rooted device), but we still parse the field so that the value
//   round-trips through GetConfig/UpdateConfig if the user toggles it.
data class VPNGatewayConfig(
    val clientEnabled: Boolean,
    val gatewayPeerID: String,
    val serverEnabled: Boolean,
)

// DnsConfig mirrors DNSConfig in github.com/anywherelan/awl/config.
//
// `disableDNS` — DNS is off entirely (also the field kill switch for the
//   interceptor): establishTun then does not call addDnsServer with the awl
//   DNS IP and the Go side does not install the interceptor.
//
// `upstreamDNSAddress` — the public resolver (host:port) the Go side forwards
//   non-.awl queries to. Normally the device talks to the in-tunnel awl DNS
//   IP (Anywherelan.dnsServerIP) and the Go resolver does the forwarding;
//   this address is used by the host directly only when DNS is disabled but
//   full-tunnel (gateway client) mode is on — then VpnService pins it via
//   addDnsServer so queries do not leak around the tunnel. The port is
//   stripped — VpnService.addDnsServer takes a bare IP.
data class DnsConfig(
    val disableDNS: Boolean,
    val upstreamDNSAddress: String,
)
