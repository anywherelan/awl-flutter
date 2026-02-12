package com.anywherelan.awl

import org.json.JSONObject

data class AppConfig(
    val vpn: VpnConfig
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

            return AppConfig(vpnConfig)
        }
    }
}

data class VpnConfig(
    val disableVPNInterface: Boolean,
    val interfaceName: String,
    val ipNet: String
)
