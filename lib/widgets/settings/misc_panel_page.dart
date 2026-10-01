/*
 * FLauncher
 * Copyright (C) 2024 LeanBitLab
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

import 'package:flauncher/providers/settings_service.dart';
import 'package:flauncher/widgets/rounded_switch_list_tile.dart';
import 'package:flauncher/widgets/settings/focusable_settings_tile.dart';
import 'package:flauncher/widgets/settings/plex_server_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flauncher/l10n/app_localizations.dart';

class MiscPanelPage extends StatelessWidget {
  static const String routeName = "misc_panel";

  const MiscPanelPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    SettingsService settingsService = Provider.of(context);

    return Column(
      children: [
        Text(localizations.miscellaneous, style: Theme.of(context).textTheme.titleLarge),
        const Divider(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              RoundedSwitchListTile(
                autofocus: true,
                value: settingsService.appHighlightAnimationEnabled,
                onChanged: (value) => settingsService.setAppHighlightAnimationEnabled(value),
                title: Text(localizations.appCardHighlightAnimation, style: Theme.of(context).textTheme.bodyMedium),
                secondary: const Icon(Icons.filter_center_focus),
              ),
              RoundedSwitchListTile(
                value: settingsService.appKeyClickEnabled,
                onChanged: (value) => settingsService.setAppKeyClickEnabled(value),
                title: Text(localizations.appKeyClick, style: Theme.of(context).textTheme.bodyMedium),
                secondary: const Icon(Icons.notifications_active),
              ),
              RoundedSwitchListTile(
                value: settingsService.showCategoryTitles,
                onChanged: (value) => settingsService.setShowCategoryTitles(value),
                title: Text(localizations.showCategoryTitles, style: Theme.of(context).textTheme.bodyMedium),
                secondary: const Icon(Icons.abc),
              ),
              RoundedSwitchListTile(
                value: settingsService.showAppNamesBelowIcons,
                onChanged: (value) => settingsService.setShowAppNamesBelowIcons(value),
                title: Text(localizations.showAppNamesBelowIcons, style: Theme.of(context).textTheme.bodyMedium),
                secondary: const Icon(Icons.subtitles),
              ),
              RoundedSwitchListTile(
                value: settingsService.hideHighlightOutlineOnHomescreen,
                onChanged: (value) => settingsService.setHideHighlightOutlineOnHomescreen(value),
                title: Text(localizations.hideHighlightOutlineOnHomescreen, style: Theme.of(context).textTheme.bodyMedium),
                secondary: const Icon(Icons.border_clear),
              ),
              RoundedSwitchListTile(
                value: settingsService.appSelectorTransitionAnimationEnabled,
                onChanged: (value) => settingsService.setAppSelectorTransitionAnimationEnabled(value),
                title: Text(localizations.appSelectorTransitionAnimation, style: Theme.of(context).textTheme.bodyMedium),
                secondary: const Icon(Icons.animation),
              ),
              FocusableSettingsTile(
                leading: const Icon(Icons.dns_outlined),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(localizations.plexServer, style: Theme.of(context).textTheme.bodyMedium),
                    Text(
                      settingsService.plexServerUrl.isEmpty ? localizations.notSet : settingsService.plexServerUrl,
                      style: Theme.of(context).textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                onPressed: () async {
                  final url = await showDialog<String>(
                    context: context,
                    builder: (_) => PlexServerDialog(initialValue: settingsService.plexServerUrl),
                  );
                  if (url != null) {
                    await settingsService.setPlexServerUrl(url);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
