import 'dart:convert';

class RegisteredFace {
  final int? id;
  final String name;
  final String imagePath;
  final String? createdAt;
  final List<List<double>> embeddings;

  RegisteredFace({
    this.id,
    required this.name,
    required this.imagePath,
    this.createdAt,
    required this.embeddings,
  });

  /// =========================
  /// FROM MAP (DB → MODEL)
  /// =========================
  factory RegisteredFace.fromMap(Map<String, dynamic> map) {
    final List<List<double>> loadedEmbeddings = [];

    if (map.containsKey('embedding_front') &&
        map.containsKey('embedding_left') &&
        map.containsKey('embedding_right') &&
        map.containsKey('embedding_top') &&
        map.containsKey('embedding_bottom')) {
      final front = _decodeEmbedding(map['embedding_front']);
      final left = _decodeEmbedding(map['embedding_left']);
      final right = _decodeEmbedding(map['embedding_right']);
      final top = _decodeEmbedding(map['embedding_top']);
      final bottom = _decodeEmbedding(map['embedding_bottom']);

      if (front.isNotEmpty) loadedEmbeddings.add(front);
      if (left.isNotEmpty) loadedEmbeddings.add(left);
      if (right.isNotEmpty) loadedEmbeddings.add(right);
      if (top.isNotEmpty) loadedEmbeddings.add(top);
      if (bottom.isNotEmpty) loadedEmbeddings.add(bottom);
    } else if (map.containsKey('embeddings')) {
      final embeddingsData = map['embeddings'] as String?;
      if (embeddingsData != null && embeddingsData.isNotEmpty) {
        loadedEmbeddings.addAll(_decodeEmbeddings(embeddingsData));
      }
    }

    return RegisteredFace(
      id: map['id'] as int?,
      name: map['name'] as String,
      imagePath: map['imagePath'] as String? ?? '',
      createdAt: map['created_at'] as String?,
      embeddings: loadedEmbeddings,
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
      'created_at': createdAt,
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

    return data
        .split(';')
        .map(
          (vec) =>
              vec.split(',').map((e) => double.tryParse(e) ?? 0.0).toList(),
        )
        .toList();
  }

  /// =========================
  /// DECODE SINGLE EMBEDDING
  /// =========================
  static List<double> _decodeEmbedding(dynamic data) {
    if (data == null) return [];
    if (data is String) {
      try {
        final decoded = jsonDecode(data) as List<dynamic>;
        return decoded.map((e) => (e as num).toDouble()).toList();
      } catch (_) {
        return [];
      }
    }
    if (data is List) {
      return data.map((e) => (e as num).toDouble()).toList();
    }
    return [];
  }
}
