String mesecniGroupingKey({required String? id, required String putnikIme}) {
  if (id != null && id.trim().isNotEmpty) return id;
  return putnikIme.trim();
}
