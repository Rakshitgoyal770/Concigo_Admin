import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../services/supabase_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/loading_skeleton_widget.dart';
import '../../widgets/empty_state_widget.dart';

/// Which inventory table this screen manages
enum InventoryServiceType { kitchen, laundry, spa }

class ManageInventoryScreen extends StatefulWidget {
  final String propertyId;
  final String propertyName;
  final InventoryServiceType serviceType;
  final GlobalKey<ScaffoldState> scaffoldKey;

  const ManageInventoryScreen({
    super.key,
    required this.propertyId,
    required this.propertyName,
    required this.serviceType,
    required this.scaffoldKey,
  });

  @override
  State<ManageInventoryScreen> createState() => _ManageInventoryScreenState();
}

class _ManageInventoryScreenState extends State<ManageInventoryScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _items = [];
  String? _errorMessage;
  String _searchQuery = '';

  Color get _accentColor {
    switch (widget.serviceType) {
      case InventoryServiceType.kitchen:
        return AppTheme.managerColor;
      case InventoryServiceType.laundry:
        return const Color(0xFF0891B2);
      case InventoryServiceType.spa:
        return const Color(0xFF7C3AED);
    }
  }

  Color get _accentContainer {
    switch (widget.serviceType) {
      case InventoryServiceType.kitchen:
        return AppTheme.managerContainer;
      case InventoryServiceType.laundry:
        return const Color(0xFFECFEFF);
      case InventoryServiceType.spa:
        return const Color(0xFFF5F3FF);
    }
  }

  String get _tableLabel {
    switch (widget.serviceType) {
      case InventoryServiceType.kitchen:
        return 'Menu Items';
      case InventoryServiceType.laundry:
        return 'Laundry Items';
      case InventoryServiceType.spa:
        return 'Spa Services';
    }
  }

  String get _itemIdKey {
    switch (widget.serviceType) {
      case InventoryServiceType.kitchen:
        return 'item_id';
      case InventoryServiceType.laundry:
        return 'item_id';
      case InventoryServiceType.spa:
        return 'spa_item_id';
    }
  }

  /// The boolean availability column name per table
  String get _availabilityKey {
    switch (widget.serviceType) {
      case InventoryServiceType.kitchen:
        return 'in_stock';
      case InventoryServiceType.laundry:
        return 'is_express_available'; // laundry has no single availability flag; use express as proxy
      case InventoryServiceType.spa:
        return 'is_available';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final items = await SupabaseService.instance.fetchInventoryItems(
        propertyId: widget.propertyId,
        serviceType: widget.serviceType,
      );
      if (mounted) {
        setState(() {
          _items = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_searchQuery.isEmpty) return _items;
    final q = _searchQuery.toLowerCase();
    return _items.where((item) {
      final name = (item['name'] as String? ?? '').toLowerCase();
      return name.contains(q);
    }).toList();
  }

  void _showAddEditDialog({Map<String, dynamic>? item}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _InventoryItemDialog(
        serviceType: widget.serviceType,
        existingItem: item,
        accentColor: _accentColor,
        accentContainer: _accentContainer,
        onSave: (data) async {
          Navigator.of(ctx).pop();
          await _saveItem(data, existingId: item?[_itemIdKey] as String?);
        },
      ),
    );
  }

  Future<void> _saveItem(
    Map<String, dynamic> data, {
    String? existingId,
  }) async {
    try {
      if (existingId != null) {
        await SupabaseService.instance.updateInventoryItem(
          propertyId: widget.propertyId,
          serviceType: widget.serviceType,
          itemId: existingId,
          data: data,
        );
        Fluttertoast.showToast(msg: 'Item updated successfully');
      } else {
        await SupabaseService.instance.createInventoryItem(
          propertyId: widget.propertyId,
          serviceType: widget.serviceType,
          data: data,
        );
        Fluttertoast.showToast(msg: 'Item added successfully');
      }
      _loadItems();
    } catch (e) {
      Fluttertoast.showToast(
        msg: 'Error: ${e.toString().replaceFirst('Exception: ', '')}',
      );
    }
  }

  Future<void> _deleteItem(String itemId, String itemName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Item',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete "$itemName"?',
          style: GoogleFonts.plusJakartaSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.onSurfaceMuted,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Delete',
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await SupabaseService.instance.deleteInventoryItem(
          serviceType: widget.serviceType,
          itemId: itemId,
        );
        Fluttertoast.showToast(msg: 'Item deleted');
        _loadItems();
      } catch (e) {
        Fluttertoast.showToast(
          msg: 'Error: ${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
  }

  /// Optimistic toggle for availability (in_stock / is_available)
  Future<void> _toggleAvailability(
    int index,
    String itemId,
    bool currentValue,
  ) async {
    final newValue = !currentValue;
    // Optimistic update
    setState(() {
      _items[index] = {..._items[index], _availabilityKey: newValue};
    });
    try {
      await SupabaseService.instance.updateInventoryItem(
        propertyId: widget.propertyId,
        serviceType: widget.serviceType,
        itemId: itemId,
        data: {_availabilityKey: newValue},
      );
    } catch (e) {
      // Revert on failure
      if (mounted) {
        setState(() {
          _items[index] = {..._items[index], _availabilityKey: currentValue};
        });
        Fluttertoast.showToast(
          msg:
              'Failed to update: ${e.toString().replaceFirst('Exception: ', '')}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header bar
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            bottom: 12,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_accentColor, _accentColor.withAlpha(200)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => widget.scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.menu_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manage Items',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '${widget.propertyName} · $_tableLabel',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => _showAddEditDialog(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, size: 16, color: _accentColor),
                      const SizedBox(width: 4),
                      Text(
                        'Add',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search items...',
              hintStyle: GoogleFonts.plusJakartaSans(
                color: AppTheme.onSurfaceMuted,
                fontSize: 14,
              ),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: AppTheme.onSurfaceMuted,
                size: 20,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.outline),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppTheme.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: _accentColor, width: 1.5),
              ),
            ),
          ),
        ),

        // Count badge
        if (!_isLoading && _errorMessage == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              children: [
                Text(
                  '${_filteredItems.length} item${_filteredItems.length == 1 ? '' : 's'}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: AppTheme.onSurfaceMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

        // Content
        Expanded(
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: ListSkeletonWidget(itemCount: 5),
                )
              : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: Colors.red.shade400,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load items',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _loadItems,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _filteredItems.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.inventory_2_rounded,
                  title: 'No items found',
                  description: _searchQuery.isNotEmpty
                      ? 'Try a different search term'
                      : 'Tap "Add" to create your first item',
                )
              : RefreshIndicator(
                  onRefresh: _loadItems,
                  color: _accentColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: _filteredItems.length,
                    itemBuilder: (ctx, i) {
                      // Find the real index in _items for optimistic toggle
                      final item = _filteredItems[i];
                      final realIndex = _items.indexWhere(
                        (it) => it[_itemIdKey] == item[_itemIdKey],
                      );
                      return _buildItemCard(item, realIndex);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item, int realIndex) {
    final itemId = item[_itemIdKey] as String? ?? '';
    final name = item['name'] as String? ?? 'Unnamed';
    final imageUrl = item['image_url'] as String?;
    final isAvailable = item[_availabilityKey] as bool? ?? true;

    // Price column per service type
    String priceLabel = '';
    if (widget.serviceType == InventoryServiceType.kitchen) {
      final mrp = item['mrp'];
      priceLabel = mrp != null ? '₹$mrp' : '';
    } else if (widget.serviceType == InventoryServiceType.laundry) {
      final price = item['price'];
      priceLabel = price != null ? '₹$price' : '';
    } else {
      final price = item['price'];
      priceLabel = price != null ? '₹$price' : '';
    }

    // Availability label per service type
    String availLabel = '';
    if (widget.serviceType == InventoryServiceType.kitchen) {
      availLabel = isAvailable ? 'In Stock' : 'Out of Stock';
    } else if (widget.serviceType == InventoryServiceType.laundry) {
      availLabel = isAvailable ? 'Express On' : 'Express Off';
    } else {
      availLabel = isAvailable ? 'Available' : 'Unavailable';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      placeholder: (ctx, url) => Container(
                        width: 56,
                        height: 56,
                        color: _accentContainer,
                        child: Icon(
                          _serviceIcon,
                          size: 24,
                          color: _accentColor,
                        ),
                      ),
                      errorWidget: (ctx, url, err) => Container(
                        width: 56,
                        height: 56,
                        color: _accentContainer,
                        child: Icon(
                          _serviceIcon,
                          size: 24,
                          color: _accentColor,
                        ),
                      ),
                    )
                  : Container(
                      width: 56,
                      height: 56,
                      color: _accentContainer,
                      child: Icon(_serviceIcon, size: 24, color: _accentColor),
                    ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + price row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (priceLabel.isNotEmpty)
                        Text(
                          priceLabel,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _accentColor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Extra info chips
                  _buildItemChips(item),
                  const SizedBox(height: 8),
                  // Availability toggle row + action buttons
                  Row(
                    children: [
                      // Availability toggle
                      GestureDetector(
                        onTap: realIndex >= 0
                            ? () => _toggleAvailability(
                                realIndex,
                                itemId,
                                isAvailable,
                              )
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 36,
                              height: 20,
                              child: Switch.adaptive(
                                value: isAvailable,
                                onChanged: realIndex >= 0
                                    ? (v) => _toggleAvailability(
                                        realIndex,
                                        itemId,
                                        isAvailable,
                                      )
                                    : null,
                                activeColor: _accentColor,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              availLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isAvailable
                                    ? _accentColor
                                    : AppTheme.onSurfaceMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Edit button
                      InkWell(
                        onTap: () => _showAddEditDialog(item: item),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.edit_rounded,
                            size: 18,
                            color: _accentColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Delete button
                      InkWell(
                        onTap: () => _deleteItem(itemId, name),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Colors.red.shade400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _serviceIcon {
    switch (widget.serviceType) {
      case InventoryServiceType.kitchen:
        return Icons.restaurant_menu_rounded;
      case InventoryServiceType.laundry:
        return Icons.local_laundry_service_rounded;
      case InventoryServiceType.spa:
        return Icons.spa_rounded;
    }
  }

  Widget _buildItemChips(Map<String, dynamic> item) {
    switch (widget.serviceType) {
      case InventoryServiceType.kitchen:
        return _buildKitchenChips(item);
      case InventoryServiceType.laundry:
        return _buildLaundryChips(item);
      case InventoryServiceType.spa:
        return _buildSpaChips(item);
    }
  }

  Widget _buildKitchenChips(Map<String, dynamic> item) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (item['category'] != null)
          _chip('${item['category']}', Icons.category_rounded),
        if (item['is_veg'] != null)
          _chip(
            item['is_veg'] == true ? 'Veg' : 'Non-Veg',
            item['is_veg'] == true ? Icons.eco_rounded : Icons.no_food_rounded,
            color: item['is_veg'] == true ? Colors.green : Colors.red,
          ),
        if (item['prep_time'] != null)
          _chip('${item['prep_time']} min', Icons.timer_rounded),
        if (item['discount'] != null && (item['discount'] as num) > 0)
          _chip('${item['discount']}% off', Icons.local_offer_rounded),
        if (item['tag'] != null)
          _chip(
            '${item['tag']}',
            Icons.star_rounded,
            color: Colors.amber.shade700,
          ),
      ],
    );
  }

  Widget _buildLaundryChips(Map<String, dynamic> item) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (item['type_of_service'] != null)
          _chip('${item['type_of_service']}', Icons.category_rounded),
        if (item['expected_tat'] != null)
          _chip('TAT: ${item['expected_tat']}h', Icons.schedule_rounded),
        if (item['is_express_available'] == true)
          _chip(
            'Express: ₹${item['exp_price'] ?? '-'}',
            Icons.flash_on_rounded,
            color: Colors.orange,
          ),
        if (item['discount'] != null && (item['discount'] as num) > 0)
          _chip('${item['discount']}% off', Icons.local_offer_rounded),
      ],
    );
  }

  Widget _buildSpaChips(Map<String, dynamic> item) {
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        if (item['category'] != null)
          _chip('${item['category']}', Icons.category_rounded),
        if (item['duration_mins'] != null)
          _chip('${item['duration_mins']} min', Icons.timer_rounded),
        if (item['sort_order'] != null && (item['sort_order'] as int) > 0)
          _chip('Order: ${item['sort_order']}', Icons.sort_rounded),
      ],
    );
  }

  Widget _chip(String label, IconData icon, {Color? color}) {
    final c = color ?? _accentColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: c.withAlpha(18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withAlpha(40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: c),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialog for Add / Edit
// ─────────────────────────────────────────────────────────────────────────────

class _InventoryItemDialog extends StatefulWidget {
  final InventoryServiceType serviceType;
  final Map<String, dynamic>? existingItem;
  final Color accentColor;
  final Color accentContainer;
  final Future<void> Function(Map<String, dynamic> data) onSave;

  const _InventoryItemDialog({
    required this.serviceType,
    required this.existingItem,
    required this.accentColor,
    required this.accentContainer,
    required this.onSave,
  });

  @override
  State<_InventoryItemDialog> createState() => _InventoryItemDialogState();
}

class _InventoryItemDialogState extends State<_InventoryItemDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;

  // Common
  late TextEditingController _nameCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _imageUrlCtrl;

  // Kitchen
  late TextEditingController _mrpCtrl;
  late TextEditingController _discountCtrl;
  late TextEditingController _categoryCtrl;
  late TextEditingController _prepTimeCtrl;
  late TextEditingController _ratingCtrl;
  bool _isVeg = true;
  bool _inStock = true;
  String? _tag;

  // Laundry
  late TextEditingController _priceCtrl;
  late TextEditingController _laundryDiscountCtrl;
  late TextEditingController _typeOfServiceCtrl;
  late TextEditingController _expectedTatCtrl;
  late TextEditingController _expPriceCtrl;
  late TextEditingController _expTatCtrl;
  bool _isExpressAvailable = false;

  // Spa
  late TextEditingController _spaPriceCtrl;
  late TextEditingController _spaCategoryCtrl;
  late TextEditingController _durationMinsCtrl;
  late TextEditingController _sortOrderCtrl;
  bool _isAvailable = true;

  static const List<String> _kitchenTags = [
    'Best Seller',
    "Chef's Choice",
    "Today's Special",
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existingItem;

    _nameCtrl = TextEditingController(text: e?['name'] as String? ?? '');
    _descriptionCtrl = TextEditingController(
      text: e?['description'] as String? ?? '',
    );
    _imageUrlCtrl = TextEditingController(
      text: e?['image_url'] as String? ?? '',
    );

    // Kitchen
    _mrpCtrl = TextEditingController(
      text: e?['mrp'] != null ? '${e!['mrp']}' : '',
    );
    _discountCtrl = TextEditingController(
      text: e?['discount'] != null ? '${e!['discount']}' : '',
    );
    _categoryCtrl = TextEditingController(
      text: e?['category'] as String? ?? '',
    );
    _prepTimeCtrl = TextEditingController(
      text: e?['prep_time'] != null ? '${e!['prep_time']}' : '',
    );
    _ratingCtrl = TextEditingController(
      text: e?['rating'] != null ? '${e!['rating']}' : '',
    );
    _isVeg = e?['is_veg'] as bool? ?? true;
    _inStock = e?['in_stock'] as bool? ?? true;
    _tag = e?['tag'] as String?;

    // Laundry
    _priceCtrl = TextEditingController(
      text: e?['price'] != null ? '${e!['price']}' : '',
    );
    _laundryDiscountCtrl = TextEditingController(
      text: e?['discount'] != null ? '${e!['discount']}' : '',
    );
    _typeOfServiceCtrl = TextEditingController(
      text: e?['type_of_service'] as String? ?? '',
    );
    _expectedTatCtrl = TextEditingController(
      text: e?['expected_tat'] != null ? '${e!['expected_tat']}' : '',
    );
    _expPriceCtrl = TextEditingController(
      text: e?['exp_price'] != null ? '${e!['exp_price']}' : '',
    );
    _expTatCtrl = TextEditingController(
      text: e?['exp_tat'] != null ? '${e!['exp_tat']}' : '',
    );
    _isExpressAvailable = e?['is_express_available'] as bool? ?? false;

    // Spa
    _spaPriceCtrl = TextEditingController(
      text: e?['price'] != null ? '${e!['price']}' : '',
    );
    _spaCategoryCtrl = TextEditingController(
      text: e?['category'] as String? ?? '',
    );
    _durationMinsCtrl = TextEditingController(
      text: e?['duration_mins'] != null ? '${e!['duration_mins']}' : '',
    );
    _sortOrderCtrl = TextEditingController(
      text: e?['sort_order'] != null ? '${e!['sort_order']}' : '0',
    );
    _isAvailable = e?['is_available'] as bool? ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _imageUrlCtrl.dispose();
    _mrpCtrl.dispose();
    _discountCtrl.dispose();
    _categoryCtrl.dispose();
    _prepTimeCtrl.dispose();
    _ratingCtrl.dispose();
    _priceCtrl.dispose();
    _laundryDiscountCtrl.dispose();
    _typeOfServiceCtrl.dispose();
    _expectedTatCtrl.dispose();
    _expPriceCtrl.dispose();
    _expTatCtrl.dispose();
    _spaPriceCtrl.dispose();
    _spaCategoryCtrl.dispose();
    _durationMinsCtrl.dispose();
    _sortOrderCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildData() {
    switch (widget.serviceType) {
      case InventoryServiceType.kitchen:
        return {
          'name': _nameCtrl.text.trim(),
          'description': _descriptionCtrl.text.trim().isEmpty
              ? null
              : _descriptionCtrl.text.trim(),
          'image_url': _imageUrlCtrl.text.trim().isEmpty
              ? null
              : _imageUrlCtrl.text.trim(),
          'mrp': double.tryParse(_mrpCtrl.text.trim()),
          'discount': double.tryParse(_discountCtrl.text.trim()),
          'category': _categoryCtrl.text.trim().isEmpty
              ? null
              : _categoryCtrl.text.trim(),
          'prep_time': int.tryParse(_prepTimeCtrl.text.trim()),
          'rating': double.tryParse(_ratingCtrl.text.trim()),
          'is_veg': _isVeg,
          'in_stock': _inStock,
          'tag': _tag,
        };
      case InventoryServiceType.laundry:
        return {
          'name': _nameCtrl.text.trim(),
          'price': double.tryParse(_priceCtrl.text.trim()),
          'discount': double.tryParse(_laundryDiscountCtrl.text.trim()),
          'type_of_service': _typeOfServiceCtrl.text.trim().isEmpty
              ? null
              : _typeOfServiceCtrl.text.trim(),
          'expected_tat': int.tryParse(_expectedTatCtrl.text.trim()),
          'is_express_available': _isExpressAvailable,
          'exp_price': _isExpressAvailable
              ? double.tryParse(_expPriceCtrl.text.trim())
              : null,
          'exp_tat': _isExpressAvailable
              ? int.tryParse(_expTatCtrl.text.trim())
              : null,
        };
      case InventoryServiceType.spa:
        return {
          'name': _nameCtrl.text.trim(),
          'description': _descriptionCtrl.text.trim().isEmpty
              ? null
              : _descriptionCtrl.text.trim(),
          'image_url': _imageUrlCtrl.text.trim().isEmpty
              ? null
              : _imageUrlCtrl.text.trim(),
          'price': double.tryParse(_spaPriceCtrl.text.trim()) ?? 0,
          'category': _spaCategoryCtrl.text.trim().isEmpty
              ? null
              : _spaCategoryCtrl.text.trim(),
          'duration_mins': int.tryParse(_durationMinsCtrl.text.trim()),
          'is_available': _isAvailable,
          'sort_order': int.tryParse(_sortOrderCtrl.text.trim()) ?? 0,
        };
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    await widget.onSave(_buildData());
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingItem != null;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
              decoration: BoxDecoration(
                color: widget.accentContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2_rounded,
                    color: widget.accentColor,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isEdit ? 'Edit Item' : 'Add New Item',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: widget.accentColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Form
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Form(key: _formKey, child: _buildFormFields()),
              ),
            ),
            // Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: BorderSide(color: AppTheme.outline),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurfaceMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              isEdit ? 'Update' : 'Add Item',
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormFields() {
    switch (widget.serviceType) {
      case InventoryServiceType.kitchen:
        return _buildKitchenForm();
      case InventoryServiceType.laundry:
        return _buildLaundryForm();
      case InventoryServiceType.spa:
        return _buildSpaForm();
    }
  }

  Widget _buildKitchenForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(_nameCtrl, 'Item Name *', required: true),
        _field(_categoryCtrl, 'Category'),
        _field(
          _mrpCtrl,
          'MRP (₹) *',
          keyboardType: TextInputType.number,
          required: true,
        ),
        _field(
          _discountCtrl,
          'Discount (%)',
          keyboardType: TextInputType.number,
        ),
        _field(
          _prepTimeCtrl,
          'Prep Time (minutes)',
          keyboardType: TextInputType.number,
        ),
        _field(_ratingCtrl, 'Rating (0–5)', keyboardType: TextInputType.number),
        _field(_descriptionCtrl, 'Description', maxLines: 3),
        _field(_imageUrlCtrl, 'Image URL'),
        const SizedBox(height: 8),
        _switchRow('Vegetarian', _isVeg, (v) => setState(() => _isVeg = v)),
        _switchRow('In Stock', _inStock, (v) => setState(() => _inStock = v)),
        const SizedBox(height: 8),
        _label('Tag (optional)'),
        const SizedBox(height: 6),
        DropdownButtonFormField<String?>(
          initialValue: _tag,
          decoration: _inputDecoration('Select tag'),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            color: Colors.black87,
          ),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('None')),
            ..._kitchenTags.map(
              (t) => DropdownMenuItem<String?>(value: t, child: Text(t)),
            ),
          ],
          onChanged: (v) => setState(() => _tag = v),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildLaundryForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(_nameCtrl, 'Item Name *', required: true),
        _field(_typeOfServiceCtrl, 'Type of Service'),
        _field(
          _priceCtrl,
          'Price (₹) *',
          keyboardType: TextInputType.number,
          required: true,
        ),
        _field(
          _laundryDiscountCtrl,
          'Discount (%)',
          keyboardType: TextInputType.number,
        ),
        _field(
          _expectedTatCtrl,
          'Expected TAT (hours)',
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 8),
        _switchRow(
          'Express Available',
          _isExpressAvailable,
          (v) => setState(() => _isExpressAvailable = v),
        ),
        if (_isExpressAvailable) ...[
          _field(
            _expPriceCtrl,
            'Express Price (₹)',
            keyboardType: TextInputType.number,
          ),
          _field(
            _expTatCtrl,
            'Express TAT (hours)',
            keyboardType: TextInputType.number,
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSpaForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _field(_nameCtrl, 'Service Name *', required: true),
        _field(_spaCategoryCtrl, 'Category'),
        _field(
          _spaPriceCtrl,
          'Price (₹) *',
          keyboardType: TextInputType.number,
          required: true,
        ),
        _field(
          _durationMinsCtrl,
          'Duration (minutes)',
          keyboardType: TextInputType.number,
        ),
        _field(
          _sortOrderCtrl,
          'Sort Order',
          keyboardType: TextInputType.number,
        ),
        _field(_descriptionCtrl, 'Description', maxLines: 3),
        _field(_imageUrlCtrl, 'Image URL'),
        const SizedBox(height: 8),
        _switchRow(
          'Available',
          _isAvailable,
          (v) => setState(() => _isAvailable = v),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label),
          const SizedBox(height: 6),
          TextFormField(
            controller: ctrl,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: GoogleFonts.plusJakartaSans(fontSize: 14),
            decoration: _inputDecoration(label),
            validator: required
                ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                : null,
          ),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppTheme.onSurfaceMuted,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(
        color: AppTheme.onSurfaceMuted,
        fontSize: 13,
      ),
      filled: true,
      fillColor: const Color(0xFFF8F9FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppTheme.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: widget.accentColor, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  Widget _switchRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: widget.accentColor,
          ),
        ],
      ),
    );
  }
}
