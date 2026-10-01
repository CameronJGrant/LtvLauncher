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

import 'package:flauncher/actions.dart';
import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flauncher/providers/games_service.dart';
import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/app_card_keys.dart';
import 'package:flauncher/widgets/focus_keyboard_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Games from Moonlight-paired PCs, shown as box art that starts a stream when selected.
class GamesRow extends StatelessWidget {
  // Moonlight publishes box art as portrait movie posters.
  static const double _cardHeight = 210;

  final bool isFirstSection;

  const GamesRow({super.key, this.isFirstSection = false});

  @override
  Widget build(BuildContext context) {
    final bool showTitles = context.select<SettingsService, bool>((s) => s.showCategoryTitles);

    return Consumer<GamesService>(
      builder: (context, gamesService, _) {
        final games = gamesService.games;
        if (games.isEmpty) {
          return const SizedBox.shrink();
        }
        // Box art already names the game; the PC is only worth showing when there's a choice.
        final bool showHost = games.map((game) => game.host).toSet().length > 1;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showTitles)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        AppLocalizations.of(context)!.games,
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          shadows: [const Shadow(color: Colors.black54, offset: Offset(1, 1), blurRadius: 8)],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•  ${games.length}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                height: _cardHeight + (showHost ? 44 : 16),
                child: ListView.builder(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.all(8),
                  physics: const ClampingScrollPhysics(),
                  scrollDirection: Axis.horizontal,
                  itemCount: games.length,
                  itemBuilder: (context, index) => Padding(
                    key: ValueKey(games[index].intentUri),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GameCard(
                      game: games[index],
                      height: _cardHeight,
                      showHost: showHost,
                      handleUpNavigationToSettings: isFirstSection,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class GameCard extends StatefulWidget {
  final Game game;
  final double height;
  final bool showHost;
  final bool handleUpNavigationToSettings;

  const GameCard({
    super.key,
    required this.game,
    required this.height,
    this.showHost = false,
    this.handleUpNavigationToSettings = false,
  });

  @override
  State<GameCard> createState() => _GameCardState();
}

class _GameCardState extends State<GameCard> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_onFocusChange);
  }

  void _onFocusChange() {
    setState(() => _focused = _focusNode.hasFocus);
    if (_focusNode.hasFocus) {
      Scrollable.ensureVisible(
        context,
        alignment: 0.5,
        curve: Curves.easeInOut,
        duration: const Duration(milliseconds: 100),
      );
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _launch() => context.read<GamesService>().launch(widget.game);

  @override
  Widget build(BuildContext context) {
    final String accentColorHex = context.select<SettingsService, String>((s) => s.accentColorHex);
    final Color accentColor = Color(int.parse('FF$accentColorHex', radix: 16));
    final double width = widget.height * 2 / 3;
    final BorderRadius borderRadius = BorderRadius.circular(10);

    return FocusKeyboardListener(
      onPressed: (key) {
        if (key == LogicalKeyboardKey.arrowUp && widget.handleUpNavigationToSettings) {
          Actions.invoke(context, const MoveFocusToSettingsIntent());
          return KeyEventResult.handled;
        } else if (AppCardKeys.validationKeys.contains(key)) {
          _launch();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      builder: (context) => InkWell(
        focusNode: _focusNode,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: _launch,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: _focused ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutBack,
              child: Container(
                width: width,
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  color: const Color(0xFF141517),
                  boxShadow: _focused ? const [BoxShadow(color: Colors.black54, blurRadius: 16)] : null,
                ),
                // Drawn over the box art so the focus outline isn't hidden by it.
                foregroundDecoration: BoxDecoration(
                  borderRadius: borderRadius,
                  border: Border.all(
                    color: _focused ? accentColor : Colors.white.withOpacity(0.06),
                    width: _focused ? 3 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: borderRadius,
                  child: widget.game.posterBytes != null
                      ? Image.memory(widget.game.posterBytes!, fit: BoxFit.cover, cacheWidth: 300, gaplessPlayback: true)
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              widget.game.title,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ),
                ),
              ),
            ),
            if (widget.showHost) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: width,
                child: Text(
                  widget.game.host,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white54),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
