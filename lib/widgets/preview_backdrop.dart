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

import 'dart:ui' show ImageFilter;

import 'package:flauncher/providers/focused_app_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Full-screen artwork for the focused app's featured content, layered between
/// the wallpaper and the home screen's scrim.
class PreviewBackdrop extends StatelessWidget {
  const PreviewBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<FocusedAppService>(
      builder: (_, focusedApp, __) {
        final art = focusedApp.art;
        final image = focusedApp.image;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 700),
          // The default layout sizes to the child; the backdrop must fill the screen.
          layoutBuilder: (current, previous) => Stack(
            fit: StackFit.expand,
            children: [...previous, if (current != null) current],
          ),
          child: art == null || image == null
              ? const SizedBox.expand(key: ValueKey("backdrop-none"))
              : _PreviewArtView(key: ValueKey(art.uri), art: art, image: image),
        );
      },
    );
  }
}

class _PreviewArtView extends StatelessWidget {
  final PreviewArt art;
  final ImageProvider image;

  const _PreviewArtView({super.key, required this.art, required this.image});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (art.portrait) _blurredFill() else Image(image: image, fit: BoxFit.cover),
        // Scrims keep the tile row, section headers and clock readable over the art.
        const ColoredBox(color: Color(0x26000000)),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xB3000000), Color(0x00000000)],
              stops: [0.0, 0.6],
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Color(0xCC000000), Color(0x00000000)],
              stops: [0.0, 0.45],
            ),
          ),
        ),
        // Darken the top so badges baked into the art don't compete with the clock.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xCC000000), Color(0x00000000)],
              stops: [0.0, 0.28],
            ),
          ),
        ),
        // Above the scrims, so the poster itself stays crisp.
        if (art.portrait) _poster(),
      ],
    );
  }

  Widget _blurredFill() => ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Opacity(opacity: 0.6, child: Image(image: image, fit: BoxFit.cover)),
      );

  // BoxFit.cover would crop a portrait poster to an unrecognisable strip, so show it
  // intact below the tile row.
  Widget _poster() => Padding(
        padding: const EdgeInsets.fromLTRB(0, 0, 64, 48),
        child: Align(
          alignment: Alignment.bottomRight,
          child: FractionallySizedBox(
            heightFactor: 0.55,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image(image: image, fit: BoxFit.contain),
            ),
          ),
        ),
      );
}
