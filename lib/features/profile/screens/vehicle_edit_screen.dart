import 'package:chargenet_mobile/data/constants.dart';
import 'package:chargenet_mobile/data/enums/ev_connector_type.dart';
import 'package:chargenet_mobile/data/models.dart';
import 'package:chargenet_mobile/features/profile/widgets/vehicle_card_widget.dart';
import 'package:chargenet_mobile/services/api_service.dart';
import 'package:chargenet_mobile/services/app_state_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Add or edit one saved EV.
///
/// `vehicle == null` puts the screen in add mode; otherwise every field is
/// prefilled from the saved record and a delete action is offered.
class VehicleEditScreen extends StatefulWidget {
  const VehicleEditScreen({super.key, this.vehicle});

  final Vehicle? vehicle;

  /// At most three digits and one decimal — `250` is the largest legal value.
  static final RegExp batteryPattern = RegExp(r'^\d{0,3}(\.\d{0,1})?$');

  /// Plates are stored uppercase, so the field forces it while typing.
  static final TextInputFormatter plateFormatter =
      TextInputFormatter.withFunction(
        (oldValue, newValue) => newValue.copyWith(
          text: newValue.text.toUpperCase().replaceAll(
            RegExp(r'[^A-Z0-9 ]'),
            '',
          ),
        ),
      );

  /// Drops a keystroke that would make the capacity unparseable.
  static final TextInputFormatter batteryFormatter =
      TextInputFormatter.withFunction(
        (oldValue, newValue) =>
            newValue.text.isEmpty || batteryPattern.hasMatch(newValue.text)
            ? newValue
            : oldValue,
      );

  static String? validateName(String? value) =>
      (value ?? '').trim().isEmpty ? 'Enter a vehicle name' : null;

  static String? validatePlate(String? value) =>
      (value ?? '').trim().isEmpty ? 'Enter the license plate' : null;

  static String? validateBattery(String? value) {
    final capacity = double.tryParse((value ?? '').trim());
    if (capacity == null) return 'Enter the battery capacity';
    if (capacity < KConstants.minVehicleBatteryKwh ||
        capacity > KConstants.maxVehicleBatteryKwh) {
      return 'Enter a capacity between '
          '${KConstants.minVehicleBatteryKwh.toStringAsFixed(0)} and '
          '${KConstants.maxVehicleBatteryKwh.toStringAsFixed(0)} kWh';
    }
    return null;
  }

  /// Unknown/missing values fall back to `CCS2`, the Malaysian default.
  static EvConnectorType connectorFromApi(String? value) {
    if (value == null) return EvConnectorType.ccs2;
    try {
      return EvConnectorType.fromApi(value);
    } on ArgumentError {
      return EvConnectorType.ccs2;
    }
  }

  @override
  State<VehicleEditScreen> createState() => _VehicleEditScreenState();
}

class _VehicleEditScreenState extends State<VehicleEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _plateController;
  late final TextEditingController _batteryController;

  late EvConnectorType _connectorType;
  late bool _isDefault;

  bool _isBusy = false;
  String? _error;

  Vehicle? get _existing => widget.vehicle;

  bool get _isEditMode => _existing != null;

  @override
  void initState() {
    super.initState();
    final vehicle = widget.vehicle;
    _nameController = TextEditingController(text: vehicle?.name ?? '');
    _plateController = TextEditingController(text: vehicle?.licensePlate ?? '');
    _batteryController = TextEditingController(
      text: vehicle == null
          ? ''
          : VehicleCardWidget.capacityText(vehicle.batteryCapacity),
    );
    _connectorType = VehicleEditScreen.connectorFromApi(vehicle?.connectorType);
    _isDefault = vehicle?.isDefault ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    _batteryController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameController.text.trim();
    final plate = _plateController.text.trim().toUpperCase();
    final capacity = double.parse(_batteryController.text.trim());
    final existing = _existing;

    setState(() => _isBusy = true);
    try {
      // The server ignores `id`/`userId` on create and owns the
      // default-vehicle bookkeeping, so both are sent as-is.
      final service = AppStateService.instance;
      if (existing == null) {
        await service.createVehicle(
          Vehicle(
            id: '',
            userId: '',
            name: name,
            licensePlate: plate,
            connectorType: _connectorType.apiValue,
            batteryCapacity: capacity,
            isDefault: _isDefault,
          ),
        );
      } else {
        await service.updateVehicle(
          Vehicle(
            id: existing.id,
            userId: existing.userId,
            name: name,
            licensePlate: plate,
            connectorType: _connectorType.apiValue,
            batteryCapacity: capacity,
            isDefault: _isDefault,
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        // The API can report several fields at once (name *and* capacity), so
        // they are shown together instead of an arbitrary first one.
        _error = error.fields.isNotEmpty
            ? error.fields.values.join(' ')
            : error.message;
      });
    }
  }

  Future<void> _delete() async {
    final vehicle = _existing;
    if (vehicle == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete vehicle?'),
        content: Text('${vehicle.name} will be removed from your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await AppStateService.instance.deleteVehicle(vehicle.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditMode ? 'Edit vehicle' : 'Add vehicle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            TextFormField(
              controller: _nameController,
              enabled: !_isBusy,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Vehicle name',
                hintText: 'Tesla Model Y',
                prefixIcon: Icon(Icons.directions_car),
              ),
              validator: VehicleEditScreen.validateName,
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _plateController,
              enabled: !_isBusy,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: [VehicleEditScreen.plateFormatter],
              decoration: const InputDecoration(
                labelText: 'License plate',
                hintText: 'PCN1234',
                prefixIcon: Icon(Icons.subtitles_outlined),
              ),
              validator: VehicleEditScreen.validatePlate,
            ),
            const SizedBox(height: 18),
            DropdownMenu<EvConnectorType>(
              initialSelection: _connectorType,
              enabled: !_isBusy,
              expandedInsets: EdgeInsets.zero,
              label: const Text('Charging connector type'),
              onSelected: (type) {
                if (type != null) setState(() => _connectorType = type);
              },
              dropdownMenuEntries: [
                for (final EvConnectorType type in EvConnectorType.values)
                  DropdownMenuEntry<EvConnectorType>(
                    value: type,
                    label: type.displayName,
                  ),
              ],
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _batteryController,
              enabled: !_isBusy,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [VehicleEditScreen.batteryFormatter],
              decoration: const InputDecoration(
                labelText: 'Battery capacity',
                hintText: '75',
                suffixText: 'kWh',
                prefixIcon: Icon(Icons.battery_charging_full_outlined),
              ),
              validator: VehicleEditScreen.validateBattery,
            ),
            const SizedBox(height: 6),
            SwitchListTile(
              value: _isDefault,
              onChanged: _isBusy
                  ? null
                  : (value) => setState(() => _isDefault = value),
              title: const Text('Set as default vehicle'),
              subtitle: const Text('Used automatically when a session starts'),
              contentPadding: EdgeInsets.zero,
            ),
            if (_error != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _isBusy ? null : _save,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isBusy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save'),
            ),
            if (_isEditMode) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _delete,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete vehicle'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
