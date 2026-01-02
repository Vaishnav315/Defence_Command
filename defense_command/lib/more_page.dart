import 'package:flutter/material.dart';
import 'simulation_screen.dart';
import 'pages/mission_history_page.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Additional Tools',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          
          // Simulation Room Tile
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.videogame_asset_outlined, color: Colors.blueAccent),
            ),
            title: const Text('Tactical Simulation'),
            subtitle: const Text('Plan missions and calculate routes'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SimulationScreen()),
              );
            },
          ),
          
          Divider(color: theme.dividerColor),

          // Placeholder for other settings
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.analytics_outlined, color: Colors.orange),
            ),
            title: const Text('Mission Analytics'),
            subtitle: const Text('View post-mission reports'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MissionHistoryPage()),
              );
            },
          ),
        ],
      ),
    );
  }
}