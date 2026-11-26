import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oshudh_reminder/data/models.dart';
import 'package:oshudh_reminder/l10n/codes.dart';
import 'package:oshudh_reminder/l10n/generated/app_localizations.dart';

void main() {
  final spec = jsonDecode(
    File('../spec/api/codes.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  for (final locale in AppLocalizations.supportedLocales) {
    test('every backend code has ${locale.languageCode} text', () async {
      final l = await AppLocalizations.delegate.load(
        Locale(locale.languageCode),
      );
      final missing = [
        for (final c in (spec['errors'] as List).cast<String>())
          if (localizeError(l, c) == null) c,
        for (final c in (spec['notices'] as List).cast<String>())
          if (localizeNotice(
                l,
                Notice(c, const {
                  'written': 'X',
                  'suggested': 'X',
                  'days': '9',
                }),
              ) ==
              null)
            c,
      ];
      expect(missing, isEmpty);
    });
  }

  test('notice parameters are filled in', () async {
    final l = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      localizeNotice(l, const Notice('name_corrected', {'written': 'Sargel'})),
      contains('Sargel'),
    );
  });
}
