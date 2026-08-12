import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/sweet_alert.dart';

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
  String _errorMessage = '';
  String _savedUsername = '';

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
      setState(() {
        _savedUsername = username;
        _loginUserCtrl.text = username;
      });
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
    if (!success) {
      setState(() {
        _errorMessage = 'PIN incorrecto. Reintenta.';
      });
    }
  }

  Future<void> _processPasswordLogin() async {
    if (_loginUserCtrl.text.isEmpty || _loginPassCtrl.text.isEmpty) return;

    try {
      final success = await ref.read(authStateProvider.notifier).loginWithPassword(
        username: _loginUserCtrl.text,
        masterPassword: _loginPassCtrl.text,
      );

      if (!success) {
        setState(() {
          _errorMessage = 'Usuario o Contraseña incorrectos.';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('SocketException: ', '');
      });
      if (mounted) {
        SweetAlert.show(
          context,
          title: 'Error de Conexión',
          description: _errorMessage,
          icon: SweetAlertIcon.warning,
        );
      }
    }
  }

  Future<void> _processRegister() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final success = await ref.read(authStateProvider.notifier).register(
        username: _regUserCtrl.text,
        masterPassword: _regPassCtrl.text,
        pin: _regPinCtrl.text,
      );

      if (!success) {
        setState(() {
          _errorMessage = 'Error al registrar el usuario. Reintenta.';
        });
      } else {
        final recoveryKey = ref.read(authStateProvider.notifier).generatedRecoveryKey ?? 'No disponible';
        if (mounted) {
          SweetAlert.show(
            context,
            title: '¡Bóveda Creada!',
            description: 'Tu bóveda se ha registrado en la nube con éxito.\n\nESTA ES TU CLAVE DE RECUPERACIÓN (Zero-Knowledge):\n\n$recoveryKey\n\nPor favor, cópiala y guárdala en un lugar seguro. Es la única forma de recuperar tu acceso si olvidas tu contraseña.',
            confirmButtonText: 'Entendido y Copiado',
            icon: SweetAlertIcon.success,
          );
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '').replaceAll('SocketException: ', '');
      });
      if (mounted) {
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
                  // Logo/Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: AppTheme.primaryDark,
                      size: 50,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'My Finances',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRegistering ? 'Crea tu bóveda criptográfica' : 'Bóveda Cifrada de Extremo a Extremo',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondaryDark,
                        ),
                  ),
                  const SizedBox(height: 32),

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
              TextFormField(
                controller: _regUserCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre de Usuario',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                style: const TextStyle(color: Colors.white),
                validator: (val) => (val == null || val.isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),

              // Master Password Input
              TextFormField(
                controller: _regPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña Maestra',
                  prefixIcon: Icon(Icons.password_outlined),
                ),
                style: const TextStyle(color: Colors.white),
                validator: (val) {
                  if (val == null || val.length < 8) {
                    return 'Debe tener al menos 8 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // PIN Input
              TextFormField(
                controller: _regPinCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 4,
                decoration: const InputDecoration(
                  labelText: 'PIN de acceso rápido (4 dígitos)',
                  prefixIcon: Icon(Icons.pin_outlined),
                  counterText: '',
                ),
                style: const TextStyle(color: Colors.white),
                validator: (val) {
                  if (val == null || val.length != 4 || int.tryParse(val) == null) {
                    return 'Debe ser un PIN de 4 dígitos';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _processRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
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
    return Column(
      children: [
        // TabBar to switch between Password and PIN login methods
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: AppTheme.primaryDark,
              borderRadius: BorderRadius.circular(12),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: AppTheme.textSecondaryDark,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'Contraseña Maestra'),
              Tab(text: 'PIN / Huella'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        
        SizedBox(
          height: 380,
          child: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Password Login
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _loginUserCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _loginPassCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Contraseña Maestra',
                        prefixIcon: Icon(Icons.password_outlined),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _processPasswordLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryDark,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
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
                          // Biometrics Key
                          return IconButton(
                            onPressed: _triggerBiometrics,
                            icon: const Icon(Icons.fingerprint, size: 30, color: AppTheme.primaryDark),
                          );
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
    return InkWell(
      onTap: () => _onKeyPress(value),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.primaryDark.withOpacity(0.1)),
        ),
        child: Text(
          '$value',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }
}
