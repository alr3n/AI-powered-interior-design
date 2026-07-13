import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/errors/failures.dart';
import '../models/analysis_result.dart';
import '../models/design_concept.dart';
import '../models/room_model.dart';

/// Client wrapper for the Cloud Function AI endpoints. The Gemini key never
/// touches the device — see docs/01-ARCHITECTURE.md §1.
class GeminiClient {
  GeminiClient(this._functions);
  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> extractRoom({
    required List<Map<String, String>> images, // {base64, mimeType, target}
    Map<String, dynamic>? arDimensions,
  }) =>
      _call('extractRoom', {
        'images': images,
        if (arDimensions != null) 'arDimensions': arDimensions,
      });

  Future<AnalysisResult> analyzeRoom(RoomModel room,
      {Map<String, dynamic>? profile, String region = 'PH'}) async {
    final data = await _call('analyzeRoom', {
      'room': room.toJson(),
      if (profile != null) 'profile': profile,
      'region': region,
    });
    return AnalysisResult.fromJson(data);
  }

  Future<DesignConcept> generateDesign(RoomModel room,
      {required String style,
      String tier = 'medium',
      String region = 'PH'}) async {
    final data = await _call('generateDesign', {
      'room': room.toJson(),
      'style': style,
      'tier': tier,
      'region': region,
    });
    return DesignConcept.fromJson(data);
  }

  Future<String> chat({
    required String message,
    required List<Map<String, String>> history, // {role, text}
    RoomModel? room,
  }) async {
    final data = await _call('chatAssistant', {
      'message': message,
      'history': history,
      if (room != null) 'room': room.toJson(),
    });
    return data['reply'] as String? ?? '';
  }

  Future<Map<String, dynamic>> _call(
      String name, Map<String, dynamic> payload) async {
    try {
      final result = await _functions
          .httpsCallable(name,
              options: HttpsCallableOptions(
                  timeout: const Duration(seconds: 120)))
          .call<dynamic>(payload);
      return _deepConvert(result.data) as Map<String, dynamic>;
    } on FirebaseFunctionsException catch (e) {
      throw mapFunctionsError('${e.code} ${e.message}');
    } catch (e) {
      throw mapFunctionsError(e);
    }
  }

  /// Mobile platform channels decode nested JSON as `Map<Object?, Object?>` /
  /// `List<Object?>`, not the `Map<String, dynamic>` the model factories
  /// expect — recursively normalize before any `as Map<String, dynamic>` cast.
  dynamic _deepConvert(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _deepConvert(v)));
    }
    if (value is List) {
      return value.map(_deepConvert).toList();
    }
    return value;
  }
}

final geminiClientProvider = Provider<GeminiClient>(
    (ref) => GeminiClient(FirebaseFunctions.instance));
