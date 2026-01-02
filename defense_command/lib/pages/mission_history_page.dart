import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:intl/intl.dart';

class MissionHistoryPage extends StatefulWidget {
  const MissionHistoryPage({super.key});

  @override
  State<MissionHistoryPage> createState() => _MissionHistoryPageState();
}

class _MissionHistoryPageState extends State<MissionHistoryPage> {
  List<MissionHistory> _history = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final history = await ApiService.fetchMissionHistory();
    setState(() {
      _history = history;
      _isLoading = false;
    });
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All History?'),
        content: const Text('This will permanently delete all mission records and GPS logs.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      final success = await ApiService.clearMissionHistory();
      if (success) {
        _loadHistory();
      } else {
        setState(() => _isLoading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to clear history')));
      }
    }
  }

  String _formatDate(String timestamp) {
    try {
      final dt = DateTime.parse(timestamp).toLocal();
      return DateFormat('MMM dd, yyyy HH:mm').format(dt);
    } catch (e) {
      return timestamp;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mission Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            onPressed: _history.isEmpty ? null : _clearHistory,
            tooltip: 'Clear All Data',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHistory,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _history.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.history, size: 64, color: theme.hintColor.withValues(alpha: 0.5)),
                   const SizedBox(height: 16),
                   Text('No mission history found.', style: theme.textTheme.titleMedium),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final mission = _history[index];
                return ExpansionTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.blueAccent,
                    child: Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                  title: Text('Session: ${mission.scoutId}'),
                  subtitle: Text('Synced: ${_formatDate(mission.syncTimestamp)}'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('GPS Data Points: ${mission.gpsLogs.length}', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                              TextButton.icon(
                                onPressed: () {
                                   // Logic to open video URL if needed
                                },
                                icon: const Icon(Icons.play_circle_outline, size: 16),
                                label: const Text('Play Video'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildGpsTable(mission.gpsLogs),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildGpsTable(List<MissionGpsLog> logs) {
    final theme = Theme.of(context);
    
    if (logs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(8.0),
        child: Text('No GPS logs available for this session.'),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Table(
        columnWidths: const {
          0: FlexColumnWidth(2),
          1: FlexColumnWidth(1.5),
          2: FlexColumnWidth(1.5),
        },
        border: TableBorder.symmetric(inside: BorderSide(color: theme.dividerColor, width: 0.5)),
        children: [
          TableRow(
            decoration: BoxDecoration(color: theme.hoverColor),
            children: [
              _buildHeaderCell('Time (UTC)'),
              _buildHeaderCell('Latitude'),
              _buildHeaderCell('Longitude'),
            ],
          ),
          ...logs.map((log) => TableRow(
            children: [
              _buildDataCell(_formatTime(log.timestamp)),
              _buildDataCell(log.lat.toStringAsFixed(6)),
              _buildDataCell(log.lng.toStringAsFixed(6)),
            ],
          )),
        ],
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      // If it's a unix timestamp as string, parse it
      final unix = int.tryParse(timestamp);
      if (unix != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(unix, isUtc: true);
        return DateFormat('HH:mm:ss').format(dt);
      }
      // Otherwise try standard parsing
      final dt = DateTime.parse(timestamp);
      return DateFormat('HH:mm:ss').format(dt);
    } catch (e) {
      return timestamp;
    }
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildDataCell(String text) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  }
}
