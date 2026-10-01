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

import 'package:flauncher/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Edits the Plex server address. Returns the entered text, which may be empty to clear it.
class PlexServerDialog extends StatefulWidget {
  final String initialValue;

  const PlexServerDialog({super.key, required this.initialValue});

  @override
  State<PlexServerDialog> createState() => _PlexServerDialogState();
}

class _PlexServerDialogState extends State<PlexServerDialog> {
  late final FocusNode _focusNode;
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_focusNode.hasFocus) {
          _focusNode.unfocus();
          SystemChannels.textInput.invokeMethod('TextInput.hide');
        } else {
          Navigator.of(context).pop();
        }
      },
      child: SimpleDialog(
        insetPadding: const EdgeInsets.only(bottom: 120),
        contentPadding: const EdgeInsets.all(24),
        title: Text(localizations.plexServer),
        children: [
          TextFormField(
            focusNode: _focusNode,
            autofocus: true,
            controller: _controller,
            decoration: InputDecoration(labelText: localizations.plexServerHint),
            keyboardType: TextInputType.url,
            onFieldSubmitted: (value) => Navigator.of(context).pop(value),
          ),
        ],
      ),
    );
  }
}
