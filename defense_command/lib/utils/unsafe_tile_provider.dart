import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

class UnsafeTileProvider extends TileProvider {
  UnsafeTileProvider({super.headers});

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    // Generate the URL for the tile
    final url = getTileUrl(coordinates, options);
    
    // Return a custom ImageProvider that ignores SSL errors
    return _UnsafeNetworkImageProvider(url, headers: headers);
  }
}

class _UnsafeNetworkImageProvider extends ImageProvider<_UnsafeNetworkImageProvider> {
  final String url;
  final Map<String, String>? headers;

  // Shared Client to prevent socket exhaustion
  // Shared Client to prevent socket exhaustion
  static final HttpClient _sharedClient = HttpClient()
    ..idleTimeout = const Duration(seconds: 30)
    ..maxConnectionsPerHost = 20 // Allow more parallel tile fetches
    ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;

  _UnsafeNetworkImageProvider(this.url, {this.headers});

  @override
  Future<_UnsafeNetworkImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<_UnsafeNetworkImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadBuffer(_UnsafeNetworkImageProvider key, DecoderBufferCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode),
      scale: 1.0,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<_UnsafeNetworkImageProvider>('Image key', key),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(_UnsafeNetworkImageProvider key, DecoderBufferCallback decode) async {
    try {
      final Uri uri = Uri.parse(key.url);
      final HttpClientRequest request = await _sharedClient.getUrl(uri);
      
      // Ensure User-Agent is present (Required by OSM/OpenWeather)
      if (key.headers == null || !key.headers!.containsKey('User-Agent')) {
        request.headers.add('User-Agent', 'DefenseCommandApp/1.0');
      }
      
      key.headers?.forEach((k, v) => request.headers.add(k, v));
      
      final HttpClientResponse response = await request.close();
      
      if (response.statusCode != HttpStatus.ok) {
        throw Exception('HTTP ${response.statusCode}');
      }
      
      final Uint8List bytes = await consolidateHttpClientResponseBytes(response);
      
      final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return decode(buffer);
    } catch (e) {
      debugPrint("Failed to load tile ${key.url}: $e");
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) return false;
    return other is _UnsafeNetworkImageProvider && other.url == url;
  }

  @override
  int get hashCode => url.hashCode;
}
