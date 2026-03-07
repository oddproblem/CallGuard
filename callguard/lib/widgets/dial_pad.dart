import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Dial input field + call button.
class DialPad extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onCall;

  const DialPad({
    super.key,
    required this.controller,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label
          Row(
            children: [
              Icon(Icons.dialpad_rounded, color: AppColors.textSecondary, size: 16),
              const SizedBox(width: 8),
              Text('DIAL', style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: 16),
          // Input
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: AppTextStyles.dialInput,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: '• • • • • •',
              hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.12),
                fontSize: 28,
                letterSpacing: 8,
              ),
              counterText: '',
              filled: true,
              fillColor: AppColors.background,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Call button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: onCall,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              child: Ink(
                decoration: BoxDecoration(
                  gradient: AppGradients.accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.call_rounded, size: 22, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'CALL',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
