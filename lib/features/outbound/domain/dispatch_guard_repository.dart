abstract class DispatchGuardRepository {
  Future<bool> tryReserve({
    required String requestId,
    required String conversationId,
  });

  Future<void> markStatus({required String requestId, required String status});

  Future<String?> getStatus(String requestId);

  Future<int> recoverStuckSending({required Duration olderThan});
}
