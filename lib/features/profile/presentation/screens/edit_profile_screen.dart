import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/models/country_model.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/listing_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  // Avatar upload state. `_pickedAvatarBytes` is the just-picked image shown
  // immediately (before the upload round-trip finishes); `_avatarUrl` is the
  // persisted URL — pre-filled from the current user and updated once the
  // upload succeeds. Only `_avatarUrl` is sent to `updateUserProfile`.
  Uint8List? _pickedAvatarBytes;
  String? _avatarUrl;
  bool _avatarUploading = false;

  Country? _selectedCountry;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  void _loadUserData() {
    final userAsync = ref.read(currentUserProvider);
    userAsync.whenData((user) {
      if (user != null) {
        _nameController.text = user.name ?? '';
        _phoneController.text = user.phone ?? '';
        _emailController.text = user.email;
        _avatarUrl = user.avatarUrl;
        _selectedCountry = _countryForCode(user.countryCode);
      }
    });
  }

  Country? _countryForCode(String? code) {
    if (code == null) return null;
    for (final country in Country.defaultCountries) {
      if (country.code == code) return country;
    }
    return null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  ImageProvider? get _avatarImageProvider {
    if (_pickedAvatarBytes != null) return MemoryImage(_pickedAvatarBytes!);
    final url = _avatarUrl;
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImageProvider(url);
    }
    return null;
  }

  Future<void> _pickAndUploadAvatar() async {
    if (_avatarUploading) return;
    final l10n = AppLocalizations.of(context)!;
    final userId = ref.read(authServiceProvider).currentUser?.id;
    if (userId == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (!mounted || picked == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedAvatarBytes = bytes;
      _avatarUploading = true;
    });

    try {
      final urls = await ref
          .read(listingServiceProvider)
          .uploadImages(userId, [bytes]);
      if (!mounted) return;
      setState(() {
        _avatarUrl = urls.first;
      });
    } catch (e) {
      // Upload failure is non-blocking: the rest of the form still saves.
      // The locally picked bytes stay visible as a preview even though they
      // were never persisted.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.editProfileAvatarUploadFailed),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _avatarUploading = false);
    }
  }

  Future<void> _pickCountry() async {
    final selected = await showModalBottomSheet<Country>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _CountryPickerSheet(selected: _selectedCountry),
    );
    if (selected != null && mounted) {
      setState(() => _selectedCountry = selected);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;

    setState(() => _isLoading = true);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.updateUserProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        avatarUrl: _avatarUrl,
        countryCode: _selectedCountry?.code,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.editProfileSaved),
            backgroundColor: AppColors.success,
          ),
        );
        ref.invalidate(currentUserProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.commonErrorWithMessage(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.editProfileTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Avatar
            Center(
              child: GestureDetector(
                onTap: _avatarUploading ? null : _pickAndUploadAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: _avatarImageProvider == null
                            ? AppColors.foxGradient
                            : null,
                        shape: BoxShape.circle,
                        image: _avatarImageProvider != null
                            ? DecorationImage(
                                image: _avatarImageProvider!,
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _avatarImageProvider == null
                          ? const Center(
                              child: Text('🦊', style: TextStyle(fontSize: 50)),
                            )
                          : null,
                    ),
                    if (_avatarUploading)
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black38,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                l10n.editProfileAvatarHint,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Email (read-only)
            TextFormField(
              controller: _emailController,
              enabled: false,
              decoration: InputDecoration(
                labelText: l10n.editProfileEmailLabel,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.editProfileNameLabel,
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.editProfileNameRequired;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phone
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.editProfilePhoneLabel,
                hintText: l10n.editProfilePhoneHint,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Country
            InkWell(
              onTap: _pickCountry,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: l10n.editProfileCountryLabel,
                  prefixIcon: const Icon(Icons.public_outlined),
                ),
                child: Row(
                  children: [
                    if (_selectedCountry != null) ...[
                      Text(
                        _selectedCountry!.flag,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(_selectedCountry?.name ?? ''),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(l10n.editProfileSaveChanges),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet listing [Country.defaultCountries] for the edit-profile
/// country selector. Kept local to this file — unlike
/// `CountrySelectionScreen` (the app-wide `/select-country` screen backed by
/// `countriesProvider`'s Supabase round-trip), this picker only needs a
/// static list to choose a value for the form, so it avoids the network
/// dependency entirely.
class _CountryPickerSheet extends StatelessWidget {
  const _CountryPickerSheet({required this.selected});

  final Country? selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final countries = Country.defaultCountries;
    return SafeArea(
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.editProfileCountryLabel,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: countries.length,
                itemBuilder: (context, index) {
                  final country = countries[index];
                  final isSelected = country.code == selected?.code;
                  return ListTile(
                    leading: Text(
                      country.flag,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(country.name),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppColors.primary)
                        : null,
                    onTap: () => Navigator.of(context).pop(country),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
