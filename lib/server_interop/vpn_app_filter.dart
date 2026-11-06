/// An installed app shown in the per-app VPN filter picker.
class VpnAppEntry {
  final String pkg;
  final String label;

  const VpnAppEntry(this.pkg, this.label);
}

/// The persisted per-app VPN filter state (Android only).
class VpnAppFilterState {
  /// "none" | "denylist" ("all except selected") | "allowlist" ("only selected").
  final String mode;

  /// Selected package names.
  final List<String> packages;

  const VpnAppFilterState(this.mode, this.packages);
}
