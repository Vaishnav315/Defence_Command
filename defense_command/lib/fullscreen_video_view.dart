import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

class FullScreenVideoView extends StatefulWidget {
  final String title;
  final String subtitle;
  final Map<String, String> details;
  final VideoTrack? videoTrack; // Added VideoTrack

  const FullScreenVideoView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.details,
    this.videoTrack,
  });

  @override
  State<FullScreenVideoView> createState() => _FullScreenVideoViewState();
}

class _FullScreenVideoViewState extends State<FullScreenVideoView> {
  bool _showControls = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          setState(() {
            _showControls = !_showControls;
          });
        },
        behavior: HitTestBehavior.translucent, // Capture taps even on blank space
        child: Stack(
          children: [
            // Video Background Placeholder
            // Video Feed
            Center(
              child: widget.videoTrack != null
                  ? VideoTrackRenderer(
                      widget.videoTrack!,
                      fit: VideoViewFit.cover,
                    )
                  : Container(
                      color: Colors.grey[900],
                      width: double.infinity,
                      height: double.infinity,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.videocam_off, size: 64, color: Colors.grey[800]),
                          const SizedBox(height: 16),
                          Text(
                            "NO VIDEO SIGNAL",
                            style: TextStyle(
                              color: Colors.grey[700],
                              letterSpacing: 2.0,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
            
            // Overlays
            if (_showControls) ...[
              // Top Bar
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back Button
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      // Title Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.subtitle,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Live Indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          "LIVE",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Bottom Details Panel
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.9),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: SafeArea(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Left side details
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: widget.details.entries.map((e) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Row(
                                  children: [
                                    Text(
                                      "${e.key}: ",
                                      style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 14,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        e.value,
                                        style: const TextStyle(
                                          color: Colors.greenAccent,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                          fontSize: 14,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        
                        const SizedBox(width: 24), // Added spacing
                        
                        // Right side controls
                        Row(
                          children: [
                            _buildCircleButton(Icons.mic_off),
                            const SizedBox(width: 16),
                            _buildCircleButton(Icons.camera_alt),
                            const SizedBox(width: 16),
                            _buildCircleButton(Icons.fullscreen_exit, onTap: () => Navigator.pop(context)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            
            // Crosshair Overlay (Always visible)
            Center(
              child: Opacity(
                opacity: 0.3,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.5)),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
