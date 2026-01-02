import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/entity_provider.dart';
import '../soldiers_page.dart';
import '../uavs_page.dart';

class EntityListPage extends StatelessWidget {
  final String title;
  final String entityType; // 'soldier', 'tank', 'uav', 'artillery'

  const EntityListPage({
    super.key, 
    required this.title, 
    required this.entityType
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final entities = Provider.of<EntityProvider>(context).entities;
    
    // Filter entities
    final filteredList = entities.where((e) {
      if (entityType == 'soldier') {
        return e.type == 'soldier' || e.type == 'scout' || e.type == 'infantry';
      }
      return e.type == entityType;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: filteredList.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.radar, size: 64, color: theme.disabledColor),
                   const SizedBox(height: 16),
                   Text("No active $entityType units detected", style: theme.textTheme.bodyLarge),
                ],
              ),
            )
          : ListView.builder(
        itemCount: filteredList.length,
        itemBuilder: (context, index) {
          final entity = filteredList[index];
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: InkWell(
              onTap: () {
                // Navigate to specific detail page if available
                if (entityType == 'soldier' || entity.type == 'scout') {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => SoldiersPage(soldierId: entity.id)));
                } else if (entityType == 'uav') {
                   Navigator.push(context, MaterialPageRoute(builder: (_) => UAVsPage(uavId: entity.id)));
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    // Status Indicator
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getStatusColor(entity.type), 
                        shape: BoxShape.circle,
                        boxShadow: [
                           BoxShadow(
                             color: _getStatusColor(entity.type).withOpacity(0.4),
                             blurRadius: 4,
                             spreadRadius: 2,
                           )
                        ]
                      ),
                    ),
                    const SizedBox(width: 16),
                    // ID and Type
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entity.id,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Lat: ${entity.position.latitude.toStringAsFixed(4)}, Lng: ${entity.position.longitude.toStringAsFixed(4)}",
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action Icon
                    if (entityType == 'soldier')
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.visibility_outlined, 
                        size: 20, 
                        color: isDark ? Colors.white70 : Colors.black54
                      ),
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
  
  Color _getStatusColor(String type) {
    switch (type) {
      case 'tank': return Colors.red;
      case 'artillery': return Colors.purple;
      case 'uav': return Colors.blue;
      default: return Colors.greenAccent;
    }
  }
}
