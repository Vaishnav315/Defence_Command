import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/entity_provider.dart';
import '../uavs_page.dart';  // Assuming this page exists for detail view

class UAVListPage extends StatelessWidget {
  const UAVListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final entities = Provider.of<EntityProvider>(context).entities;
    // Filter for UAVs
    final uavs = entities.where((e) => e.type == 'uav').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active UAVs'),
      ),
      body: uavs.isEmpty 
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.flight_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('No Active UAVs', style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey)),
              ],
            ),
          )
        : ListView.builder(
            itemCount: uavs.length,
            itemBuilder: (context, index) {
              final uav = uavs[index];
              
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 2,
                color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                child: InkWell(
                  onTap: () {
                    // Navigate to UAV Detail/Feed Page
                    // Assuming UAVsPage might take an ID in future refactor, 
                    // but for now sticking to existing UAVsPage or similar?
                    // The user asked for "a list screen for the uav also just like the soliders"
                    // Soldiers listing goes to SoldiersPage(id). 
                    // Let's assume we navigate to UAVsPage.
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const UAVsPage(), // Currently generic page
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Row(
                      children: [
                        // Icon
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.purple.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.flight, color: Colors.purple),
                        ),
                        const SizedBox(width: 16),
                        // ID and details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                uav.id,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Aerial Surveillance Unit',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Status
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "AIRBORNE", 
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green, 
                              fontSize: 10,
                              fontWeight: FontWeight.bold
                            )
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_ios, 
                          size: 14, 
                          color: isDark ? Colors.white38 : Colors.grey[400]
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
    );
  }
}
