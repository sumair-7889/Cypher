import 'package:shared_preferences/shared_preferences.dart';
import 'ai_provider.dart';
import 'openai_compatible_provider.dart';

/// Manages multiple AI providers and handles provider switching
class ProviderManager {
  static final ProviderManager _instance = ProviderManager._internal();
  
  factory ProviderManager() {
    return _instance;
  }
  
  ProviderManager._internal();

  late SharedPreferences _prefs;
  Map<String, AIProvider> _providers = {};
  String _activeProvider = 'custom';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _activeProvider = _prefs.getString('active_provider') ?? 'custom';
    _loadProviders();
  }

  void _loadProviders() {
    // Load stored provider configurations
    final customBaseUrl = _prefs.getString('base_url') ?? '';
    final customApiKey = _prefs.getString('api_key') ?? '';
    final customModel = _prefs.getString('model') ?? 'deepseek-chat';

    if (customBaseUrl.isNotEmpty && customApiKey.isNotEmpty) {
      _providers['custom'] = OpenAICompatibleProvider(
        name: 'Custom',
        baseUrl: customBaseUrl,
        apiKey: customApiKey,
        model: customModel,
      );
    }

    // Load NVIDIA if configured
    final nvidiaKey = _prefs.getString('nvidia_api_key');
    if (nvidiaKey != null && nvidiaKey.isNotEmpty) {
      _providers['nvidia'] = OpenAICompatibleProvider(
        name: 'NVIDIA',
        baseUrl: 'https://integrate.api.nvidia.com/v1',
        apiKey: nvidiaKey,
        model: _prefs.getString('nvidia_model') ?? 'z-ai/glm-5.2',
      );
    }
  }

  AIProvider? getActiveProvider() {
    return _providers[_activeProvider];
  }

  Future<void> setActiveProvider(String providerId) async {
    _activeProvider = providerId;
    await _prefs.setString('active_provider', providerId);
  }

  void addProvider(String id, AIProvider provider) {
    _providers[id] = provider;
  }

  Map<String, AIProvider> getAllProviders() {
    return Map.unmodifiable(_providers);
  }
}
