import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/analysis_result.dart';
import '../../../models/design_concept.dart';
import '../../../models/project.dart';
import '../../../models/room_model.dart';
import '../../auth/presentation/auth_providers.dart';

/// Firestore access for projects and their subcollections.
class ProjectRepository {
  ProjectRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  CollectionReference<Map<String, dynamic>> get _projects =>
      _db.collection('projects');

  Stream<List<Project>> watchProjects({int limit = 25}) => _projects
      .where('ownerId', isEqualTo: _uid)
      .orderBy('updatedAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(Project.fromDoc).toList());

  Future<String> createProject(String name, String roomType) async {
    final doc = await _projects.add({
      'ownerId': _uid,
      'name': name,
      'roomType': roomType,
      'status': 'scanned',
      'isFavorite': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> setStatus(String projectId, String status) =>
      _projects.doc(projectId).update(
          {'status': status, 'updatedAt': FieldValue.serverTimestamp()});

  Future<void> toggleFavorite(String projectId, bool value) =>
      _projects.doc(projectId).update({'isFavorite': value});

  // ---- rooms -----------------------------------------------------------

  Future<void> saveRoom(RoomModel room) => _projects
      .doc(room.projectId)
      .collection('rooms')
      .doc(room.id)
      .set({...room.toJson(), 'updatedAt': FieldValue.serverTimestamp()});

  Stream<RoomModel?> watchLatestRoom(String projectId) => _projects
      .doc(projectId)
      .collection('rooms')
      .orderBy('version', descending: true)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty
          ? null
          : RoomModel.fromJson(s.docs.first.id, projectId, s.docs.first.data()));

  // ---- analyses / designs ----------------------------------------------

  Future<void> saveAnalysis(String projectId, AnalysisResult a, int roomVersion) =>
      _projects.doc(projectId).collection('analyses').add({
        ...a.toJson(),
        'roomVersion': roomVersion,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Stream<AnalysisResult?> watchLatestAnalysis(String projectId) => _projects
      .doc(projectId)
      .collection('analyses')
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty
          ? null
          : AnalysisResult.fromJson(s.docs.first.data()));

  Future<void> saveDesign(String projectId, DesignConcept d) =>
      _projects.doc(projectId).collection('designs').add(
          {...d.toJson(), 'createdAt': FieldValue.serverTimestamp()});

  Stream<List<DesignConcept>> watchDesigns(String projectId) => _projects
      .doc(projectId)
      .collection('designs')
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map((s) => s.docs.map((d) => DesignConcept.fromJson(d.data())).toList());
}

final projectRepositoryProvider = Provider<ProjectRepository?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ProjectRepository(FirebaseFirestore.instance, user.uid);
});

final projectsProvider = StreamProvider<List<Project>>((ref) {
  final repo = ref.watch(projectRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchProjects();
});

final latestRoomProvider =
    StreamProvider.family<RoomModel?, String>((ref, projectId) {
  final repo = ref.watch(projectRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchLatestRoom(projectId);
});

final latestAnalysisProvider =
    StreamProvider.family<AnalysisResult?, String>((ref, projectId) {
  final repo = ref.watch(projectRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchLatestAnalysis(projectId);
});

final designsProvider =
    StreamProvider.family<List<DesignConcept>, String>((ref, projectId) {
  final repo = ref.watch(projectRepositoryProvider);
  if (repo == null) return const Stream.empty();
  return repo.watchDesigns(projectId);
});
