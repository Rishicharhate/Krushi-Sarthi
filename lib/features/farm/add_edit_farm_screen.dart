import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/models/farm.dart';

/// Add or edit farm screen.
class AddEditFarmScreen extends ConsumerStatefulWidget {
  final String? farmId;

  const AddEditFarmScreen({super.key, this.farmId});

  @override
  ConsumerState<AddEditFarmScreen> createState() => _AddEditFarmScreenState();
}

class _AddEditFarmScreenState extends ConsumerState<AddEditFarmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _areaController = TextEditingController();
  final _cropController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  String _selectedSoilType = AppConstants.soilTypes.first;
  DateTime? _sowingDate;
  bool _isActive = false;
  bool _saving = false;
  bool _prefilled = false;

  bool get isEditing => widget.farmId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _areaController.dispose();
    _cropController.dispose();
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }

  void _prefillFrom(Farm farm) {
    _nameController.text = farm.name;
    _locationController.text = farm.location ?? '';
    _areaController.text = farm.area.toString();
    _cropController.text = farm.crop;
    _latController.text = farm.latitude?.toString() ?? '';
    _lonController.text = farm.longitude?.toString() ?? '';
    _selectedSoilType = farm.soilType ?? AppConstants.soilTypes.first;
    _sowingDate = farm.sowingDate;
    _isActive = farm.isActive;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final lat = _latController.text.trim().isEmpty ? null : double.tryParse(_latController.text.trim());
    final lon = _lonController.text.trim().isEmpty ? null : double.tryParse(_lonController.text.trim());

    final farm = Farm(
      id: widget.farmId ?? '',
      name: _nameController.text.trim(),
      location: _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      area: double.tryParse(_areaController.text.trim()) ?? 0,
      crop: _cropController.text.trim(),
      soilType: _selectedSoilType,
      sowingDate: _sowingDate,
      isActive: _isActive,
      latitude: lat,
      longitude: lon,
    );

    setState(() => _saving = true);
    try {
      final repo = ref.read(farmsRepositoryProvider);
      if (isEditing) {
        await repo.updateFarm(farm);
      } else {
        await repo.createFarm(farm);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEditing ? 'Farm updated' : 'Farm added successfully')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save farm: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Prefill once, when editing and the farm data has arrived.
    if (isEditing && !_prefilled) {
      final farms = ref.watch(farmsProvider).asData?.value;
      final farm = farms?.where((f) => f.id == widget.farmId).firstOrNull;
      if (farm != null) {
        _prefillFrom(farm);
        _prefilled = true;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Farm' : 'Add Farm'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Farm Name', prefixIcon: Icon(Icons.grass_rounded)),
              validator: (v) => (v == null || v.isEmpty) ? 'Please enter farm name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location', prefixIcon: Icon(Icons.location_on_rounded)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _areaController,
              decoration: const InputDecoration(labelText: 'Area (Acres)', prefixIcon: Icon(Icons.straighten_rounded)),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) => (v == null || v.isEmpty) ? 'Please enter area' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cropController,
              decoration: const InputDecoration(labelText: 'Crop', prefixIcon: Icon(Icons.eco_rounded)),
              validator: (v) => (v == null || v.isEmpty) ? 'Please enter crop name' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedSoilType,
              decoration: const InputDecoration(labelText: 'Soil Type', prefixIcon: Icon(Icons.terrain_rounded)),
              items: AppConstants.soilTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (v) => setState(() => _selectedSoilType = v ?? AppConstants.soilTypes.first),
            ),
            const SizedBox(height: 24),
            Text('Location coordinates', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              'Needed for real weather, soil and satellite data. Find these by long-pressing '
              'your field on Google Maps and copying the numbers shown.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _latController,
                    decoration: const InputDecoration(labelText: 'Latitude', hintText: 'e.g. 21.32'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final parsed = double.tryParse(v.trim());
                      if (parsed == null || parsed < -90 || parsed > 90) return 'Invalid latitude';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lonController,
                    decoration: const InputDecoration(labelText: 'Longitude', hintText: 'e.g. 74.88'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return null;
                      final parsed = double.tryParse(v.trim());
                      if (parsed == null || parsed < -180 || parsed > 180) return 'Invalid longitude';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Set as active farm'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
