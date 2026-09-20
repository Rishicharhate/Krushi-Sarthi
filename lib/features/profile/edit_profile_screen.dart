import 'package:flutter/material.dart';

/// Edit profile screen with form fields.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController(text: 'Rajesh Patil');
  final _mobileController = TextEditingController(text: '+91 98765 43210');
  final _villageController = TextEditingController(text: 'Shirpur');
  final _districtController = TextEditingController(text: 'Dhule');
  final _stateController = TextEditingController(text: 'Maharashtra');

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _villageController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Profile updated successfully')),
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
              decoration: const InputDecoration(labelText: 'Full Name', prefixIcon: Icon(Icons.person_rounded)),
              validator: (v) => (v == null || v.isEmpty) ? 'Please enter your name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _mobileController,
              decoration: const InputDecoration(labelText: 'Mobile Number', prefixIcon: Icon(Icons.phone_rounded)),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.isEmpty) ? 'Please enter your mobile number' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _villageController,
              decoration: const InputDecoration(labelText: 'Village', prefixIcon: Icon(Icons.location_on_rounded)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _districtController,
              decoration: const InputDecoration(labelText: 'District', prefixIcon: Icon(Icons.map_rounded)),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _stateController,
              decoration: const InputDecoration(labelText: 'State', prefixIcon: Icon(Icons.flag_rounded)),
            ),
          ],
        ),
      ),
    );
  }
}
