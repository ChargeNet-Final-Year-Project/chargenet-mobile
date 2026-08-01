import 'package:chargenet_mobile/data/load_state.dart';
import 'package:chargenet_mobile/widgets/data_slice.dart';
import 'package:chargenet_mobile/core/typography.dart';
import 'package:chargenet_mobile/core/layout.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/data/notifiers.dart';
import 'package:chargenet_mobile/features/profile/screens/vehicle_edit_screen.dart';
import 'package:chargenet_mobile/features/profile/widgets/user_info_card_widget.dart';
import 'package:chargenet_mobile/features/profile/widgets/vehicle_card_widget.dart';
import 'package:chargenet_mobile/features/profile/widgets/wallet_card_widget.dart';
import 'package:chargenet_mobile/services/app_state_service.dart';
import 'package:flutter/material.dart';

/// The profile tab: user card → wallet → vehicles → sign out
///.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          // Pull-to-refresh re-reads every user-scoped slice.
          onRefresh: AppStateService.instance.refreshAll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pageInset,
              vertical: AppSpacing.section,
            ),
            children: [
              const UserInfoCardWidget(),
              const SizedBox(height: AppSpacing.group),
              const WalletCardWidget(),
              const SizedBox(height: AppSpacing.section),
              const _SectionHeader('My Vehicles'),
              const SizedBox(height: AppSpacing.related),
              DataSlice(
                state: vehiclesLoadNotifier,
                label: 'vehicles',
                onRetry: AppStateService.instance.refreshVehicles,
                child: const _VehiclesSection(),
              ),
              const SizedBox(height: AppSpacing.section),
              Center(
                child: TextButton.icon(
                  onPressed: AppStateService.instance.signOut,
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: AppTypography.sectionTitle);
  }
}

/// "My Vehicles" — the saved EVs, plus an add button and an empty state
///.
class _VehiclesSection extends StatelessWidget {
  const _VehiclesSection();

  void _addVehicle(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const VehicleEditScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Vehicle>>(
      valueListenable: vehiclesNotifier,
      builder: (context, vehicles, child) {
        if (vehicles.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(
                    Icons.directions_car_outlined,
                    size: 34,
                    color: Colors.black26,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Add your EV to get compatible chargers',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Connector standard and battery size pick the right charger '
                    'for every session.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _addVehicle(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add vehicle'),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: [
            for (final vehicle in vehicles)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: VehicleCardWidget(vehicle: vehicle),
              ),
            OutlinedButton.icon(
              onPressed: () => _addVehicle(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add vehicle'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
