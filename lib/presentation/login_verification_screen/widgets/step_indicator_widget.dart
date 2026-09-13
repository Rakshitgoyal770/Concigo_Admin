import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';

class StepIndicatorWidget extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final List<String> labels;
  final Color activeColor;

  const StepIndicatorWidget({
    super.key,
    required this.currentStep,
    required this.totalSteps,
    required this.labels,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(totalSteps * 2 - 1, (index) {
        if (index.isOdd) {
          // Connector line
          final stepIndex = index ~/ 2;
          final isCompleted = currentStep > stepIndex;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 2,
              decoration: BoxDecoration(
                color: isCompleted ? activeColor : AppTheme.outline,
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          );
        } else {
          final stepIndex = index ~/ 2;
          final isCompleted = currentStep > stepIndex;
          final isActive = currentStep == stepIndex;

          return Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isCompleted
                      ? activeColor
                      : isActive
                      ? activeColor.withAlpha(20)
                      : AppTheme.surfaceVariant,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isCompleted || isActive
                        ? activeColor
                        : AppTheme.outline,
                    width: isActive ? 2 : 1.5,
                  ),
                ),
                child: Center(
                  child: isCompleted
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : Text(
                          '${stepIndex + 1}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? activeColor
                                : AppTheme.onSurfaceMuted,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[stepIndex],
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: isActive || isCompleted
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: isActive || isCompleted
                      ? activeColor
                      : AppTheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        }
      }),
    );
  }
}
