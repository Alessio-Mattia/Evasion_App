/// Today as the server sees it: Postgres `current_date` is in UTC. Between
/// midnight and 1 or 2 am in Switzerland, the local date is already one day
/// ahead; checking against it would accept a birth date the server refuses.
DateTime serverToday([DateTime? now]) {
  final utc = (now ?? DateTime.now()).toUtc();
  return DateTime(utc.year, utc.month, utc.day);
}

/// Age in full years on [today], as Postgres
/// `extract(year from age(today, birth_date))` computes it: the birthday
/// counts from its own day.
int ageOn(DateTime birthDate, DateTime today) {
  final hadBirthday =
      today.month > birthDate.month ||
      (today.month == birthDate.month && today.day >= birthDate.day);
  return today.year - birthDate.year - (hadBirthday ? 0 : 1);
}

/// [date] as a Postgres `date` value (`2000-01-31`), whatever its time zone.
String toSqlDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';
