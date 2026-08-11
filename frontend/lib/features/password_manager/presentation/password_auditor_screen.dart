import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/global_providers.dart';
import '../../../core/theme/app_theme.dart';

class PasswordAuditorScreen extends ConsumerStatefulWidget {
  const PasswordAuditorScreen({super.key});

  @override
  ConsumerState<PasswordAuditorScreen> createState() => _PasswordAuditorScreenState();
}

class _PasswordAuditorScreenState extends ConsumerState<PasswordAuditorScreen> {
  String _generatedPassphrase = '';
  int _wordCount = 4;
  
  final List<String> _dicewareWords = [
    'sol', 'luna', 'gato', 'perro', 'arbol', 'casa', 'mesa', 'silla',
    'libro', 'lapiz', 'nube', 'lluvia', 'viento', 'fuego', 'agua',
    'tierra', 'flor', 'fruta', 'cielo', 'monte', 'rio', 'mar', 'arena',
    'piedra', 'metal', 'papel', 'reloj', 'caja', 'llave', 'puerta',
    'ventana', 'camino', 'puente', 'bosque', 'selva', 'desierto',
    'noche', 'dia', 'tarde', 'mañana', 'verde', 'azul', 'rojo', 'amarillo'
  ];

  @override
  void initState() {
    super.initState();
    _generatePassphrase();
  }

  void _generatePassphrase() {
    final rand = Random.secure();
    final words = <String>[];
    for (int i = 0; i < _wordCount; i++) {
      words.add(_dicewareWords[rand.nextInt(_dicewareWords.length)]);
    }
    // Add a random 2-digit number at the end for extra strength
    final num = rand.nextInt(90) + 10;
    setState(() {
      _generatedPassphrase = '${words.join("-")}-$num';
    });
  }

  double _calculateEntropy(String password) {
    if (password.isEmpty) return 0.0;
    
    int poolSize = 0;
    if (RegExp(r'[a-z]').hasMatch(password)) poolSize += 26;
    if (RegExp(r'[A-Z]').hasMatch(password)) poolSize += 26;
    if (RegExp(r'[0-9]').hasMatch(password)) poolSize += 10;
    if (RegExp(r'[^a-zA-Z0-9]').hasMatch(password)) poolSize += 33; // Special characters
    
    if (poolSize == 0) poolSize = 1;
    
    // Entropy formula: H = L * log2(R)
    return password.length * (log(poolSize) / log(2));
  }

  @override
  Widget build(BuildContext context) {
    final credentialsAsync = ref.watch(decryptedCredentialsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Auditor de Seguridad', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. DICWARE GENERATOR MODULE
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Generador de Passphrases (Método Diceware)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Crea contraseñas fáciles de recordar pero extremadamente difíciles de romper mediante fuerza bruta.',
                      style: TextStyle(color: AppTheme.textSecondaryDark, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _generatedPassphrase,
                              style: const TextStyle(
                                fontSize: 16,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentDark,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_outlined, color: AppTheme.primaryDark),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: _generatedPassphrase));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Copiado al portapapeles.')),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: AppTheme.primaryDark),
                            onPressed: _generatePassphrase,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Cantidad de palabras:', style: TextStyle(color: Colors.white70)),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove, color: Colors.white60),
                              onPressed: _wordCount > 3 ? () => setState(() { _wordCount--; _generatePassphrase(); }) : null,
                            ),
                            Text('$_wordCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            IconButton(
                              icon: const Icon(Icons.add, color: Colors.white60),
                              onPressed: _wordCount < 6 ? () => setState(() { _wordCount++; _generatePassphrase(); }) : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 2. AUDIT SUMMARY MODULE
            Text(
              'Salud General de Contraseñas',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            credentialsAsync.when(
              data: (credentials) {
                if (credentials.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Center(
                        child: Text(
                          'No tienes contraseñas en tu bóveda para auditar.',
                          style: TextStyle(color: AppTheme.textSecondaryDark),
                        ),
                      ),
                    ),
                  );
                }

                // Audit calculations
                int weakCount = 0;
                int mediumCount = 0;
                int strongCount = 0;

                // Find duplicate passwords
                final Map<String, List<String>> passwordReused = {};
                for (var cred in credentials) {
                  final pass = cred['password'] ?? '';
                  final service = cred['serviceName'] ?? '';
                  passwordReused.putIfAbsent(pass, () => []).add(service);
                }

                final List<String> duplicateWarnings = [];
                passwordReused.forEach((pass, services) {
                  if (services.length > 1) {
                    duplicateWarnings.add(
                      'Contraseña repetida en: ${services.join(", ")}'
                    );
                  }
                });

                for (var cred in credentials) {
                  final pass = cred['password'] ?? '';
                  final double entropy = _calculateEntropy(pass);
                  if (entropy < 50) {
                    weakCount++;
                  } else if (entropy < 75) {
                    mediumCount++;
                  } else {
                    strongCount++;
                  }
                }

                final double total = credentials.length.toDouble();
                final double healthScore = (strongCount + (mediumCount * 0.5)) / total * 100;

                return Column(
                  children: [
                    // Health Score Dashboard Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('PUNTUACIÓN DE SALUD', style: TextStyle(color: AppTheme.textSecondaryDark, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${healthScore.toStringAsFixed(0)}%',
                                    style: TextStyle(
                                      fontSize: 48,
                                      fontWeight: FontWeight.bold,
                                      color: healthScore > 75 ? Colors.greenAccent : (healthScore > 40 ? Colors.amberAccent : Colors.redAccent),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    healthScore > 75 ? 'Excelente protección' : (healthScore > 40 ? 'Requiere mejoras' : '¡Peligro! Contraseñas débiles'),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            // Micro counts
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildIndicator('Fuertes', strongCount, Colors.greenAccent),
                                const SizedBox(height: 8),
                                _buildIndicator('Medias', mediumCount, Colors.amberAccent),
                                const SizedBox(height: 8),
                                _buildIndicator('Débiles', weakCount, Colors.redAccent),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    if (duplicateWarnings.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      // Duplicates warnings card
                      Card(
                        color: Colors.redAccent.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: Colors.redAccent, width: 0.5),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Alertas de Reutilización de Contraseña',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...duplicateWarnings.map((warning) => Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                                    child: Text(
                                      '• $warning',
                                      style: const TextStyle(color: AppTheme.textSecondaryDark, fontSize: 13),
                                    ),
                                  )),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Password items list with strength indicator
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: credentials.length,
                      itemBuilder: (context, index) {
                        final cred = credentials[index];
                        final pass = cred['password'] ?? '';
                        final double entropy = _calculateEntropy(pass);
                        
                        Color strengthColor = Colors.greenAccent;
                        String label = 'Fuerte';
                        if (entropy < 50) {
                          strengthColor = Colors.redAccent;
                          label = 'Débil';
                        } else if (entropy < 75) {
                          strengthColor = Colors.amberAccent;
                          label = 'Media';
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            leading: Container(
                              width: 8,
                              height: 36,
                              decoration: BoxDecoration(
                                color: strengthColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            title: Text(cred['serviceName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('Usuario: ${cred['username']}'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(color: strengthColor, fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${entropy.toStringAsFixed(0)} bits',
                                  style: const TextStyle(color: AppTheme.textSecondaryDark, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Text('Error: $err'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicator(String name, int count, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text('$name: ', style: const TextStyle(color: AppTheme.textSecondaryDark, fontSize: 12)),
        Text('$count', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      ],
    );
  }
}
