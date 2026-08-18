import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/widgets/sweet_alert.dart';

class PasswordVaultScreen extends ConsumerStatefulWidget {
  const PasswordVaultScreen({super.key});

  @override
  ConsumerState<PasswordVaultScreen> createState() => _PasswordVaultScreenState();
}

class _PasswordVaultScreenState extends ConsumerState<PasswordVaultScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  void _showAddCredentialDialog({Map<String, String>? credentialToEdit}) {
    final isEdit = credentialToEdit != null;
    final id = isEdit ? credentialToEdit['id']! : DateTime.now().millisecondsSinceEpoch.toString();
    
    final formKey = GlobalKey<FormState>();
    final serviceCtrl = TextEditingController(text: isEdit ? credentialToEdit['serviceName']! : '');
    final userCtrl = TextEditingController(text: isEdit ? credentialToEdit['username']! : '');
    final passCtrl = TextEditingController(text: isEdit ? credentialToEdit['password']! : '');
    final urlCtrl = TextEditingController(text: isEdit ? credentialToEdit['websiteUrl']! : '');
    final notesCtrl = TextEditingController(text: isEdit ? credentialToEdit['notes']! : '');
    String selectedCategory = 'banco';

    void generateSecurePassword(StateSetter setModalState) {
      const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()';
      final rnd = Random.secure();
      final newPass = List.generate(16, (index) => chars[rnd.nextInt(chars.length)]).join();
      setModalState(() {
        passCtrl.text = newPass;
      });
      AppToast.show(context, message: '🎲 ¡Contraseña segura de 16 caracteres generada!', type: AppToastType.success);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withOpacity(0.15) : Colors.black12, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 32,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Drag handle
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? Colors.white24 : Colors.black26,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),

                      // Header with Shield Badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryDark.withOpacity(0.2),
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.primaryDark.withOpacity(0.4)),
                            ),
                            child: const Icon(Icons.shield_outlined, color: AppTheme.primaryDark, size: 24),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isEdit ? 'Editar Credencial' : 'Nueva Credencial Cifrada',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : AppTheme.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Protegida con Cifrado Grado Militar AES-256',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).brightness == Brightness.dark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Service / Bank Name
                      AppTextField(
                        controller: serviceCtrl,
                        labelText: 'Nombre del Servicio / Banco (ej. BNC, Gmail)',
                        prefixIcon: Icons.account_balance_outlined,
                        validator: (val) => (val == null || val.isEmpty) ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 12),

                      // Username / Email
                      AppTextField(
                        controller: userCtrl,
                        labelText: 'Usuario / Correo Electrónico',
                        prefixIcon: Icons.person_outline,
                        validator: (val) => (val == null || val.isEmpty) ? 'Campo requerido' : null,
                      ),
                      const SizedBox(height: 12),

                      // Password with Random Generator button 🎲
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: passCtrl,
                              labelText: 'Contraseña',
                              prefixIcon: Icons.lock_outline,
                              isPassword: true,
                              validator: (val) => (val == null || val.isEmpty) ? 'Campo requerido' : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.casino_outlined, color: AppTheme.primaryDark, size: 28),
                            tooltip: 'Generar Contraseña Segura',
                            onPressed: () => generateSecurePassword(setModalState),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Website URL Input (Optional)
                      AppTextField(
                        controller: urlCtrl,
                        labelText: 'URL del Sitio Web (Opcional)',
                        prefixIcon: Icons.language_outlined,
                      ),
                      const SizedBox(height: 12),

                      // Notes Input (Optional)
                      AppTextField(
                        controller: notesCtrl,
                        labelText: 'Notas / PIN de Seguridad (Opcional)',
                        prefixIcon: Icons.note_alt_outlined,
                      ),
                      const SizedBox(height: 24),

                      // Save Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryDark,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                        icon: const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                        label: Text(
                          isEdit ? 'Guardar Cambios' : '🔐 Añadir a Bóveda Cifrada',
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            await ref.read(localPasswordRepositoryProvider).saveCredential(
                              id: id,
                              serviceName: serviceCtrl.text,
                              username: userCtrl.text,
                              clearPassword: passCtrl.text,
                              websiteUrl: urlCtrl.text,
                              clearNotes: notesCtrl.text,
                            );

                            ref.invalidate(decryptedCredentialsProvider);
                            if (ctx.mounted) {
                              Navigator.pop(ctx);
                              AppToast.show(
                                context,
                                message: '🔐 ¡Credencial "${serviceCtrl.text}" guardada en la bóveda!',
                                type: AppToastType.success,
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _copyToClipboard(String text, String fieldName) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$fieldName copiado al portapapeles.'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppTheme.accentDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final credentialsAsync = ref.watch(decryptedCredentialsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bóveda de Contraseñas', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Buscar cuentas...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.toLowerCase();
                });
              },
            ),
            const SizedBox(height: 16),

            // Credentials list
            Expanded(
              child: credentialsAsync.when(
                data: (credentials) {
                  final filtered = credentials.where((cred) {
                    return cred['serviceName']!.toLowerCase().contains(_searchQuery) ||
                        cred['username']!.toLowerCase().contains(_searchQuery);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'No se encontraron credenciales en tu bóveda.',
                        style: TextStyle(color: AppTheme.textSecondaryDark),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final cred = filtered[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ExpansionTile(
                          leading: const CircleAvatar(
                            backgroundColor: AppTheme.primaryDark,
                            child: Icon(Icons.vpn_key, color: Colors.white),
                          ),
                          title: Text(
                            cred['serviceName']!,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(cred['username']!),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: [
                                  // Detail row for Website URL
                                  if (cred['websiteUrl']!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 8.0),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.link, size: 16, color: AppTheme.textSecondaryDark),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              cred['websiteUrl']!,
                                              style: const TextStyle(color: Colors.blueAccent),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  
                                  // Detail row for Notes
                                  if (cred['notes']!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 12.0),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Icon(Icons.note_alt_outlined, size: 16, color: AppTheme.textSecondaryDark),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              cred['notes']!,
                                              style: const TextStyle(color: AppTheme.textSecondaryDark),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  // Quick Copy Actions Row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _copyToClipboard(cred['username']!, 'Usuario'),
                                        icon: const Icon(Icons.copy, size: 16),
                                        label: const Text('Usuario'),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _copyToClipboard(cred['password']!, 'Contraseña'),
                                        icon: const Icon(Icons.copy, size: 16),
                                        label: const Text('Contraseña'),
                                      ),
                                    ],
                                  ),
                                  
                                  const Divider(),
                                  
                                  // Edit & Delete row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _showAddCredentialDialog(credentialToEdit: cred),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        onPressed: () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Eliminar Credencial'),
                                              content: const Text('¿Estás seguro de que quieres eliminar esta cuenta permanentemente de tu bóveda local?'),
                                              actions: [
                                                TextButton(
                                                  child: const Text('Cancelar'),
                                                  onPressed: () => Navigator.pop(ctx, false),
                                                ),
                                                TextButton(
                                                  child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            await ref.read(localPasswordRepositoryProvider).deleteCredential(cred['id']!);
                                            ref.invalidate(decryptedCredentialsProvider);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Text('Error: $err'),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCredentialDialog(),
        backgroundColor: AppTheme.primaryDark,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
