import 'package:flutter/material.dart';

/// Friendly dialog that explains why permissions are needed before requesting them
class PermissionDialog extends StatelessWidget {
  const PermissionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: screenSize.width * 0.9,
        height: screenSize.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Friendly header without emoji
              const Text(
                'Hey there, rider.',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 16),

              // Main message
              Text(
                'To keep you safe before you hit the road, we need your permission to access the following:',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.5,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 20),

              // What we need section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey[800] : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Column(
                  children: [
                    _FriendlyPermissionItem(
                      emoji: '📍',
                      title: 'Your location',
                      description: 'So I can check the weather where you are',
                    ),
                    SizedBox(height: 12),
                    _FriendlyPermissionItem(
                      emoji: '🔔',
                      title: 'Send notifications',
                      description: 'To warn you about bad weather for riding',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Continuation message
              Text(
                'Without these permissions, the app won\'t be able to function properly and keep you informed about dangerous or annoying riding conditions.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.left,
              ),
              const SizedBox(height: 20),

              // Promise section
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Color(0x4D1B5E20) : Color(0xFFE8F5E8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color:
                          isDarkMode ? Color(0xFF388E3C) : Color(0xFFC8E6C9)),
                ),
                child: Row(
                  children: [
                    const Text('🤝', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Promise: No spam, just safety alerts when you need them!',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDarkMode
                              ? Color(0xFF81C784)
                              : Color(0xFF388E3C),
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 12,
                        ),
                        side: BorderSide(
                          color: isDarkMode
                              ? Colors.grey[600]!
                              : Colors.grey[400]!,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'No Thanks',
                        style: TextStyle(
                          fontSize: 16,
                          color:
                              isDarkMode ? Colors.grey[300] : Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                      child: const Text(
                        'Sure',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Show the permission dialog and return user's choice
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PermissionDialog(),
    );
    return result ?? false;
  }
}

/// Friendly permission item widget with emoji
class _FriendlyPermissionItem extends StatelessWidget {
  final String emoji;
  final String title;
  final String description;

  const _FriendlyPermissionItem({
    required this.emoji,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(
                  fontSize: 15,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
