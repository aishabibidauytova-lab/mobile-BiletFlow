import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// App-bar button that opens a menu with RU / ENG / KAZ language choices.
class LanguageMenu extends StatelessWidget {
  const LanguageMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AppLang>(
      tooltip: tr('language'),
      onSelected: l10n.set,
      itemBuilder: (_) => [
        for (final l in AppLang.values)
          CheckedPopupMenuItem<AppLang>(
            value: l,
            checked: l == l10n.lang,
            child: Text(l.nativeName),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 22),
            const SizedBox(width: 4),
            Text(l10n.lang.code.toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
