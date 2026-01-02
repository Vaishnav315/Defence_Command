import 'package:flutter/material.dart';
import 'fullscreen_video_view.dart';
import 'package:livekit_client/livekit_client.dart';

class UAVsPage extends StatefulWidget {
  final Participant? participant;
  final VideoTrack? videoTrack;
  final String? uavId;

  const UAVsPage({
    super.key, 
    this.participant, 
    this.videoTrack, 
    this.uavId
  });

  @override
  State<UAVsPage> createState() => _UAVsPageState();
}

class _UAVsPageState extends State<UAVsPage> {
  final bool _isFullScreen = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final String displayId = widget.uavId ?? (widget.participant?.identity ?? 'UAV-404');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
        child: Column(
          children: [
            // Top Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              color: theme.appBarTheme.backgroundColor ?? theme.scaffoldBackgroundColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'UAV Details',
                        style: theme.textTheme.titleLarge?.copyWith(fontSize: 20),
                      ),
                    ],
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                    child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

            // UAV Video Feed
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.grey[300],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    if (widget.videoTrack != null)
                      VideoTrackRenderer(
                        widget.videoTrack!,
                        fit: VideoViewFit.cover,
                      )
                    else
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.signal_wifi_off, size: 52, color: isDark ? Colors.grey[700] : Colors.grey[600]),
                            const SizedBox(height: 8),
                            Text('$displayId Feed', style: TextStyle(color: isDark ? Colors.grey : Colors.grey[700], fontSize: 15, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('Signal Lost', style: TextStyle(color: isDark ? Colors.grey : Colors.grey[700], fontSize: 12)),
                          ],
                        ),
                      ),

                    // Video controls
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(18)),
                            child: IconButton(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const FullScreenVideoView(
                                  title: 'UAV-404 Live Feed',
                                  subtitle: 'Target Acquired',
                                  details: {"Battery": "85%", "Altitude": "5,200 ft", "Speed": "120 km/h"},
                                )));
                              },
                              icon: Icon(_isFullScreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 18),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(18)),
                            child: IconButton(
                              onPressed: () {},
                              icon: const Icon(Icons.settings, color: Colors.white, size: 18),
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Content Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                   // Telemetry + Flight Path (Simplified)
                   SizedBox(
                     height: 160,
                     child: Row(
                       children: [
                         Expanded(
                           child: Container(
                             padding: const EdgeInsets.all(14),
                             decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.dividerColor)),
                             child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                               Text('Telemetry', style: theme.textTheme.titleLarge?.copyWith(fontSize: 20)),
                               const SizedBox(height: 12),
                               Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                                 _buildTelemetryRow(theme, icon: Icons.battery_full, label: 'Battery:', value: '85%'),
                                 _buildTelemetryRow(theme, icon: Icons.speed, label: 'Speed:', value: '120 km/h'),
                                 _buildTelemetryRow(theme, icon: Icons.height, label: 'Altitude:', value: '5,000 ft'),
                               ])),
                             ]),
                           ),
                         ),
                         const SizedBox(width: 12),
                         Expanded(
                           child: Container(
                             padding: const EdgeInsets.all(14),
                             decoration: BoxDecoration(color: theme.cardColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.dividerColor)),
                             child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                               Icon(Icons.map, size: 48, color: theme.iconTheme.color?.withValues(alpha: 0.5)),
                               const SizedBox(height: 8),
                               Text('Flight Path\nMini-Map', textAlign: TextAlign.center, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 14)),
                             ]),
                           ),
                         ),
                       ],
                     ),
                   ),

                   const SizedBox(height: 16),
                   // Details
                   Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('UAV Details', style: theme.textTheme.titleLarge?.copyWith(fontSize: 18)),
                        const SizedBox(height: 16),
                        _buildDetailRow(theme, label: 'ID:', value: 'UAV-404'),
                        _buildDashedDivider(theme),
                        _buildDetailRow(theme, label: 'Type:', value: 'Reconnaissance Drone'),
                        _buildDashedDivider(theme),
                        // Status
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Status:', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(4)),
                                child: const Text('Active', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                   ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildTelemetryRow(ThemeData theme, {required IconData icon, required String label, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [Icon(icon, color: theme.iconTheme.color, size: 18), const SizedBox(width: 6), Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13))]),
        Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildDetailRow(ThemeData theme, {required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14)),
          Text(value, style: theme.textTheme.bodyLarge?.copyWith(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDashedDivider(ThemeData theme) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: LayoutBuilder(builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 4.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(dashCount, (_) => SizedBox(width: dashWidth, height: 1, child: ColoredBox(color: theme.dividerColor))),
        );
      }),
    );
  }
}