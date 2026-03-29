import '../domain/channel_adapter.dart';

class ChannelManager {
  ChannelManager({
    required Map<ChannelType, ChannelAdapter> adapters,
    required ChannelType initialChannel,
  }) : _adapters = Map<ChannelType, ChannelAdapter>.from(adapters),
       _activeChannel = initialChannel {
    if (!_adapters.containsKey(initialChannel)) {
      throw ArgumentError('initialChannel is not configured: $initialChannel');
    }
  }

  final Map<ChannelType, ChannelAdapter> _adapters;
  ChannelType _activeChannel;

  ChannelType get activeChannel => _activeChannel;

  List<ChannelAdapter> get adapters => _adapters.values.toList(growable: false);

  ChannelAdapter? adapterOf(ChannelType type) => _adapters[type];

  ChannelAdapter get activeAdapter => _adapters[_activeChannel]!;

  Future<void> switchTo(ChannelType channel) async {
    if (!_adapters.containsKey(channel)) {
      throw ArgumentError('channel adapter missing: $channel');
    }
    _activeChannel = channel;
  }

  void updateAdapter(ChannelAdapter adapter) {
    _adapters[adapter.channelType] = adapter;
  }

  Future<ChannelHealthStatus> checkActiveHealth() {
    return activeAdapter.healthCheck();
  }
}
