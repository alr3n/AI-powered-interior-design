import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../models/room_model.dart';
import '../../../services/gemini_client.dart';
import '../../projects/data/project_repository.dart';
import '../domain/scan_state.dart';

/// Drives the guided capture flow and the extract→save pipeline.
class ScanController extends AutoDisposeNotifier<ScanSession> {
  @override
  ScanSession build() => const ScanSession();

  void addShot(String filePath) {
    if (state.isComplete) return;
    state = state.copyWith(
      shots: [...state.shots, CapturedShot(target: state.currentTarget, filePath: filePath)],
      currentIndex: state.currentIndex + 1,
    );
  }

  void retakeLast() {
    if (state.shots.isEmpty) return;
    // Jump back to the removed shot's own target — indexes are not 1:1 with
    // shots once windows/doors have been skipped.
    final last = state.shots.last;
    state = state.copyWith(
      shots: state.shots.sublist(0, state.shots.length - 1),
      currentIndex: ScanTarget.values.indexOf(last.target),
    );
  }

  void skipCurrent() {
    // Windows/doors may not exist in every room.
    if (state.currentTarget == ScanTarget.windows ||
        state.currentTarget == ScanTarget.doors) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

  /// Forget previously entered dimensions (the user switched to AI estimates).
  void clearDimensions() =>
      state = state.copyWith(clearManualDimensions: true);

  void setDimensions(double lengthM, double widthM, double heightM) {
    state = state.copyWith(manualDimensions: {
      'lengthM': lengthM,
      'widthM': widthM,
      'heightM': heightM,
    });
  }
}

final scanControllerProvider =
    AutoDisposeNotifierProvider<ScanController, ScanSession>(ScanController.new);

/// Submits the scan: compress → base64 → extract-room function → RoomModel →
/// Postgres, with the photos copied to Supabase Storage. Returns the new
/// project id.
class ScanSubmitController extends AutoDisposeAsyncNotifier<String?> {
  @override
  Future<String?> build() async => null;

  Future<void> submit({required String projectName, required String roomType}) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final session = ref.read(scanControllerProvider);
      final repo = ref.read(projectRepositoryProvider);
      if (repo == null) throw const AuthFailure();
      if (session.shots.isEmpty) {
        throw const ValidationFailure('Capture at least the walls and floor first.');
      }

      // Compress + encode (capped at maxScanShots to bound payload size).
      final images = <Map<String, String>>[];
      final photoBytes = <String, Uint8List>{}; // target name -> jpeg
      for (final shot in session.shots.take(AppConstants.maxScanShots)) {
        final bytes = await FlutterImageCompress.compressWithFile(
          shot.filePath,
          minWidth: AppConstants.maxImageDimension,
          minHeight: AppConstants.maxImageDimension,
          quality: AppConstants.jpegQuality,
        );
        if (bytes == null) continue;
        photoBytes[shot.target.name] = bytes;
        images.add({
          'base64': base64Encode(bytes),
          'mimeType': 'image/jpeg',
          'target': shot.target.name,
        });
      }
      if (images.isEmpty) throw const ValidationFailure('Photos could not be read.');

      final gemini = ref.read(geminiClientProvider);
      final extraction = await gemini.extractRoom(
        images: images,
        arDimensions: session.manualDimensions,
      );

      final String projectId;
      try {
        projectId = await repo.createProject(projectName, roomType);
      } catch (e) {
        throw mapError(e);
      }

      final dims = session.manualDimensions != null
          ? RoomDimensions(
              lengthM: session.manualDimensions!['lengthM']!,
              widthM: session.manualDimensions!['widthM']!,
              heightM: session.manualDimensions!['heightM']!,
            )
          : RoomDimensions.fromJson(
              (extraction['dimensionEstimate'] as Map<String, dynamic>?) ??
                  {'lengthM': 3, 'widthM': 3, 'heightM': 2.4});

      final room = RoomModel(
        id: 'v1',
        projectId: projectId,
        version: 1,
        roomType: extraction['roomType'] as String? ?? roomType,
        dimensionSource: session.manualDimensions != null
            ? DimensionSource.manual
            : DimensionSource.ai,
        dimensions: dims,
        openings: ((extraction['openings'] as List<dynamic>?) ?? [])
            .map((o) => Opening.fromJson(o as Map<String, dynamic>))
            .toList(),
        furniture: ((extraction['furniture'] as List<dynamic>?) ?? [])
            .map((f) => FurnitureItem.fromJson(f as Map<String, dynamic>))
            .toList(),
        materials: ((extraction['materials'] as List<dynamic>?) ?? [])
            .map((m) => MaterialDetection.fromJson(m as Map<String, dynamic>))
            .toList(),
        lightingObservation: extraction['lightingObservation'] as String?,
        assumptions: ((extraction['assumptions'] as List<dynamic>?) ?? [])
            .map((e) => e.toString())
            .toList(),
        // Filled in below once the photos are in Storage.
        photoPaths: const [],
      );

      try {
        // Keep the originals in Storage; local temp paths die with the cache.
        final paths = <String>[];
        for (final entry in photoBytes.entries) {
          final path =
              await repo.uploadScanPhoto(projectId, entry.key, entry.value);
          if (path != null) paths.add(path);
        }
        await repo.saveRoom(room.copyWith(photoPaths: paths));
      } catch (e) {
        // Don't leave an empty project behind if the room could not be saved.
        try {
          await repo.deleteProject(projectId);
        } catch (_) {}
        throw mapError(e);
      }

      // Best-effort local cleanup of temp captures.
      for (final shot in session.shots) {
        try {
          await File(shot.filePath).delete();
        } catch (_) {}
      }
      return projectId;
    });
  }
}

final scanSubmitProvider =
    AutoDisposeAsyncNotifierProvider<ScanSubmitController, String?>(
        ScanSubmitController.new);
