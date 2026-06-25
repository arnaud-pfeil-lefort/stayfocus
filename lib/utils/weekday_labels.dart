/// French weekday abbreviations, indexed by `DateTime.weekday - 1` (0 = Lundi).
const weekdayShortLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

/// French weekday full names, indexed by `DateTime.weekday - 1` (0 = Lundi).
const weekdayFullLabels = [
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
  'Dimanche',
];

/// Formats [day] as a French weekday + date label, e.g. "Lundi 23/6".
String formatWeekdayDate(DateTime day) =>
    '${weekdayFullLabels[day.weekday - 1]} ${day.day}/${day.month}';
