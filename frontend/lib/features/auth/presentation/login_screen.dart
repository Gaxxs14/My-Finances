import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sweet_alert.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/gaxxs_loader.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  // Registration controllers
  final _regUserCtrl = TextEditingController();
  final _regPassCtrl = TextEditingController();
  final _regPinCtrl = TextEditingController();

  // Password Login controllers
  final _loginUserCtrl = TextEditingController();
  final _loginPassCtrl = TextEditingController();

  final List<int> _pinInput = [];
  bool _isRegistering = false;
  bool _isLoading = false;
  bool _biometricsEnabled = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _regUserCtrl.dispose();
    _regPassCtrl.dispose();
    _regPinCtrl.dispose();
    _loginUserCtrl.dispose();
    _loginPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    final isRegistered = await ref.read(authServiceProvider).isUserRegistered();
    setState(() {
      _isRegistering = !isRegistered;
    });

    if (isRegistered) {
      final username = await ref.read(authServiceProvider).getUsername();
      // Check if biometrics are enabled (masterKey stored)
      final masterKey = await ref.read(secureStorageProvider).getMasterKey();
      final bioEnabled = masterKey != null;
      setState(() {
        _loginUserCtrl.text = username;
        _biometricsEnabled = bioEnabled;
        _tabController.index = 1;
      });
      // Auto-trigger biometrics only if enabled
      if (bioEnabled) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) _triggerBiometrics();
        });
      }
    }
  }

  Future<void> _triggerBiometrics() async {
    final success = await ref.read(authStateProvider.notifier).loginWithBiometrics();
    if (success) {
      _errorMessage = '';
    }
  }

  void _onKeyPress(int number) {
    if (_pinInput.length < 4) {
      setState(() {
        _pinInput.add(number);
        _errorMessage = '';
      });
    }

    if (_pinInput.length == 4) {
      _processPinLogin();
    }
  }

  void _onDelete() {
    if (_pinInput.isNotEmpty) {
      setState(() {
        _pinInput.removeLast();
      });
    }
  }

  Future<void> _processPinLogin() async {
    final pin = _pinInput.join();
    setState(() => _pinInput.clear());

    final success = await ref.read(authStateProvider.notifier).loginWithPin(pin);
    if (!success && mounted) {
      setState(() {
        _errorMessage = 'PIN incorrecto. Reintenta.';
      });
      AppToast.show(context, message: 'PIN incorrecto. Verifícalo e intenta de nuevo.', type: AppToastType.error);
    } else if (mounted) {
      AppToast.show(context, message: '¡Bóveda desbloqueada!', type: AppToastType.success);
    }
  }

  Future<void> _processPasswordLogin() async {
    if (_loginUserCtrl.text.isEmpty || _loginPassCtrl.text.isEmpty) return;
    setState(() { _isLoading = true; _errorMessage = ''; });

    try {
      final success = await ref.read(authStateProvider.notifier).loginWithPassword(
        username: _loginUserCtrl.text,
        masterPassword: _loginPassCtrl.text,
      );

      if (!success && mounted) {
        setState(() {
          _errorMessage = 'Usuario o Contraseña incorrectos.';
          _isLoading = false;
        });
        AppToast.show(context, message: 'Credenciales inválidas. Revisa tu usuario y contraseña.', type: AppToastType.error);
      } else if (mounted) {
        AppToast.show(context, message: '¡Bienvenido de vuelta!', type: AppToastType.success);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('SocketException: ', '');
          _isLoading = false;
        });
        SweetAlert.show(
          context,
          title: 'Error',
          description: _errorMessage,
          icon: SweetAlertIcon.warning,
        );
      }
    }
  }

  Future<void> _processRegister() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _isLoading = true; _errorMessage = ''; });

    try {
      final success = await ref.read(authStateProvider.notifier).register(
        username: _regUserCtrl.text,
        masterPassword: _regPassCtrl.text,
        pin: _regPinCtrl.text,
      );

      if (!success && mounted) {
        setState(() {
          _errorMessage = 'Error al registrar el usuario. Reintenta.';
          _isLoading = false;
        });
      } else if (mounted) {
        SweetAlert.show(
          context,
          title: '¡Bóveda Creada!',
          description: 'Tu bóveda se ha registrado y desbloqueada localmente con éxito.',
          icon: SweetAlertIcon.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('SocketException: ', '');
          _isLoading = false;
        });
        SweetAlert.show(
          context,
          title: 'Error de Registro',
          description: _errorMessage,
          icon: SweetAlertIcon.error,
        );
      }
    }
  }

  Future<void> _showRecoveryDialog() async {
    final formKey = GlobalKey<FormState>();
    final recoveryKeyCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final newPinCtrl = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceDark,
          title: const Text('Recuperar Acceso a Bóveda', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ingresa tu clave de recuperación (Zero-Knowledge) para restablecer tus accesos de seguridad.',
                    style: TextStyle(color: AppTheme.textSecondaryDark, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: recoveryKeyCtrl,
                    decoration: const InputDecoration(labelText: 'Clave de Recuperación', prefixIcon: Icon(Icons.key_outlined)),
                    style: const TextStyle(color: Colors.white),
                    validator: (val) => (val == null || val.isEmpty) ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPassCtrl,
                    decoration: const InputDecoration(labelText: 'Nueva Contraseña Maestra (mín. 8)', prefixIcon: Icon(Icons.password_outlined)),
                    obscureText: true,
                    style: const TextStyle(color: Colors.white),
                    validator: (val) => (val == null || val.length < 8) ? 'Contraseña muy corta' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: newPinCtrl,
                    decoration: const InputDecoration(labelText: 'Nuevo PIN (4 dígitos)', prefixIcon: Icon(Icons.fiber_pin_outlined)),
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(color: Colors.white),
                    maxLength: 4,
                    validator: (val) => (val == null || val.length < 4) ? 'Debe tener 4 dígitos' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryDark),
              child: const Text('Restablecer', style: TextStyle(color: Colors.white)),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(ctx, true);
                }
              },
            ),
          ],
        );
      },
    ).then((confirmed) async {
      if (confirmed == true) {
        final newKey = await ref.read(authStateProvider.notifier).recoverAccess(
          recoveryKey: recoveryKeyCtrl.text,
          newMasterPassword: newPassCtrl.text,
          newPin: newPinCtrl.text,
        );

        if (newKey != null) {
          if (mounted) {
            SweetAlert.show(
              context,
              title: '¡Acceso Restablecido!',
              description: 'Tu contraseña y PIN han sido cambiados.\n\nTU NUEVA CLAVE DE RECUPERACIÓN ES:\n\n$newKey\n\nPor favor, cópiala y guárdala. La anterior ha quedado invalidada.',
              confirmButtonText: 'Entendido y Copiado',
              icon: SweetAlertIcon.success,
            );
          }
        } else {
          if (mounted) {
            SweetAlert.show(
              context,
              title: 'Error de Recuperación',
              description: 'Clave de recuperación incorrecta o datos inválidos. Intenta de nuevo.',
              icon: SweetAlertIcon.error,
            );
          }
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
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
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Clean Vector Emblem Icon (No black square background)
                  const GaxxsIconMark(size: 60),
                  const SizedBox(height: 14),
                  Text(
                    'My Finances',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!_isRegistering && _loginUserCtrl.text.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryDark.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.primaryDark.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircleAvatar(
                            radius: 12,
                            backgroundColor: AppTheme.primaryDark,
                            child: Icon(Icons.person, size: 14, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '¡Hola de nuevo, ${_loginUserCtrl.text.toUpperCase()}!',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    _isRegistering
                        ? 'Crea tu bóveda criptográfica'
                        : (_biometricsEnabled ? 'Desbloquea con tu PIN o Huella' : 'Desbloquea con tu PIN'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondaryDark,
                        ),
                  ),
                  const SizedBox(height: 28),

                  if (_errorMessage.isNotEmpty) ...[
                    Text(
                      _errorMessage,
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                  ],

                  _isRegistering ? _buildRegisterForm() : _buildLoginForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Card(
      elevation: 4,
      color: AppTheme.surfaceDark.withOpacity(0.9),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Registro Inicial',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // Username Input
              AppTextField(
                controller: _regUserCtrl,
                labelText: 'Nombre de Usuario',
                prefixIcon: Icons.person_outline,
                validator: (val) => (val == null || val.isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),

              // Master Password Input
              AppTextField(
                controller: _regPassCtrl,
                labelText: 'Contraseña Maestra',
                prefixIcon: Icons.password_outlined,
                isPassword: true,
                validator: (val) {
                  if (val == null || val.length < 8) {
                    return 'Debe tener al menos 8 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // PIN Input
              AppTextField(
                controller: _regPinCtrl,
                labelText: 'PIN de acceso rápido (4 dígitos)',
                prefixIcon: Icons.pin_outlined,
                isPassword: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                validator: (val) {
                  if (val == null || val.length != 4 || int.tryParse(val) == null) {
                    return 'Debe ser un PIN de 4 dígitos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _processRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Crear Bóveda Segura',
                        style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // TabBar to switch between Password and PIN login methods
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.surfaceDark.withOpacity(0.5) : Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: isDark ? AppTheme.primaryDark : AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(12),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            dividerColor: Colors.transparent,
            tabs: [
              const Tab(text: 'Contraseña Maestra'),
              Tab(text: _biometricsEnabled ? 'PIN / Huella' : 'PIN Rápido'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.45,
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Password Login
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: _loginUserCtrl,
                      labelText: 'Usuario',
                      prefixIcon: Icons.person_outline,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: _loginPassCtrl,
                      labelText: 'Contraseña Maestra',
                      prefixIcon: Icons.password_outlined,
                      isPassword: true,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _processPasswordLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: GaxxsLoader(size: 24, showBrandName: false),
                            )
                          : const Text(
                              'Desbloquear Bóveda',
                              style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _showRecoveryDialog,
                      child: const Text(
                        '¿Olvidaste tu contraseña maestra?',
                        style: TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),

              // Tab 2: PIN Pad / Biometrics Login
              Column(
                children: [
                  // PIN Dots Display
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index < _pinInput.length
                              ? AppTheme.primaryDark
                              : AppTheme.textSecondaryDark.withOpacity(0.3),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  
                  // Custom numeric keypad
                  Expanded(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.5,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: 12,
                      itemBuilder: (context, index) {
                        if (index == 9) {
                          // Biometrics Key — only show if enabled
                          return _biometricsEnabled
                              ? IconButton(
                                  onPressed: _triggerBiometrics,
                                  icon: const Icon(Icons.fingerprint, size: 30, color: AppTheme.primaryDark),
                                  tooltip: 'Ingresar con huella',
                                )
                              : const SizedBox.shrink();
                        } else if (index == 10) {
                          // Zero Key
                          return _buildPinKey(0);
                        } else if (index == 11) {
                          // Delete Key
                          return IconButton(
                            onPressed: _onDelete,
                            icon: const Icon(Icons.backspace_outlined, size: 24, color: AppTheme.primaryDark),
                          );
                        } else {
                          // Keys 1-9
                          return _buildPinKey(index + 1);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinKey(int value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _onKeyPress(value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.surfaceDark.withOpacity(0.5) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300]!),
          boxShadow: isDark ? [] : [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Text(
          '$value',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textPrimaryLight,
          ),
        ),
      ),
    );
  }
}
