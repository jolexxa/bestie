/// The mascot families that can live in the corner of the app.
enum Mascot {
  cow(id: 'cow', label: 'Cow'),
  dino(id: 'dino', label: 'Dino');

  const Mascot({required this.id, required this.label});

  /// The stable identifier persisted in configuration.
  final String id;

  /// The human-readable name shown in the config overlay.
  final String label;

  /// Resolves [id] to its mascot, falling back to [cow] for unknown ids.
  static Mascot parse(String id) => values.firstWhere(
    (mascot) => mascot.id == id,
    orElse: () => cow,
  );
}
