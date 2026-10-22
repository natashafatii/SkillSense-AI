import 'package:dio/dio.dart';
import '../models/application.dart';
import '../models/question_set.dart';
import 'api_client.dart';
import 'api_exception.dart';

class QuestionPreparationService {
  QuestionPreparationService({Dio? client}) : _client = client;
  final Dio? _client;
  Future<QuestionSet> read(
    String applicationId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final dio = _client ?? await ApiClient.getInstance();
      return QuestionSet.fromJson(
        Map<String, dynamic>.from(
          (await dio.get(
                '/applications/$applicationId/question-set/',
                cancelToken: cancelToken,
              )).data
              as Map,
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<QuestionSet> prepare(Application application) async {
    if (!application.canPrepareQuestions) {
      throw StateError('Application is not eligible for preparation.');
    }
    try {
      final dio = _client ?? await ApiClient.getInstance();
      return QuestionSet.fromJson(
        Map<String, dynamic>.from(
          (await dio.post(
                '/applications/${application.id}/question-set/',
                data: {'expected_version': application.version},
              )).data
              as Map,
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<QuestionSet> command(
    QuestionSet set,
    String operation, [
    Map<String, dynamic> fields = const {},
  ]) async {
    if (set.id == null ||
        set.revision == null ||
        set.legacy ||
        set.frozenAt != null) {
      throw StateError('This question set is read-only.');
    }
    if (!const {
      'add',
      'edit',
      'remove',
      'reorder',
      'approve',
      'retry',
      'regenerate',
    }.contains(operation)) {
      throw ArgumentError('Unknown question command.');
    }
    final editable = set.editable;
    if ((const {
              'add',
              'edit',
              'remove',
              'reorder',
              'approve',
            }.contains(operation) &&
            !editable) ||
        (operation == 'approve' && set.questions.isEmpty) ||
        (operation == 'retry' && set.generationStatus != 'FAILED') ||
        (const {'retry', 'regenerate'}.contains(operation) &&
            set.approvedAt != null) ||
        (operation == 'regenerate' &&
            !const {
              'READY',
              'FALLBACK',
              'FAILED',
            }.contains(set.generationStatus))) {
      throw StateError(
        'This command is not available for the current generation state.',
      );
    }
    if (operation == 'add' && set.questions.length >= 100) {
      throw StateError('Maximum 100 active questions.');
    }
    if (const {'edit', 'remove'}.contains(operation) &&
        !set.questions.any((q) => q.id == fields['id'])) {
      throw ArgumentError('Review the current question identity.');
    }
    if (fields.containsKey('text') &&
        (fields['text'] is! String ||
            (fields['text'] as String).trim().isEmpty ||
            (fields['text'] as String).length > 10000)) {
      throw ArgumentError('Question text must contain 1–10,000 characters.');
    }
    if (fields.containsKey('category') &&
        !const {
          'TECHNICAL',
          'BEHAVIORAL',
          'SITUATIONAL',
        }.contains(fields['category'])) {
      throw ArgumentError('Choose a supported category.');
    }
    if (operation == 'reorder') {
      final ids = (fields['ids'] as List).cast<String>();
      if (ids.length != set.questions.length ||
          ids.toSet().length != ids.length ||
          ids
              .toSet()
              .difference(set.questions.map((q) => q.id).toSet())
              .isNotEmpty) {
        throw ArgumentError('Reorder must contain every active question once.');
      }
    }
    try {
      final dio = _client ?? await ApiClient.getInstance();
      return QuestionSet.fromJson(
        Map<String, dynamic>.from(
          (await dio.patch(
                '/question-sets/${set.id}/',
                data: {
                  ...fields,
                  'operation': operation,
                  'expected_revision': set.revision!.value,
                },
              )).data
              as Map,
        ),
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }
}
