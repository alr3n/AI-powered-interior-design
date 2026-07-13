import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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
    state = state.copyWith(
      shots: state.shots.sublist(0, state.shots.length - 1),
      currentIndex: math.max(0, state.currentIndex - 1),
    );
  }

  void skipCurrent() {
    // Windows/doors may not exist in every room.
    if (state.currentTarget == ScanTarget.windows ||
        state.currentTarget == ScanTarget.doors) {
      state = state.copyWith(currentIndex: state.currentIndex + 1);
    }
  }

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

/// Submits the scan: compress → base64 → extractRoom function → RoomModel →
/// Firestore. Returns the new project id.
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
      for (final shot in session.shots.take(AppConstants.maxScanShots)) {
        final bytes = await FlutterImageCompress.compressWithFile(
          shot.filePath,
          minWidth: AppConstants.maxImageDimension,
          minHeight: AppConstants.maxImageDimension,
          quality: AppConstants.jpegQuality,
        );
        if (bytes == null) continue;
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

      final projectId = await repo.createProject(projectName, roomType);

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
        photoPaths: session.shots.map((s) => s.filePath).toList(),
      );
      await repo.saveRoom(room);

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
