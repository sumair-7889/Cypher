import 'agent_core.dart';
import 'provider/provider_manager.dart';
import '../models/agent_action.dart';
import 'dart:async';

/// Execution Pipeline Manager
/// Orchestrates the flow from user input through Agent Core to device execution
class ExecutionPipeline {
  static final ExecutionPipeline _instance = ExecutionPipeline._internal();
  
  factory ExecutionPipeline() {
    return _instance;
  }
  
  ExecutionPipeline._internal();

  late AgentCore _agentCore;
  late ProviderManager _providerManager;
  
  final List<ExecutionEvent> _eventLog = [];
  final StreamController<ExecutionEvent> _eventStream = StreamController.broadcast();

  Future<void> init() async {
    _agentCore = AgentCore();
    await _agentCore.init();
    
    _providerManager = ProviderManager();
    await _providerManager.init();
  }

  /// Execute a user command through the complete pipeline
  Future<ExecutionResult> executeCommand(
    String userInput, {
    void Function(ExecutionEvent)? onEvent,
  }) async {
    try {
      // Step 1: Interpret user intent
      _logEvent(
        'INTERPRET',
        'Analyzing user input',
        userInput,
      );
      final action = await _agentCore.interpretIntent(userInput);
      if (action == null) {
        return ExecutionResult(
          success: false,
          errorMessage: 'Could not understand the request',
        );
      }

      // Step 2: Check safety and permissions
      _logEvent('SAFETY_CHECK', 'Verifying permissions and constraints', action.id);
      final safetyCheck = await _agentCore.checkSafety(action);
      if (safetyCheck['permitted'] == false) {
        return ExecutionResult(
          success: false,
          errorMessage: 'Action not permitted',
        );
      }

      // Step 3: Route to appropriate executor
      _logEvent('ROUTE', 'Routing action to executor', action.action);
      final routeResult = await _agentCore.routeAction(action);
      _logEvent('ROUTING_RESULT', routeResult, action.id);

      // Step 4: Verify completion
      _logEvent('VERIFY', 'Verifying action completion', action.id);
      final verified = await _agentCore.verifyCompletion(action, routeResult);

      return ExecutionResult(
        success: verified,
        actionId: action.id,
        result: routeResult,
      );
    } catch (e) {
      _logEvent('ERROR', 'Execution pipeline error', e.toString());
      return ExecutionResult(
        success: false,
        errorMessage: 'Execution error: ${e.toString()}',
      );
    }
  }

  /// Get the active AI provider
  String getActiveProviderName() {
    final provider = _providerManager.getActiveProvider();
    return provider?.name ?? 'Not configured';
  }

  /// Switch to a different provider
  Future<void> switchProvider(String providerId) async {
    await _providerManager.setActiveProvider(providerId);
    _logEvent('PROVIDER_SWITCH', 'Switched to provider', providerId);
  }

  /// Get all available providers
  Map<String, String> getAvailableProviders() {
    return _providerManager
        .getAllProviders()
        .map((key, provider) => MapEntry(key, provider.name));
  }

  void _logEvent(String type, String message, String details) {
    final event = ExecutionEvent(
      timestamp: DateTime.now(),
      type: type,
      message: message,
      details: details,
    );
    _eventLog.add(event);
    _eventStream.add(event);
  }

  Stream<ExecutionEvent> get eventStream => _eventStream.stream;

  List<ExecutionEvent> getEventLog() => List.unmodifiable(_eventLog);

  void clearEventLog() => _eventLog.clear();

  void dispose() {
    _eventStream.close();
  }
}

/// Represents a single event in the execution pipeline
class ExecutionEvent {
  final DateTime timestamp;
  final String type; // INTERPRET, PLAN, ROUTE, EXECUTE, VERIFY, RECOVER, ERROR
  final String message;
  final String details;

  ExecutionEvent({
    required this.timestamp,
    required this.type,
    required this.message,
    required this.details,
  });

  @override
  String toString() => '$type: $message ($details)';
}

/// Result of a complete execution
class ExecutionResult {
  final bool success;
  final String? actionId;
  final String? result;
  final String? errorMessage;
  final DateTime timestamp;
  final int? tokensUsed;

  ExecutionResult({
    required this.success,
    this.actionId,
    this.result,
    this.errorMessage,
    this.timestamp = const DateTime.now(),
    this.tokensUsed,
  });

  @override
  String toString() => success
      ? 'SUCCESS: $result'
      : 'FAILED: $errorMessage';
}
