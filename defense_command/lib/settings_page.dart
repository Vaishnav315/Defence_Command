import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // State for switches
  bool _notificationsEnabled = true;
  bool _darkMode = true; // Visual state only for now
  bool _biometrics = false;
  bool _locationTracking = true;
  bool _secureConnect = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Custom colors for the settings page to match the "Defense" aesthetic
    final sectionHeaderColor = isDark ? Colors.grey[500] : Colors.grey[700];
    final cardColor = theme.cardColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          "SYSTEM SETTINGS",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Section: General
          _buildSectionHeader("GENERAL", sectionHeaderColor),
          _buildSettingsCard(
            theme,
            children: [
              _buildSwitchTile(
                theme,
                title: "Push Notifications",
                subtitle: "Receive mission alerts and updates",
                icon: Icons.notifications_active,
                value: _notificationsEnabled,
                onChanged: (val) => setState(() => _notificationsEnabled = val),
              ),
              _buildDivider(theme),
              _buildSwitchTile(
                theme,
                title: "Dark Mode Interface",
                subtitle: "Tactical low-light display",
                icon: Icons.dark_mode,
                value: _darkMode,
                onChanged: (val) => setState(() => _darkMode = val),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: Security
          _buildSectionHeader("SECURITY & PRIVACY", sectionHeaderColor),
          _buildSettingsCard(
            theme,
            children: [
              _buildSwitchTile(
                theme,
                title: "Biometric Auth",
                subtitle: "Require fingerprint for access",
                icon: Icons.fingerprint,
                value: _biometrics,
                onChanged: (val) => setState(() => _biometrics = val),
              ),
              _buildDivider(theme),
              _buildSwitchTile(
                theme,
                title: "Secure Connection",
                subtitle: "Encrypt all telemetry data (TLS 1.3)",
                icon: Icons.vpn_lock,
                value: _secureConnect,
                onChanged: (val) => setState(() => _secureConnect = val),
              ),
              _buildDivider(theme),
              _buildSwitchTile(
                theme,
                title: "Location Tracking",
                subtitle: "Share device location with HQ",
                icon: Icons.gps_fixed,
                value: _locationTracking,
                onChanged: (val) => setState(() => _locationTracking = val),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Section: System Info
          _buildSectionHeader("SYSTEM INFORMATION", sectionHeaderColor),
          _buildSettingsCard(
            theme,
            children: [
              _buildInfoTile(
                theme,
                title: "App Version",
                value: "2.5.0 (Build 342)",
                icon: Icons.info_outline,
              ),
              _buildDivider(theme),
              _buildInfoTile(
                theme,
                title: "Device ID",
                value: "UNIT-ALPHA-77",
                icon: Icons.perm_device_information,
              ),
              _buildDivider(theme),
              _buildInfoTile(
                theme,
                title: "Server Status",
                value: "Online (9ms)",
                valueColor: Colors.green,
                icon: Icons.dns,
              ),
            ],
          ),
          
          const SizedBox(height: 40),
          
          // Reset Button
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: OutlinedButton.icon(
                onPressed: () {
                  // Formatting action
                },
                icon: Icon(Icons.refresh, size: 18, color: Colors.red[400]),
                label: Text(
                  "RESTORE DEFAULT CONFIGURATION",
                  style: TextStyle(
                    color: Colors.red[400],
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  side: BorderSide(color: Colors.red[400]!.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color? color) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(ThemeData theme, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSwitchTile(
    ThemeData theme, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: theme.iconTheme.color),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.blueGrey, // Changed from green to match theme
        activeTrackColor: Colors.blueGrey.withOpacity(0.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildInfoTile(
    ThemeData theme, {
    required String title,
    required String value,
    required IconData icon,
    Color? valueColor,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.dividerColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: theme.iconTheme.color?.withOpacity(0.7)),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
      ),
      trailing: Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: valueColor ?? theme.textTheme.bodyMedium?.color,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }

  Widget _buildDivider(ThemeData theme) {
    return Divider(height: 1, color: theme.dividerColor.withOpacity(0.5));
  }
}
