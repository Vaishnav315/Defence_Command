import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/entity_provider.dart';
import '../soldiers_page.dart';

class SoldierListPage extends StatelessWidget {
  const SoldierListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final entities = Provider.of<EntityProvider>(context).entities;
    // Filter for soldiers (and maybe scouts?) - User said "list the no of soilder"
    // putting soldiers and scouts together or just soldiers? 
    // "scout app and my marker did not appear ... differnt colur marker ... build an anthor scrren to list the no of soilder"
    // I will list all entities or just soldiers. Let's list Soldiers and Scouts.
    final soldiers = entities.where((e) => e.type == 'soldier' || e.type == 'scout').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Personnel'),
      ),
      body: ListView.builder(
        itemCount: soldiers.length,
        itemBuilder: (context, index) {
          final soldier = soldiers[index];
          final isScout = soldier.type == 'scout';
          
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 2,
            color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SoldiersPage(soldierId: soldier.id),
                  ),
                );
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
                        color: Colors.greenAccent, // Assume active for now
                        shape: BoxShape.circle,
                        boxShadow: [
                           BoxShadow(
                             color: Colors.greenAccent.withOpacity(0.4),
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
                            soldier.id,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isScout ? 'Scout Unit' : 'Infantry Unit',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action Icon
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
}

