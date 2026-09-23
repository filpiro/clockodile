import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';
// ignore: implementation_imports
import 'package:shadcn_flutter/src/components/locale/shadcn_localizations_en.dart';

/// Italian for the shadcn strings that reach our screens. Anything not
/// overridden falls back to English. After a shadcn upgrade, diff the
/// package's `lib/l10n/shadcn_en.arb` for new strings.
class ShadcnLocalizationsIt extends ShadcnLocalizationsEn {
  ShadcnLocalizationsIt() : super('it');

  static const LocalizationsDelegate<ShadcnLocalizations> delegate =
      _Delegate();

  @override
  String get datePickerSelectYear => 'Seleziona un anno';
  @override
  String get abbreviatedMonday => 'Lu';
  @override
  String get abbreviatedTuesday => 'Ma';
  @override
  String get abbreviatedWednesday => 'Me';
  @override
  String get abbreviatedThursday => 'Gi';
  @override
  String get abbreviatedFriday => 'Ve';
  @override
  String get abbreviatedSaturday => 'Sa';
  @override
  String get abbreviatedSunday => 'Do';
  @override
  String get monthJanuary => 'Gennaio';
  @override
  String get monthFebruary => 'Febbraio';
  @override
  String get monthMarch => 'Marzo';
  @override
  String get monthApril => 'Aprile';
  @override
  String get monthMay => 'Maggio';
  @override
  String get monthJune => 'Giugno';
  @override
  String get monthJuly => 'Luglio';
  @override
  String get monthAugust => 'Agosto';
  @override
  String get monthSeptember => 'Settembre';
  @override
  String get monthOctober => 'Ottobre';
  @override
  String get monthNovember => 'Novembre';
  @override
  String get monthDecember => 'Dicembre';
  @override
  String get abbreviatedJanuary => 'Gen';
  @override
  String get abbreviatedFebruary => 'Feb';
  @override
  String get abbreviatedMarch => 'Mar';
  @override
  String get abbreviatedApril => 'Apr';
  @override
  String get abbreviatedMay => 'Mag';
  @override
  String get abbreviatedJune => 'Giu';
  @override
  String get abbreviatedJuly => 'Lug';
  @override
  String get abbreviatedAugust => 'Ago';
  @override
  String get abbreviatedSeptember => 'Set';
  @override
  String get abbreviatedOctober => 'Ott';
  @override
  String get abbreviatedNovember => 'Nov';
  @override
  String get abbreviatedDecember => 'Dic';
  @override
  String get buttonCancel => 'Annulla';
  @override
  String get buttonSave => 'Salva';
  @override
  String get buttonPrevious => 'Precedente';
  @override
  String get buttonNext => 'Successivo';
  @override
  String get timeHour => 'Ora';
  @override
  String get timeMinute => 'Minuto';
  @override
  String get timeSecond => 'Secondo';
  @override
  String get menuCut => 'Taglia';
  @override
  String get menuCopy => 'Copia';
  @override
  String get menuPaste => 'Incolla';
  @override
  String get menuSelectAll => 'Seleziona tutto';
  @override
  String get menuUndo => 'Annulla';
  @override
  String get menuRedo => 'Ripeti';
  @override
  String get menuDelete => 'Elimina';
  @override
  String get menuShare => 'Condividi';
  @override
  String get menuSearchWeb => 'Cerca sul web';
  @override
  String get noSpellCheckReplacements => 'Nessun suggerimento';
  @override
  String get placeholderDatePicker => 'Seleziona una data';
  @override
  String get placeholderTimePicker => 'Seleziona un orario';
}

class _Delegate extends LocalizationsDelegate<ShadcnLocalizations> {
  const _Delegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'it';

  @override
  Future<ShadcnLocalizations> load(Locale locale) =>
      SynchronousFuture(ShadcnLocalizationsIt());

  @override
  bool shouldReload(_Delegate old) => false;
}
