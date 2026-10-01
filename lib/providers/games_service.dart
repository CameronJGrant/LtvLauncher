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

import 'dart:typed_data';

import 'package:flauncher/flauncher_channel.dart';
import 'package:flutter/widgets.dart';

/// An app on a Moonlight-paired PC that can be streamed directly.
class Game {
  final String title;
  final String host;
  final String posterUri;
  final String intentUri;
  Uint8List? posterBytes;

  Game({required this.title, required this.host, required this.posterUri, required this.intentUri});
}

/// Games streamable through Moonlight, read from the preview programs Moonlight publishes for
/// Android TV: one per app on each paired PC, with its box art and a link that starts the stream.
class GamesService extends ChangeNotifier with WidgetsBindingObserver {
  static const _moonlight = "com.limelight";

  final FLauncherChannel _channel;
  List<Game> _games = const [];
  bool _refreshing = false;

  GamesService(this._channel) {
    WidgetsBinding.instance.addObserver(this);
    refresh();
  }

  List<Game> get games => _games;

  // Moonlight republishes its programs when a PC's app list changes, which happens while it's open.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
    }
  }

  Future<void> refresh() async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;
    try {
      final rows = await _channel.getPreviewPrograms();
      final knownPosters = {for (final game in _games) game.posterUri: game.posterBytes};
      final games = <Game>[];
      for (final row in rows) {
        final intentUri = row["intentUri"] as String? ?? "";
        if (row["packageName"] != _moonlight || intentUri.isEmpty) {
          continue;
        }
        final game = Game(
          title: row["title"] as String? ?? "",
          host: row["channelName"] as String? ?? "",
          posterUri: row["posterArtUri"] as String? ?? "",
          intentUri: intentUri,
        );
        game.posterBytes = knownPosters[game.posterUri];
        games.add(game);
      }
      games.sort((a, b) => a.host == b.host ? a.title.compareTo(b.title) : a.host.compareTo(b.host));
      _games = games;
      notifyListeners();

      for (final game in games.where((game) => game.posterBytes == null && game.posterUri.isNotEmpty)) {
        final bytes = await _channel.getWatchNextPoster(game.posterUri);
        if (bytes != null && bytes.isNotEmpty) {
          game.posterBytes = bytes;
          notifyListeners();
        }
      }
    } finally {
      _refreshing = false;
    }
  }

  Future<bool> launch(Game game) => _channel.launchWatchNextProgram(game.intentUri);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
