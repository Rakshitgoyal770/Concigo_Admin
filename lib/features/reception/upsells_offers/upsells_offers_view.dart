import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/widgets/luxury_button.dart';
import 'widgets/create_offer_dialog.dart';
import 'widgets/create_early_checkin_dialog.dart';
import 'widgets/create_late_checkout_dialog.dart';
import 'widgets/room_upgrades_tab.dart';
import 'widgets/early_checkin_tab.dart';
import 'widgets/late_checkout_tab.dart';
import 'widgets/active_offers_tab.dart';

class UpsellsOffersView extends ConsumerStatefulWidget {
  const UpsellsOffersView({super.key});

  @override
  ConsumerState<UpsellsOffersView> createState() => _UpsellsOffersViewState();
}

class _UpsellsOffersViewState extends ConsumerState<UpsellsOffersView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 650;

        return SingleChildScrollView(
          padding: EdgeInsets.all(isMobile ? AppSpacing.md : AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Upsells & In-Stay Offers', style: AppTypography.titleLarge.copyWith(fontSize: 20)),
                    AppSpacing.gapV4,
                    Text('Upgrades, Early/Late passes & packages', style: AppTypography.bodySmall),
                    AppSpacing.gapV12,
                    Row(
                      children: [
                        Expanded(
                          child: LuxuryButton(
                            text: '+ Early In',
                            variant: LuxuryButtonVariant.secondary,
                            icon: Icons.login_rounded,
                            onPressed: () {
                              showDialog(context: context, builder: (_) => const CreateEarlyCheckinDialog());
                            },
                          ),
                        ),
                        AppSpacing.gapH8,
                        Expanded(
                          child: LuxuryButton(
                            text: '+ Late Out',
                            variant: LuxuryButtonVariant.secondary,
                            icon: Icons.logout_rounded,
                            onPressed: () {
                              showDialog(context: context, builder: (_) => const CreateLateCheckoutDialog());
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Upsells, Upgrades & In-Stay Offers', style: AppTypography.titleLarge),
                          AppSpacing.gapV4,
                          Text('Manage room category upgrades, early check-in rates, late check-out privileges & promotional packages', style: AppTypography.bodySmall),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        LuxuryButton(
                          text: '+ Early Check-In',
                          variant: LuxuryButtonVariant.secondary,
                          icon: Icons.login_rounded,
                          onPressed: () {
                            showDialog(context: context, builder: (_) => const CreateEarlyCheckinDialog());
                          },
                        ),
                        AppSpacing.gapH12,
                        LuxuryButton(
                          text: '+ Late Check-Out',
                          variant: LuxuryButtonVariant.secondary,
                          icon: Icons.logout_rounded,
                          onPressed: () {
                            showDialog(context: context, builder: (_) => const CreateLateCheckoutDialog());
                          },
                        ),
                        AppSpacing.gapH12,
                        LuxuryButton(
                          text: '+ New Package',
                          variant: LuxuryButtonVariant.primary,
                          icon: Icons.add,
                          onPressed: () {
                            showDialog(context: context, builder: (_) => const CreateOfferDialog());
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              AppSpacing.gapV24,

              Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppSpacing.roundedSm,
                  border: Border(bottom: BorderSide(color: AppColors.border, width: 0.8)),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: isMobile,
                  tabAlignment: isMobile ? TabAlignment.start : TabAlignment.fill,
                  indicatorColor: AppColors.primary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: AppTypography.labelMedium.copyWith(fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'Room Upgrades'),
                    Tab(text: 'Early Check-In'),
                    Tab(text: 'Late Check-Out'),
                    Tab(text: 'Promotions & Deals'),
                  ],
                ),
              ),
              AppSpacing.gapV20,

              SizedBox(
                height: 600,
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    RoomUpgradesTab(),
                    EarlyCheckinTab(),
                    LateCheckoutTab(),
                    ActiveOffersTab(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

