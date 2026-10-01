/*
 * FLauncher
 * Copyright (C) 2021  Étienne Fesser
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/widgets.dart';

/// One piece of featured content an app publishes to the Android TV home screen.
class PreviewArt {
  final String uri;

  /// Art is published either landscape (16:9, 3:2, 4:3) or as a portrait movie
  /// poster; the backdrop lays the two out differently.
  final bool portrait;

  const PreviewArt(this.uri, this.portrait);
}

/// Drives the home-screen backdrop. When an app tile gains focus, cycles through
/// the featured content that app publishes (Netflix picks, Plex recommendations,
/// Moonlight hosts...), crossfading every [rotateEvery].
class FocusedAppService extends ChangeNotifier with WidgetsBindingObserver {
  static const rotateEvery = Duration(seconds: 10);
  static const _refreshEvery = Duration(minutes: 15);
  // Prime Video alone publishes ~60 programs; keep a full rotation cached.
  static const _imageCacheSize = 64;

  final FLauncherChannel _channel;

  Map<String, List<PreviewArt>> _previews = const {};
  DateTime? _previewsLoadedAt;
  Future<void>? _loading;

  final LinkedHashMap<String, ImageProvider> _images = LinkedHashMap();
  // Artwork that failed to load (e.g. an app's cached poster was cleared); retried on
  // the next preview refresh rather than on every rotation tick.
  final Set<String> _failed = {};

  String? _packageName;
  List<PreviewArt> _rotationArt = const [];
  int _index = 0;
  Timer? _rotation;

  PreviewArt? _art;
  ImageProvider? _image;

  FocusedAppService(this._channel) {
    WidgetsBinding.instance.addObserver(this);
  }

  PreviewArt? get art => _art;

  ImageProvider? get image => _image;

  Future<void> setFocused(String packageName) async {
    if (_packageName == packageName) {
      return;
    }
    _packageName = packageName;
    _rotation?.cancel();

    await _ensurePreviews();
    if (_packageName != packageName) {
      return;
    }

    _rotationArt = _previews[packageName] ?? const [];
    _index = 0;
    await _showFirstAvailable(packageName);
    if (_packageName == packageName) {
      _startRotation();
    }
  }

  // Don't keep fetching artwork while an app is in front of the launcher. Coming back,
  // re-read the previews: Plex republishes its rows with new image ids whenever it runs,
  // so the list loaded before it was opened is likely stale.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _previewsLoadedAt = null;
      final packageName = _packageName;
      if (packageName != null) {
        _packageName = null;
        setFocused(packageName);
      }
    } else {
      _rotation?.cancel();
    }
  }

  void _startRotation() {
    _rotation?.cancel();
    final packageName = _packageName;
    if (packageName == null || _rotationArt.length < 2) {
      return;
    }
    _rotation = Timer.periodic(rotateEvery, (_) {
      _index = (_index + 1) % _rotationArt.length;
      _showNext(packageName);
    });
  }

  Future<void> _showFirstAvailable(String packageName) async {
    for (var attempt = 0; attempt < _rotationArt.length; attempt++) {
      final art = _rotationArt[_index];
      final image = await _imageFor(art.uri);
      // Focus may have moved on while the artwork was loading.
      if (_packageName != packageName) {
        return;
      }
      if (image != null) {
        _show(art, image);
        return;
      }
      _index = (_index + 1) % _rotationArt.length;
    }
    _show(null, null);
  }

  Future<void> _showNext(String packageName) async {
    final art = _rotationArt[_index];
    final image = await _imageFor(art.uri);
    if (_packageName == packageName && image != null) {
      _show(art, image);
    }
  }

  void _show(PreviewArt? art, ImageProvider? image) {
    _art = art;
    _image = image;
    notifyListeners();
  }

  Future<void> _ensurePreviews() {
    final loadedAt = _previewsLoadedAt;
    if (loadedAt != null && DateTime.now().difference(loadedAt) < _refreshEvery) {
      return Future.value();
    }
    return _loading ??= _loadPreviews().whenComplete(() => _loading = null);
  }

  Future<void> _loadPreviews() async {
    final rows = await _channel.getPreviewPrograms();
    final grouped = <String, List<PreviewArt>>{};
    for (final row in rows) {
      final packageName = row["packageName"] as String?;
      final art = _artFrom(row);
      if (packageName == null || art == null) {
        continue;
      }
      grouped.putIfAbsent(packageName, () => []).add(art);
    }
    _previews = grouped;
    _previewsLoadedAt = DateTime.now();
    _failed.clear();
  }

  // TvContract aspect ratio constants: 0 = 16:9, 1 = 3:2, 2 = 4:3, 3 = 1:1,
  // 4 = 2:3, 5 = movie poster (1:1.441).
  static bool _isPortrait(int aspectRatio) => aspectRatio == 4 || aspectRatio == 5;

  static PreviewArt? _artFrom(Map<dynamic, dynamic> row) {
    final poster = row["posterArtUri"] as String?;
    final posterAspect = (row["posterArtAspectRatio"] as int?) ?? 0;
    final thumbnail = row["thumbnailUri"] as String?;
    final thumbnailAspect = (row["thumbnailAspectRatio"] as int?) ?? 0;

    // Prefer landscape art: it fills a TV screen without cropping.
    if (poster != null && poster.isNotEmpty && !_isPortrait(posterAspect)) {
      return PreviewArt(poster, false);
    }
    if (thumbnail != null && thumbnail.isNotEmpty && !_isPortrait(thumbnailAspect)) {
      return PreviewArt(thumbnail, false);
    }
    if (poster != null && poster.isNotEmpty) {
      return PreviewArt(poster, true);
    }
    return null;
  }

  Future<ImageProvider?> _imageFor(String uri) async {
    if (_failed.contains(uri)) {
      return null;
    }
    final cached = _images.remove(uri);
    if (cached != null) {
      _images[uri] = cached; // re-insert as most recently used
      return cached;
    }

    final Uint8List? bytes = await _channel.getWatchNextPoster(uri);
    if (bytes == null || bytes.isEmpty) {
      _failed.add(uri);
      return null;
    }
    final image = MemoryImage(bytes);
    _images[uri] = image;
    if (_images.length > _imageCacheSize) {
      _images.remove(_images.keys.first);
    }
    return image;
  }

  @override
  void dispose() {
    _rotation?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
