import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/errors/failures.dart';
import '../models/analysis_result.dart';
import '../models/design_concept.dart';
import '../models/room_model.dart';

/// Client wrapper for the Supabase Edge Function AI endpoints
/// (`supabase/functions/*`). The Gemini key never touches the device — see
/// docs/01-ARCHITECTURE.md §1.
class GeminiClient {
  GeminiClient(this._client);
  final SupabaseClient _client;

  Future<Map<String, dynamic>> extractRoom({
    required List<Map<String, String>> images, // {base64, mimeType, target}
    Map<String, dynamic>? arDimensions,
  }) =>
      _call('extract-room', {
        'images': images,
        if (arDimensions != null) 'arDimensions': arDimensions,
      });

  Future<AnalysisResult> analyzeRoom(RoomModel room,
      {Map<String, dynamic>? profile, String region = 'PH'}) async {
    final data = await _call('analyze-room', {
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
    final data = await _call('generate-design', {
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
    final data = await _call('chat-assistant', {
      'message': message,
      'history': history,
      if (room != null) 'room': room.toJson(),
    });
    return data['reply'] as String? ?? '';
  }

  Future<Map<String, dynamic>> _call(
      String name, Map<String, dynamic> payload) async {
    try {
      final response = await _client.functions
          .invoke(name, body: payload)
          .timeout(const Duration(seconds: 120));
      final data = _deepConvert(response.data);
      if (data is! Map<String, dynamic>) throw const AiFailure();
      return data;
    } catch (e) {
      throw mapError(e);
    }
  }

  /// Normalizes decoded JSON to `Map<String, dynamic>` / `List<dynamic>` so
  /// the model factories' `as Map<String, dynamic>` casts always hold.
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

final geminiClientProvider =
    Provider<GeminiClient>((ref) => GeminiClient(Supabase.instance.client));
