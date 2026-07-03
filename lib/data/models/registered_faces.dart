// registered_faces.dart
// (You already have this file — move your existing content here.)
class RegisteredFace {
  final int? id;
  final String name;
  final String imagePath;
  final List<List<double>> embeddings;

  RegisteredFace({
    this.id,
    required this.name,
    required this.imagePath,
    required this.embeddings,
  });

  /// =========================
  /// FROM MAP (DB → MODEL)
  /// =========================
  factory RegisteredFace.fromMap(Map<String, dynamic> map) {
    return RegisteredFace(
      id: map['id'],
      name: map['name'],
      imagePath: map['imagePath'],
      embeddings: _decodeEmbeddings(map['embeddings']),
    );
  }

  /// =========================
  /// TO MAP (MODEL → DB)
  /// =========================
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'imagePath': imagePath,
      'embeddings': _encodeEmbeddings(embeddings),
    };
  }

  /// =========================
  /// ENCODE (LIST → STRING)
  /// =========================
  static String _encodeEmbeddings(List<List<double>> embeddings) {
    return embeddings.map((vec) => vec.join(',')).join(';');
  }

  /// =========================
  /// DECODE (STRING → LIST)
  /// =========================
  static List<List<double>> _decodeEmbeddings(String data) {
    if (data.isEmpty) return [];

    return data.split(';').map((vec) {
      return vec.split(',').map((e) {
        return double.tryParse(e) ?? 0.0;
      }).toList();
    }).toList();
  }
}
