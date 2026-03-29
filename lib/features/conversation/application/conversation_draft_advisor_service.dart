import '../../../core/models/message.dart';
import '../../ai/application/ai_draft_service.dart';
import '../../ai/domain/ai_draft.dart';
import 'intent_classifier_service.dart';
import 'response_cadence_policy.dart';

class ConversationDraftAdvice {
  const ConversationDraftAdvice({
    required this.classification,
    required this.cadenceDecision,
    this.draft,
  });

  final IntentClassification classification;
  final CadenceDecision cadenceDecision;
  final AiDraftResult? draft;
}

class ConversationDraftAdvisorService {
  const ConversationDraftAdvisorService({
    required AiDraftService aiDraftService,
    required IntentClassifierService intentClassifier,
    required ResponseCadencePolicy cadencePolicy,
  }) : _aiDraftService = aiDraftService,
       _intentClassifier = intentClassifier,
       _cadencePolicy = cadencePolicy;

  final AiDraftService _aiDraftService;
  final IntentClassifierService _intentClassifier;
  final ResponseCadencePolicy _cadencePolicy;

  Future<ConversationDraftAdvice> buildAdvice({
    required String customerName,
    required String goalStage,
    required List<Message> messages,
  }) async {
    final classification = _intentClassifier.classify(messages);
    final cadenceDecision = _cadencePolicy.evaluate(
      classification: classification,
      messages: messages,
    );

    if (cadenceDecision.action == CadenceAction.suggestSkip) {
      return ConversationDraftAdvice(
        classification: classification,
        cadenceDecision: cadenceDecision,
      );
    }

    final draft = await _aiDraftService.generateDraft(
      customerName: customerName,
      goalStage: goalStage,
      messages: messages,
    );

    return ConversationDraftAdvice(
      classification: classification,
      cadenceDecision: cadenceDecision,
      draft: draft,
    );
  }
}
