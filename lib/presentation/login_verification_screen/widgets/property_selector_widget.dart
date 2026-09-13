import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/loading_skeleton_widget.dart';

class PropertySelectorWidget extends StatefulWidget {
  final List<Map<String, dynamic>> properties;
  final bool isLoading;
  final String? selectedPropertyId;
  final String? selectedPropertyName;
  final Color roleColor;
  final Function(String id, String name) onPropertySelected;
  final VoidCallback onNext;

  const PropertySelectorWidget({
    super.key,
    required this.properties,
    required this.isLoading,
    required this.selectedPropertyId,
    required this.selectedPropertyName,
    required this.roleColor,
    required this.onPropertySelected,
    required this.onNext,
  });

  @override
  State<PropertySelectorWidget> createState() => _PropertySelectorWidgetState();
}

class _PropertySelectorWidgetState extends State<PropertySelectorWidget> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filtered = [];
  bool _isDropdownOpen = false;

  @override
  void initState() {
    super.initState();
    _filtered = widget.properties;
    _searchController.addListener(_filterProperties);
  }

  void _filterProperties() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filtered = widget.properties.where((p) {
        final name = (p['name'] as String? ?? '').toLowerCase();
        final city = (p['city'] as String? ?? '').toLowerCase();
        return name.contains(query) || city.contains(query);
      }).toList();
    });
  }

  @override
  void didUpdateWidget(PropertySelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.properties != widget.properties) {
      _filtered = widget.properties;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Property',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: AppTheme.onSurface,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Choose the hotel property you\'re working at',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: AppTheme.onSurfaceMuted,
          ),
        ),
        const SizedBox(height: 32),

        if (widget.isLoading) ...[
          const LoadingSkeletonWidget(
            width: double.infinity,
            height: 54,
            borderRadius: 12,
          ),
          const SizedBox(height: 12),
          const LoadingSkeletonWidget(
            width: double.infinity,
            height: 54,
            borderRadius: 12,
          ),
          const LoadingSkeletonWidget(
            width: double.infinity,
            height: 54,
            borderRadius: 12,
          ),
        ] else ...[
          // Search field
          TextField(
            controller: _searchController,
            onTap: () => setState(() => _isDropdownOpen = true),
            decoration: InputDecoration(
              hintText: 'Search properties...',
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppTheme.onSurfaceMuted,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppTheme.onSurfaceMuted,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _isDropdownOpen = false);
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppTheme.surfaceVariant,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppTheme.outline, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: widget.roleColor, width: 2),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Property list
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.business_rounded,
                          size: 48,
                          color: AppTheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No properties found',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppTheme.onSurfaceMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: _filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final prop = _filtered[i];
                      final isSelected =
                          widget.selectedPropertyId == prop['property_id'];
                      return GestureDetector(
                        onTap: () {
                          widget.onPropertySelected(
                            prop['property_id'] as String,
                            prop['name'] as String,
                          );
                          _searchController.clear();
                          setState(() => _isDropdownOpen = false);
                          FocusScope.of(context).unfocus();
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? widget.roleColor.withAlpha(12)
                                : AppTheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? widget.roleColor
                                  : AppTheme.outline,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: widget.roleColor.withAlpha(20),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ]
                                : [
                                    const BoxShadow(
                                      color: Color(0x0A000000),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? widget.roleColor.withAlpha(20)
                                      : AppTheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    prop['property_type'] != null
                                        ? (prop['property_type'] as String)
                                              .substring(
                                                0,
                                                (prop['property_type']
                                                        as String)
                                                    .length
                                                    .clamp(0, 3),
                                              )
                                              .toUpperCase()
                                        : (prop['name'] as String)
                                              .substring(
                                                0,
                                                (prop['name'] as String).length
                                                    .clamp(0, 3),
                                              )
                                              .toUpperCase(),
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? widget.roleColor
                                          : AppTheme.onSurfaceMuted,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      prop['name'] as String,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? widget.roleColor
                                            : AppTheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_rounded,
                                          size: 12,
                                          color: isSelected
                                              ? widget.roleColor.withAlpha(160)
                                              : AppTheme.onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          prop['city'] != null
                                              ? prop['city'] as String
                                              : '',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w400,
                                            color: isSelected
                                                ? widget.roleColor.withAlpha(
                                                    180,
                                                  )
                                                : AppTheme.onSurfaceMuted,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: widget.roleColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],

        const SizedBox(height: 16),

        // Selected property confirmation + CTA
        if (widget.selectedPropertyId != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.successContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.success.withAlpha(60)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 18,
                  color: AppTheme.success,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.selectedPropertyName ?? '',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.roleColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Continue',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, size: 18),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
