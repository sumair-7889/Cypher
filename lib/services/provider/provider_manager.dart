import 'package:shared_preferences/shared_preferences.dart';
import '../secure_credential_manager.dart';
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
  late SecureCredentialManager _credentialManager;
  Map<String, AIProvider> _providers = {};
  String _activeProvider = 'custom';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _credentialManager = SecureCredentialManager();
    await _credentialManager.init();
    _activeProvider = _prefs.getString('active_provider') ?? 'custom';
    await _loadProviders();
  }

  Future<void> _loadProviders() async {
    _providers.clear();
    
    // Load custom provider
    final customApiKey = await _credentialManager.getCustomApiKey();
    final customBaseUrl = _credentialManager.getCustomBaseUrl();
    final customModel = _credentialManager.getCustomModel();
    
    if (customApiKey != null && customApiKey.isNotEmpty && customBaseUrl.isNotEmpty) {
      _providers['custom'] = OpenAICompatibleProvider(
        name: 'Custom',
        baseUrl: customBaseUrl,
        apiKey: customApiKey,
        model: customModel,
      );
    }

    // Load NVIDIA if configured
    final nvidiaKey = await _credentialManager.getNvidiaApiKey();
    if (nvidiaKey != null && nvidiaKey.isNotEmpty) {
      _providers['nvidia'] = OpenAICompatibleProvider(
        name: 'NVIDIA',
        baseUrl: 'https://integrate.api.nvidia.com/v1',
        apiKey: nvidiaKey,
        model: _credentialManager.getNvidiaModel(),
      );
    }
  }

  AIProvider? getActiveProvider() {
    return _providers[_activeProvider];
  }

  Future<void> setActiveProvider(String providerId) async {
    if (_providers.containsKey(providerId)) {
      _activeProvider = providerId;
      await _prefs.setString('active_provider', providerId);
    }
  }

  /// Add or update a provider
  Future<void> addOrUpdateProvider(String providerId, String name, String baseUrl, String apiKey, String model) async {
    if (providerId == 'nvidia') {
      await _credentialManager.saveNvidiaConfig(apiKey: apiKey, model: model);
    } else if (providerId == 'custom') {
      await _credentialManager.saveCustomProviderConfig(
        apiKey: apiKey,
        baseUrl: baseUrl,
        model: model,
      );
    }
    await _loadProviders();
  }

  /// Test a provider connection
  Future<bool> testProvider(String providerId) async {
    final provider = _providers[providerId];
    if (provider == null) return false;
    return await provider.testConnection();
  }

  /// Get all configured providers
  Map<String, AIProvider> getAllProviders() {
    return Map.unmodifiable(_providers);
  }

  /// Get provider details (without API keys)
  Map<String, Map<String, String>> getProviderDetails() {
    return _credentialManager.getSavedProviders();
  }

  /// Delete a provider
  Future<void> deleteProvider(String providerId) async {
    await _credentialManager.clearProviderCredentials(providerId);
    _providers.remove(providerId);
    
    // If deleted provider was active, switch to another
    if (_activeProvider == providerId && _providers.isNotEmpty) {
      _activeProvider = _providers.keys.first;
      await _prefs.setString('active_provider', _activeProvider);
    }
  }

  /// Get list of model names for a provider
  Future<List<String>> fetchModelsForProvider(String providerId) async {
    final provider = _providers[providerId];
    if (provider == null) return [];
    return await provider.fetchAvailableModels();
  }
}
