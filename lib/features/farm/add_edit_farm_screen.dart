import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Add or edit farm screen.
class AddEditFarmScreen extends StatefulWidget {
  final String? farmId;

  const AddEditFarmScreen({super.key, this.farmId});

  @override
  State<AddEditFarmScreen> createState() => _AddEditFarmScreenState();
}

class _AddEditFarmScreenState extends State<AddEditFarmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _areaController = TextEditingController();
  final _cropController = TextEditingController();
  String _selectedSoilType = AppConstants.soilTypes.first;

  bool get isEditing => widget.farmId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _areaController.dispose();
    _cropController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Farm' : 'Add Farm'),
        actions: [
          TextButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(isEditing ? 'Farm updated' : 'Farm added successfully')),
                );
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
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
              keyboardType: TextInputType.number,
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
          ],
        ),
      ),
    );
  }
}
