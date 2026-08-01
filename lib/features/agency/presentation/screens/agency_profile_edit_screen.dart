// Edit screen for the caller's own agency profile at `/agencia/editar` (Task 4
// of the B2B/agency sprint). Auth-gated, prefill from `myAgencyProfileProvider`,
// write side of T2's `upsertAgencyProfile` + `uploadAgencyLogo`. Mirrors the
// web's `agency.ts` edit panel: name/description/website/phone/location fields
// + logo picker. NEVER writes `is_verified` (admin-only).

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/agency_model.dart';
import '../../data/agency_service.dart';

class AgencyProfileEditScreen extends ConsumerStatefulWidget {
  const AgencyProfileEditScreen({super.key});

  @override
  ConsumerState<AgencyProfileEditScreen> createState() =>
      _AgencyProfileEditScreenState();
}

class _AgencyProfileEditScreenState
    extends ConsumerState<AgencyProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();

  String? _logoUrl;
  bool _prefilled = false;
  bool _saving = false;
  bool _uploadingLogo = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  /// Populate controllers the first time the profile resolves. Idempotent —
  /// `setState(_prefilled = true)` keeps subsequent builds from clobbering the
  /// user's in-progress edits.
  void _prefillFromProfile(AgencyProfile? profile) {
    if (_prefilled || profile == null) return;
    _nameController.text = profile.name;
    _descriptionController.text = profile.description ?? '';
    _websiteController.text = profile.website ?? '';
    _phoneController.text = profile.phone ?? '';
    _locationController.text = profile.location ?? '';
    _logoUrl = profile.logoUrl;
    _prefilled = true;
  }

  Future<void> _pickAndUploadLogo() async {
    if (_uploadingLogo) return;
    final auth = ref.read(authStateProvider);
    final user = auth.value?.id;
    if (user == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _uploadingLogo = true);
    try {
      final url = await ref
          .read(agencyServiceProvider)
          .uploadAgencyLogo(user, picked);
      if (!mounted) return;
      setState(() => _logoUrl = url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir el logo: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingLogo = false);
    }
  }

  String _errorMessage(AgencyValidationError error) {
    switch (error) {
      case AgencyValidationError.name:
        return 'Introduce un nombre (2–120 caracteres).';
      case AgencyValidationError.website:
        return 'La web debe empezar por http:// o https://';
      case AgencyValidationError.length:
        return 'Uno de los campos supera la longitud máxima';
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final auth = ref.read(authStateProvider);
    final userId = auth.value?.id;
    if (userId == null) return;

    final input = AgencyInput(
      name: _nameController.text,
      logoUrl: _logoUrl,
      description: _descriptionController.text,
      website: _websiteController.text,
      phone: _phoneController.text,
      location: _locationController.text,
    );

    final err = validateAgencyInput(input);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage(err)),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(agencyServiceProvider)
          .upsertAgencyProfile(userId, input);
      if (!mounted) return;
      ref.invalidate(myAgencyProfileProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Perfil de agencia guardado'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final userId = auth.when(
      loading: () => null,
      error: (_, _) => null,
      data: (u) => u?.id,
    );

    if (userId == null) {
      return _NotSignedInScaffold();
    }

    final profileAsync = ref.watch(myAgencyProfileProvider);

    // Resolve prefill as soon as the profile is loaded. Wrapped in a
    // post-frame callback so controllers mutate after build.
    final profile = profileAsync.value;
    if (!_prefilled && profile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _prefillFromProfile(profile));
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar agencia'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.error,
                ),
                const SizedBox(height: 8),
                Text(
                  'No se pudo cargar la agencia: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(myAgencyProfileProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
        data: (_) => _form(context),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _LogoSection(
            logoUrl: _logoUrl,
            uploading: _uploadingLogo,
            onPick: _pickAndUploadLogo,
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Nombre *',
              prefixIcon: Icon(Icons.business_outlined),
            ),
            maxLength: 120,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            minLines: 3,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              alignLabelWithHint: true,
              hintText: 'Cuéntales a tus clientes quién eres',
            ),
            maxLength: 2000,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _websiteController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'Web',
              prefixIcon: Icon(Icons.link),
              hintText: 'https://...',
            ),
            maxLength: 300,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
            maxLength: 40,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'Ubicación',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            maxLength: 200,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _LogoSection extends StatelessWidget {
  final String? logoUrl;
  final bool uploading;
  final VoidCallback onPick;

  const _LogoSection({
    required this.logoUrl,
    required this.uploading,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: SizedBox(
                width: 96,
                height: 96,
                child: (logoUrl != null && logoUrl!.trim().isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: logoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        errorWidget: (context, url, error) =>
                            const Icon(
                          Icons.business,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.business,
                        size: 40,
                        color: AppColors.primary,
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: uploading ? null : onPick,
            icon: uploading
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.camera_alt_outlined, size: 18),
            label: Text(uploading ? 'Subiendo…' : 'Cambiar logo'),
          ),
        ],
      ),
    );
  }
}

class _NotSignedInScaffold extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar agencia'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 56,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Inicia sesión para editar tu agencia',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.login),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Inicia sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
