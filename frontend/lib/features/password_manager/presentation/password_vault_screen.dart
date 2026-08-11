import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/theme/app_theme.dart';

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
    String serviceName = isEdit ? credentialToEdit['serviceName']! : '';
    String username = isEdit ? credentialToEdit['username']! : '';
    String password = isEdit ? credentialToEdit['password']! : '';
    String websiteUrl = isEdit ? credentialToEdit['websiteUrl']! : '';
    String notes = isEdit ? credentialToEdit['notes']! : '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surfaceDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        isEdit ? 'Editar Credencial' : 'Nueva Credencial Cifrada',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontSize: 20,
                            ),
                      ),
                      const SizedBox(height: 16),

                      // Service Name Input
                      TextFormField(
                        initialValue: serviceName,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del Servicio / Banco',
                          prefixIcon: Icon(Icons.business_outlined),
                        ),
                        validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
                        onSaved: (val) => serviceName = val!,
                      ),
                      const SizedBox(height: 12),

                      // Username Input
                      TextFormField(
                        initialValue: username,
                        decoration: const InputDecoration(
                          labelText: 'Usuario / Correo',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
                        onSaved: (val) => username = val!,
                      ),
                      const SizedBox(height: 12),

                      // Password Input
                      TextFormField(
                        initialValue: password,
                        decoration: const InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Icon(Icons.password_outlined),
                        ),
                        obscureText: true,
                        validator: (value) => (value == null || value.isEmpty) ? 'Requerido' : null,
                        onSaved: (val) => password = val!,
                      ),
                      const SizedBox(height: 12),

                      // Website URL Input (Optional)
                      TextFormField(
                        initialValue: websiteUrl,
                        decoration: const InputDecoration(
                          labelText: 'URL del Sitio Web (Opcional)',
                          prefixIcon: Icon(Icons.link_outlined),
                        ),
                        onSaved: (val) => websiteUrl = val ?? '',
                      ),
                      const SizedBox(height: 12),

                      // Notes Input (Optional)
                      TextFormField(
                        initialValue: notes,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Notas / PIN de Seguridad (Opcional)',
                          prefixIcon: Icon(Icons.note_alt_outlined),
                        ),
                        onSaved: (val) => notes = val ?? '',
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      ElevatedButton(
                        onPressed: () async {
                          if (formKey.currentState!.validate()) {
                            formKey.currentState!.save();

                            await ref.read(localPasswordRepositoryProvider).saveCredential(
                              id: id,
                              serviceName: serviceName,
                              username: username,
                              clearPassword: password,
                              websiteUrl: websiteUrl,
                              clearNotes: notes,
                            );

                            ref.invalidate(decryptedCredentialsProvider);
                            Navigator.pop(ctx);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryDark,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(isEdit ? 'Guardar Cambios' : 'Añadir a Bóveda', style: const TextStyle(color: Colors.white, fontSize: 16)),
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
