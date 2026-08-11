import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final List<int> _pin = [];
  bool _isRegistering = false;
  String _firstPinAttempt = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final isRegistered = await ref.read(authServiceProvider).isUserRegistered();
    setState(() {
      _isRegistering = !isRegistered;
    });

    if (isRegistered) {
      // Auto trigger biometrics
      _triggerBiometrics();
    }
  }

  Future<void> _triggerBiometrics() async {
    final success = await ref.read(authStateProvider.notifier).loginWithBiometrics();
    if (success) {
      // Riverpod state listener will handle navigation or showing Dashboard
    }
  }

  void _onKeyPress(int number) {
    if (_pin.length < 4) {
      setState(() {
        _pin.add(number);
        _errorMessage = '';
      });
    }

    if (_pin.length == 4) {
      _processPin();
    }
  }

  void _onDelete() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin.removeLast();
      });
    }
  }

  Future<void> _processPin() async {
    final enteredPin = _pin.join();
    setState(() => _pin.clear());

    if (_isRegistering) {
      if (_firstPinAttempt.isEmpty) {
        // First step of registration
        setState(() {
          _firstPinAttempt = enteredPin;
        });
      } else {
        // Second step of registration: confirmation
        if (_firstPinAttempt == enteredPin) {
          final success = await ref.read(authStateProvider.notifier).register(enteredPin);
          if (!success) {
            setState(() {
              _firstPinAttempt = '';
              _errorMessage = 'Error al registrar el PIN. Reintenta.';
            });
          }
        } else {
          setState(() {
            _firstPinAttempt = '';
            _errorMessage = 'Los PINs no coinciden. Comienza de nuevo.';
          });
        }
      }
    } else {
      // Login attempt
      final success = await ref.read(authStateProvider.notifier).loginWithPin(enteredPin);
      if (!success) {
        setState(() {
          _errorMessage = 'PIN incorrecto. Reintenta.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppTheme.backgroundDark, AppTheme.surfaceDark]
                : [AppTheme.backgroundLight, Colors.grey[200]!],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // Top Icon / Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryDark.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: AppTheme.primaryDark,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _isRegistering
                    ? (_firstPinAttempt.isEmpty
                        ? 'Crea tu PIN de Acceso'
                        : 'Confirma tu PIN')
                    : 'Introduce tu PIN',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                _isRegistering
                    ? 'Define un código numérico de 4 dígitos'
                    : 'Acceso seguro a tu bóveda personal',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              
              // PIN Dots Display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: index < _pin.length
                          ? AppTheme.primaryDark
                          : AppTheme.textSecondaryDark.withOpacity(0.3),
                    ),
                  );
                }),
              ),
              
              if (_errorMessage.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w500),
                ),
              ],
              
              const Spacer(),
              
              // Custom PIN Keyboard
              _buildKeyboard(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyboard() {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var j = 1; j <= 3; j++) _buildKeyButton(i * 3 + j),
            ],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Left Button: Biometrics (only if not registering)
            _isRegistering
                ? const SizedBox(width: 80, height: 80)
                : _buildIconButton(Icons.fingerprint, _triggerBiometrics),
            _buildKeyButton(0),
            // Right Button: Backspace
            _buildIconButton(Icons.backspace_outlined, _onDelete),
          ],
        ),
      ],
    );
  }

  Widget _buildKeyButton(int val) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: 80,
      height: 80,
      child: OutlinedButton(
        onPressed: () => _onKeyPress(val),
        style: OutlinedButton.styleFrom(
          shape: const CircleBorder(),
          side: BorderSide(
            color: AppTheme.primaryDark.withOpacity(0.15),
          ),
          backgroundColor: AppTheme.surfaceDark.withOpacity(0.3),
        ),
        child: Text(
          '$val',
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback action) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      width: 80,
      height: 80,
      child: IconButton(
        onPressed: action,
        icon: Icon(icon, size: 32, color: AppTheme.primaryDark),
        style: IconButton.styleFrom(
          backgroundColor: AppTheme.primaryDark.withOpacity(0.1),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}
