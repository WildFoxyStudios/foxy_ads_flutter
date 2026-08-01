import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';

class LocaleSwitcher extends ConsumerWidget {
  const LocaleSwitcher({super.key});

  static const _options = [
    ('🇪🇸', Locale('es'), 'Español'),
    ('🇬🇧', Locale('en'), 'English'),
    ('🇮🇹', Locale('it'), 'Italiano'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(localeProvider);
    final l = AppLocalizations.of(context);
    return PopupMenuButton<Locale>(
      tooltip: l.localeSwitcherAriaLabel,
      icon: const Icon(Icons.language),
      onSelected: (locale) =>
          ref.read(localeProvider.notifier).setLocale(locale),
      itemBuilder: (context) => _options.map((o) {
        final selected = o.$2 == current;
        return PopupMenuItem(
          value: o.$2,
          child: Row(children: [
            Text(o.$1),
            const SizedBox(width: 8),
            Text(o.$3),
            if (selected) ...[
              const Spacer(),
              const Icon(Icons.check, size: 16),
            ],
          ]),
        );
      }).toList(),
    );
  }
}