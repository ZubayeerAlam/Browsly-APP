import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/busy_button.dart';
import '../../../../core/widgets/failure_banner.dart';
import '../providers/profile_provider.dart';
import '../widgets/profile_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    final profile = context.read<ProfileProvider>().profile;
    _name = TextEditingController(text: profile?.fullName ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final provider = context.read<ProfileProvider>();
    final photo = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 80,
      // Asks for no extra photo permissions. Location data is removed later,
      // by the provider, because this setting alone does not remove it.
      requestFullMetadata: false,
    );
    if (photo == null) return;
    await provider.updateAvatar(await photo.readAsBytes());
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final saved = await context.read<ProfileProvider>().updateName(
      _name.text.trim(),
    );
    if (saved && mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ProfileProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              FailureBanner(failure: provider.saveFailure),
              ProfileAvatar(url: provider.profile?.avatarUrl, radius: 52),
              TextButton.icon(
                onPressed: provider.isSaving ? null : _pickPhoto,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Change photo'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                validator: Validators.name,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              const SizedBox(height: 24),
              BusyButton(
                label: 'Save',
                isBusy: provider.isSaving,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
