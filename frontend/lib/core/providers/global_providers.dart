import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/db_helper.dart';
import '../security/auth_service.dart';
import '../security/biometric_service.dart';
import '../security/encryption_service.dart';
import '../security/secure_storage_service.dart';
import '../../features/transactions/data/local_transaction_repository.dart';
import '../../features/password_manager/data/local_password_repository.dart';
import '../network/api_client.dart';
import '../network/sync_service.dart';

final secureStorageProvider = Provider<SecureStorageService>((ref) {
  return SecureStorageService();
});

final encryptionProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

final biometricProvider = Provider<BiometricService>((ref) {
  return BiometricService();
});

final dbHelperProvider = Provider<DbHelper>((ref) {
  return DbHelper();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    secureStorage: ref.watch(secureStorageProvider),
    encryptionService: ref.watch(encryptionProvider),
    biometricService: ref.watch(biometricProvider),
    dbHelper: ref.watch(dbHelperProvider),
    apiClient: ref.watch(apiClientProvider),
  );
});

// A state notifier provider to track local authentication state (logged in or logged out)
final authStateProvider = StateNotifierProvider<AuthStateNotifier, bool>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthStateNotifier(authService);
});

class AuthStateNotifier extends StateNotifier<bool> {
  final AuthService _authService;

  AuthStateNotifier(this._authService) : super(false) {
    checkRegistration();
  }

  Future<void> checkRegistration() async {
    // If not registered, state is false. If registered, we expect login.
  }

  Future<bool> register({
    required String username,
    required String masterPassword,
    required String pin,
  }) async {
    final success = await _authService.registerUser(
      username: username,
      masterPassword: masterPassword,
      pin: pin,
    );
    if (success) {
      state = true;
    }
    return success;
  }

  Future<bool> loginWithPassword({
    required String username,
    required String masterPassword,
  }) async {
    final success = await _authService.loginWithPassword(username, masterPassword);
    if (success) {
      state = true;
    }
    return success;
  }

  Future<bool> loginWithPin(String pin) async {
    final success = await _authService.loginWithPin(pin);
    if (success) {
      state = true;
    }
    return success;
  }

  Future<bool> loginWithBiometrics() async {
    final success = await _authService.loginWithBiometrics();
    if (success) {
      state = true;
    }
    return success;
  }

  Future<void> logout() async {
    await _authService.logout();
    state = false;
  }
}

final localTransactionRepositoryProvider = Provider<LocalTransactionRepository>((ref) {
  return LocalTransactionRepository(ref.watch(dbHelperProvider));
});

final localPasswordRepositoryProvider = Provider<LocalPasswordRepository>((ref) {
  return LocalPasswordRepository(
    dbHelper: ref.watch(dbHelperProvider),
    encryptionService: ref.watch(encryptionProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

final dashboardSummaryProvider = FutureProvider<Map<String, double>>((ref) async {
  // Try to load, if DB not initialized yet return zero values
  try {
    return await ref.watch(localTransactionRepositoryProvider).getDashboardSummary();
  } catch (_) {
    return {'totalBalance': 0.0, 'income': 0.0, 'expense': 0.0};
  }
});

final recentTransactionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    return await ref.watch(localTransactionRepositoryProvider).getTransactions(limit: 10);
  } catch (_) {
    return [];
  }
});

final accountsListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    return await ref.watch(localTransactionRepositoryProvider).getAccounts();
  } catch (_) {
    return [];
  }
});

final decryptedCredentialsProvider = FutureProvider<List<Map<String, String>>>((ref) async {
  try {
    return await ref.watch(localPasswordRepositoryProvider).getCredentials();
  } catch (_) {
    return [];
  }
});

final categorySummaryProvider = FutureProvider<Map<String, double>>((ref) async {
  try {
    return await ref.watch(localTransactionRepositoryProvider).getCategorySummary();
  } catch (_) {
    return {};
  }
});

final apiClientProvider = Provider<ApiClient>((ref) {
  // Use http://10.0.2.2:5227 for Android Emulator connection to PC, or http://localhost:5227 for iOS/Web
  const String localUrl = 'http://10.0.2.2:5227';
  const String productionUrl = 'https://my-finances-9kah.onrender.com';
  return ApiClient(
    baseUrl: productionUrl, // Using production URL by default
    secureStorage: ref.watch(secureStorageProvider),
  );
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    apiClient: ref.watch(apiClientProvider),
    dbHelper: ref.watch(dbHelperProvider),
  );
});
