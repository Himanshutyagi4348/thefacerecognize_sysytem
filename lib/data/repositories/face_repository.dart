import '../database/face_db.dart';
import '../models/registered_faces.dart';

class FaceRepository {
  FaceRepository._();
  static final FaceRepository instance = FaceRepository._();

  /// =========================
  /// GET ALL FACES
  /// =========================
  Future<List<RegisteredFace>> getAllFaces() async {
    final data = await FaceDB.getAllFaces();

  return data.map((e) {
      return RegisteredFace.fromMap(e as Map<String, dynamic>);
    }).toList();
  }

  /// =========================
  /// INSERT SINGLE FACE
  /// =========================
  Future<int> insertFace(RegisteredFace face) async {
    return await FaceDB.insertFace(
      name: face.name,
      imagePath: face.imagePath,
      embedding: face.embeddings.isNotEmpty ? face.embeddings.first : [],
    );
  }

  /// =========================
  /// INSERT MULTIPLE EMBEDDINGS (IMPORTANT)
  /// =========================
  Future<void> insertFaceWithEmbeddings({
    required String name,
    required String imagePath,
    required List<List<double>> embeddings,
  }) async {
    await FaceDB.insertFaceBatch(
      name: name,
      imagePath: imagePath,
      embeddings: embeddings,
    );
  }

  /// =========================
  /// DELETE FACE
  /// =========================
  Future<void> deleteFace(int id) async {
    await FaceDB.deleteUser(id);
  }

  /// =========================
  /// CLEAR ALL FACES
  /// =========================
  Future<void> clearAll() async {
    await FaceDB.clearAll();
  }

  /// =========================
  /// FIND BY NAME
  /// =========================
  Future<RegisteredFace?> findByName(String name) async {
    final faces = await getAllFaces();

    try {
      return faces.firstWhere(
        (f) => f.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
