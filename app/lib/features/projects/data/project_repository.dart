import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/analysis_result.dart';
import '../../../models/design_concept.dart';
import '../../../models/project.dart';
import '../../../models/room_model.dart';
import '../../auth/presentation/auth_providers.dart';

/// Supabase (Postgres + Realtime + Storage) access for projects and the
/// rooms / analyses / designs that belong to them. Row Level Security scopes
/// every query to the signed-in user; the `owner_id` filters below only keep
/// the realtime subscriptions narrow.
class ProjectRepository {
  ProjectRepository(this._db, this._uid);

  final SupabaseClient _db;
  final String _uid;

  static const scanBucket = 'scan-photos';

  // ---- projects ----------------------------------------------------------

  Stream<List<Project>> watchProjects({int limit = 25}) => _db
      .from('projects')
      .stream(primaryKey: ['id'])
      .eq('owner_id', _uid)
      .order('updated_at', ascending: false)
      .limit(limit)
      .map((rows) => rows.map(Project.fromRow).toList());

  Stream<Project?> watchProject(String projectId) => _db
      .from('projects')
      .stream(primaryKey: ['id'])
      .eq('id', projectId)
      .map((rows) => rows.isEmpty ? null : Project.fromRow(rows.first));

  Future<String> createProject(String name, String roomType) async {
    final row = await _db
        .from('projects')
        .insert({
          'owner_id': _uid,
          'name': name,
          'room_type': roomType,
          'status': 'scanned',
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<void> setStatus(String projectId, String status) =>
      _db.from('projects').update({'status': status}).eq('id', projectId);

  Future<void> toggleFavorite(String projectId, bool value) =>
      _db.from('projects').update({'is_favorite': value}).eq('id', projectId);

  /// Rooms, analyses and designs are removed by `on delete cascade`.
  Future<void> deleteProject(String projectId) =>
      _db.from('projects').delete().eq('id', projectId);

  // ---- photos ------------------------------------------------------------

  /// Uploads one compressed scan photo and returns its storage path
  /// (`<uid>/<projectId>/scan/<target>.jpg`), or null if the upload failed —
  /// photos are a convenience copy, so a failure must not lose the scan.
  Future<String?> uploadScanPhoto(
      String projectId, String target, Uint8List bytes) async {
    final path = '$_uid/$projectId/scan/$target.jpg';
    try {
      await _db.storage.from(scanBucket).uploadBinary(
            path,
            bytes,
            fileOptions:
                const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      return path;
    } catch (_) {
      return null;
    }
  }

  // ---- rooms -------------------------------------------------------------

  Future<void> saveRoom(RoomModel room) => _db.from('rooms').upsert({
        'project_id': room.projectId,
        'version': room.version,
        'data': room.toJson(),
      }, onConflict: 'project_id,version');

  Stream<RoomModel?> watchLatestRoom(String projectId) => _db
      .from('rooms')
      .stream(primaryKey: ['id'])
      .eq('project_id', projectId)
      .order('version', ascending: false)
      .limit(1)
      .map((rows) => rows.isEmpty
          ? null
          : RoomModel.fromJson(rows.first['id'] as String, projectId,
              Map<String, dynamic>.from(rows.first['data'] as Map)));

  // ---- analyses / designs -----------------------------------------------

  Future<void> saveAnalysis(
          String projectId, AnalysisResult a, int roomVersion) =>
      _db.from('analyses').insert({
        'project_id': projectId,
        'room_version': roomVersion,
        'data': a.toJson(),
      });

  Stream<AnalysisResult?> watchLatestAnalysis(String projectId) => _db
      .from('analyses')
      .stream(primaryKey: ['id'])
      .eq('project_id', projectId)
      .order('created_at', ascending: false)
      .limit(1)
      .map((rows) => rows.isEmpty
          ? null
          : AnalysisResult.fromJson(
              Map<String, dynamic>.from(rows.first['data'] as Map)));

  Future<void> saveDesign(String projectId, DesignConcept d) =>
      _db.from('designs').insert({
        'project_id': projectId,
        'data': d.toJson(),
      });

  Stream<List<DesignConcept>> watchDesigns(String projectId) => _db
      .from('designs')
      .stream(primaryKey: ['id'])
      .eq('project_id', projectId)
      .order('created_at', ascending: false)
      .map((rows) => rows
          .map((r) => DesignConcept.fromJson(
              Map<String, dynamic>.from(r['data'] as Map)))
          .toList());
}

final projectRepositoryProvider = Provider<ProjectRepository?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  return ProjectRepository(Supabase.instance.client, user.uid);
});

// While signed out the repository is null; emit an empty value rather than
// leaving the stream pending so `.future` never hangs.

final projectsProvider = StreamProvider<List<Project>>((ref) {
  final repo = ref.watch(projectRepositoryProvider);
  if (repo == null) return Stream.value(const <Project>[]);
  return repo.watchProjects();
});

final projectProvider =
    StreamProvider.family<Project?, String>((ref, projectId) {
  final repo = ref.watch(projectRepositoryProvider);
  if (repo == null) return Stream.value(null);
  return repo.watchProject(projectId);
});

final latestRoomProvider =
    StreamProvider.family<RoomModel?, String>((ref, projectId) {
  final repo = ref.watch(projectRepositoryProvider);
  if (repo == null) return Stream.value(null);
  return repo.watchLatestRoom(projectId);
});

final latestAnalysisProvider =
    StreamProvider.family<AnalysisResult?, String>((ref, projectId) {
  final repo = ref.watch(projectRepositoryProvider);
  if (repo == null) return Stream.value(null);
  return repo.watchLatestAnalysis(projectId);
});

final designsProvider =
    StreamProvider.family<List<DesignConcept>, String>((ref, projectId) {
  final repo = ref.watch(projectRepositoryProvider);
  if (repo == null) return Stream.value(const <DesignConcept>[]);
  return repo.watchDesigns(projectId);
});
