// Create/edit form for a development (obra nueva) at `/promocion-editar[/:id]`.
//
// Mirrors the agency's `AgencyProfileEditScreen` (Task 4) pattern: auth +
// verified-agency gate, prefill from the matching provider on edit, build a
// [DevelopmentInput], run [validateDevelopmentInput], call
// `createDevelopment`/`updateDevelopment`, invalidate the list/detail
// providers, SnackBar, pop. `_saving` disables Save + shows a spinner; every
// async gap is `mounted`-guarded so a popped screen never setState()s.
//
// Images are picked via [ImagePicker.pickMultiImage] and uploaded through
// `DevelopmentsService.uploadDevelopmentImages` (Task 8). Existing image URLs
// (edit mode) are merged with newly uploaded ones and per-image delete icons
// hide them from the form before the next save.
//
// Validation error mapping (Spanish) is parity-locked to the web's
// `developments.ts` and pinned by `agency_validation_test.dart`'s sibling
// `development_validation_test.dart` (Task 1). Lat/lng are taken as raw
// doubles — the supabase column is `double precision` and null is permitted.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/providers/selected_country_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../agency/data/agency_service.dart';
import '../../data/development_model.dart';
import '../../data/developments_service.dart';

class DevelopmentFormScreen extends ConsumerStatefulWidget {
  final String? developmentId;

  const DevelopmentFormScreen({super.key, this.developmentId});

  @override
  ConsumerState<DevelopmentFormScreen> createState() =>
      _DevelopmentFormScreenState();
}

class _DevelopmentFormScreenState extends ConsumerState<DevelopmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _promoterController = TextEditingController();
  final _countryCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _amenityController = TextEditingController();
  final _deliveryLabelController = TextEditingController();

  // Edit-mode state
  List<String> _existingImageUrls = [];
  bool _prefilled = false;

  // Mutable form state
  final List<String> _amenities = [];
  final List<String> _newImageUrls = [];

  String? _status;

  bool _saving = false;
  bool _uploadingImages = false;

  bool get _isEdit => widget.developmentId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _promoterController.dispose();
    _countryCodeController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _amenityController.dispose();
    _deliveryLabelController.dispose();
    super.dispose();
  }

  /// Populate controllers on edit. Idempotent — `_prefilled` keeps subsequent
  /// builds from clobbering the user's in-progress edits (same lesson as T4).
  void _prefillFromDevelopment(Development dev) {
    if (_prefilled) return;
    _nameController.text = dev.name;
    _descriptionController.text = dev.description ?? '';
    _promoterController.text = dev.promoterName ?? '';
    _countryCodeController.text = dev.countryCode;
    _cityController.text = dev.city ?? '';
    _addressController.text = dev.address ?? '';
    _latitudeController.text = dev.latitude?.toString() ?? '';
    _longitudeController.text = dev.longitude?.toString() ?? '';
    _deliveryLabelController.text = dev.deliveryLabel ?? '';
    _existingImageUrls = List.from(dev.images);
    _amenities
      ..clear()
      ..addAll(dev.amenities);
    _status = dev.status;
    _prefilled = true;
  }

  void _addAmenity() {
    final v = _amenityController.text.trim();
    if (v.isEmpty) return;
    setState(() {
      _amenities.add(v);
      _amenityController.clear();
    });
  }

  void _removeAmenity(int index) {
    setState(() => _amenities.removeAt(index));
  }

  Future<void> _pickAndUploadImages() async {
    if (_uploadingImages) return;
    final l10n = AppLocalizations.of(context)!;
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (!mounted) return;
    if (picked.isEmpty) return;

    setState(() => _uploadingImages = true);
    try {
      final urls = await ref
          .read(developmentsServiceProvider)
          .uploadDevelopmentImages(picked);
      if (!mounted) return;
      setState(() => _newImageUrls.addAll(urls));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.developmentFormUploadError(e.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploadingImages = false);
    }
  }

  void _removeExistingImage(int index) {
    setState(() => _existingImageUrls.removeAt(index));
  }

  void _removeNewImage(int index) {
    setState(() => _newImageUrls.removeAt(index));
  }

  String _errorMessage(DevelopmentValidationError error) {
    final l10n = AppLocalizations.of(context)!;
    switch (error) {
      case DevelopmentValidationError.name:
        return l10n.developmentFormErrorName;
      case DevelopmentValidationError.country:
        return l10n.developmentFormErrorCountry;
      case DevelopmentValidationError.status:
        return l10n.developmentFormErrorStatus;
      case DevelopmentValidationError.description:
        return l10n.developmentFormErrorDescription;
      case DevelopmentValidationError.length:
        return l10n.developmentFormErrorLength;
    }
  }

  String _statusLabel(BuildContext context, String s) {
    final l10n = AppLocalizations.of(context)!;
    switch (s) {
      case 'planning':
        return l10n.promocionStatusPlanning;
      case 'building':
        return l10n.promocionStatusBuilding;
      case 'ready':
        return l10n.promocionStatusReady;
    }
    return s;
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.read(authStateProvider);
    final userId = auth.value?.id;
    if (userId == null) return;

    // Coordinates — invalid (non-numeric) input surfaces inline below, not
    // here. Empty input is allowed.
    final latText = _latitudeController.text.trim();
    final lngText = _longitudeController.text.trim();
    final latParsed = latText.isEmpty ? null : double.tryParse(latText);
    final lngParsed = lngText.isEmpty ? null : double.tryParse(lngText);
    if (latText.isNotEmpty && latParsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.developmentFormLatInvalid),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (lngText.isNotEmpty && lngParsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.developmentFormLngInvalid),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final input = DevelopmentInput(
      name: _nameController.text,
      description: _descriptionController.text,
      promoterName: _promoterController.text,
      countryCode: _countryCodeController.text,
      city: _cityController.text,
      address: _addressController.text,
      deliveryLabel: _deliveryLabelController.text,
      status: _status,
      latitude: latParsed,
      longitude: lngParsed,
      amenities: _amenities,
      // Merge existing (kept) + newly uploaded URLs. Cap at 12 to keep the
      // payload reasonable — web form doesn't enforce a hard limit but the
      // detail gallery is most useful with a handful of photos.
      images: [..._existingImageUrls, ..._newImageUrls],
    );

    final err = validateDevelopmentInput(input);
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
      final service = ref.read(developmentsServiceProvider);
      final outcome = _isEdit
          ? await service.updateDevelopment(widget.developmentId!, input)
          : await service.createDevelopment(input);

      if (!mounted) return;
      if (!outcome.ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.developmentFormSaveFailed),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      ref.invalidate(myDevelopmentsProvider);
      if (_isEdit) {
        ref.invalidate(developmentDetailProvider(widget.developmentId!));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? l10n.developmentFormSavedUpdated
                : l10n.developmentFormSavedCreated,
          ),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.developmentFormSaveException(e.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final auth = ref.watch(authStateProvider);
    final userId = auth.when(
      loading: () => null,
      error: (_, _) => null,
      data: (u) => u?.id,
    );

    if (userId == null) {
      return const _NotSignedInScaffold();
    }

    final profileAsync = ref.watch(myAgencyProfileProvider);

    return profileAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(l10n.commonErrorWithMessage(e.toString())),
        ),
      ),
      data: (profile) {
        if (profile == null || !profile.isVerified) {
          return const _NotVerifiedScaffold();
        }

        // Default country code once the provider resolves. Doing it here (not
        // in initState) means we don't depend on selectedCountryProvider
        // before the first frame.
        if (_countryCodeController.text.isEmpty) {
          _countryCodeController.text =
              ref.read(selectedCountryProvider).code.toUpperCase();
        }

        if (_isEdit) {
          return _buildEditScaffold();
        }
        return _buildCreateScaffold();
      },
    );
  }

  Widget _buildCreateScaffold() {
    return Scaffold(
      appBar: _appBar(),
      body: _form(),
    );
  }

  Widget _buildEditScaffold() {
    final l10n = AppLocalizations.of(context)!;
    final detailAsync =
        ref.watch(developmentDetailProvider(widget.developmentId!));
    return Scaffold(
      appBar: _appBar(),
      body: detailAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    size: 48, color: AppColors.error),
                const SizedBox(height: 8),
                Text(
                  l10n.developmentFormLoadError(e.toString()),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(
                    developmentDetailProvider(widget.developmentId!),
                  ),
                  child: Text(l10n.commonRetry),
                ),
              ],
            ),
          ),
        ),
        data: (dev) {
          if (dev == null) {
            return Center(child: Text(l10n.developmentFormNotFound));
          }
          // First successful resolve — seed controllers.
          if (!_prefilled) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() => _prefillFromDevelopment(dev));
            });
          }
          return _form();
        },
      ),
    );
  }

  PreferredSizeWidget _appBar() {
    final l10n = AppLocalizations.of(context)!;
    return AppBar(
      title: Text(_isEdit
          ? l10n.developmentFormEdit
          : l10n.developmentFormNew),
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios),
        onPressed: () => context.pop(),
      ),
    );
  }

  Widget _form() {
    final l10n = AppLocalizations.of(context)!;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.developmentFormFieldName,
              prefixIcon: const Icon(Icons.apartment_outlined),
            ),
            maxLength: 140,
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.length < 2 || t.length > 140) {
                return l10n.developmentFormNameValidator;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            maxLines: 5,
            minLines: 3,
            decoration: InputDecoration(
              labelText: l10n.developmentFormFieldDescription,
              alignLabelWithHint: true,
            ),
            maxLength: 5000,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _promoterController,
            decoration: InputDecoration(
              labelText: l10n.developmentFormFieldPromoter,
              prefixIcon: const Icon(Icons.business_outlined),
            ),
            maxLength: 140,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _countryCodeController,
            decoration: InputDecoration(
              labelText: l10n.developmentFormFieldCountry,
              prefixIcon: const Icon(Icons.flag_outlined),
              hintText: l10n.developmentFormCountryHint,
            ),
            textCapitalization: TextCapitalization.characters,
            maxLength: 5,
            onChanged: (v) {
              // Auto-uppercase so the user can type "es" and still pass
              // validation. `setState` is cheap here.
              final upper = v.toUpperCase();
              if (upper != v) {
                _countryCodeController.value = TextEditingValue(
                  text: upper,
                  selection: TextSelection.collapsed(offset: upper.length),
                );
              }
            },
            validator: (v) {
              final t = (v ?? '').trim();
              if (t.length < 2 || t.length > 5) {
                return l10n.developmentFormCountryValidator;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _cityController,
            decoration: InputDecoration(
              labelText: l10n.developmentFormFieldCity,
              prefixIcon: const Icon(Icons.location_city_outlined),
            ),
            maxLength: 120,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _addressController,
            decoration: InputDecoration(
              labelText: l10n.developmentFormFieldAddress,
              prefixIcon: const Icon(Icons.place_outlined),
            ),
            maxLength: 240,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _latitudeController,
                  decoration: InputDecoration(
                    labelText: l10n.developmentFormFieldLat,
                    prefixIcon: const Icon(Icons.my_location),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    if (double.tryParse(t) == null) {
                      return l10n.developmentFormNumericInvalid;
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _longitudeController,
                  decoration: InputDecoration(
                    labelText: l10n.developmentFormFieldLng,
                    prefixIcon: const Icon(Icons.my_location),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    if (double.tryParse(t) == null) {
                      return l10n.developmentFormNumericInvalid;
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amenityController,
            decoration: InputDecoration(
              labelText: l10n.developmentFormFieldAmenityLabel,
              hintText: l10n.developmentFormFieldAmenityHint,
              prefixIcon: const Icon(Icons.local_activity_outlined),
            ),
            onFieldSubmitted: (_) => _addAmenity(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _addAmenity,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.developmentFormAddAmenity),
            ),
          ),
          if (_amenities.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var i = 0; i < _amenities.length; i++)
                  InputChip(
                    label: Text(_amenities[i]),
                    onDeleted: () => _removeAmenity(i),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          Text(
            l10n.developmentFormImagesHeading,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _uploadingImages ? null : _pickAndUploadImages,
            icon: _uploadingImages
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_photo_alternate_outlined, size: 18),
            label: Text(
              _uploadingImages
                  ? l10n.developmentFormUploading
                  : l10n.developmentFormAddImages,
            ),
          ),
          if (_existingImageUrls.isNotEmpty || _newImageUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ImageGrid(
              existingUrls: _existingImageUrls,
              newUrls: _newImageUrls,
              onRemoveExisting: _removeExistingImage,
              onRemoveNew: _removeNewImage,
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _deliveryLabelController,
            decoration: InputDecoration(
              labelText: l10n.developmentFormFieldDelivery,
              hintText: l10n.developmentFormDeliveryHint,
              prefixIcon: const Icon(Icons.event_outlined),
            ),
            maxLength: 60,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: InputDecoration(
              labelText: l10n.developmentFormFieldStatus,
              prefixIcon: const Icon(Icons.timeline_outlined),
            ),
            items: [
              for (final s in DEVELOPMENT_STATUSES)
                DropdownMenuItem(
                  value: s,
                  child: Text(_statusLabel(context, s)),
                ),
            ],
            onChanged: (v) => setState(() => _status = v),
            validator: (v) {
              if (v == null) return null;
              if (!DEVELOPMENT_STATUSES.contains(v)) {
                return l10n.developmentFormStatusInvalid;
              }
              return null;
            },
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
                : Text(_isEdit
                    ? l10n.commonSave
                    : l10n.developmentFormSubmitCreate),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _ImageGrid extends StatelessWidget {
  final List<String> existingUrls;
  final List<String> newUrls;
  final void Function(int index) onRemoveExisting;
  final void Function(int index) onRemoveNew;

  const _ImageGrid({
    required this.existingUrls,
    required this.newUrls,
    required this.onRemoveExisting,
    required this.onRemoveNew,
  });

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];
    for (var i = 0; i < existingUrls.length; i++) {
      tiles.add(_thumb(existingUrls[i], () => onRemoveExisting(i)));
    }
    for (var i = 0; i < newUrls.length; i++) {
      tiles.add(_thumb(newUrls[i], () => onRemoveNew(i)));
    }

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: tiles,
    );
  }

  Widget _thumb(String url, VoidCallback onRemove) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: AppColors.shimmer,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (context, url, error) => Container(
              color: AppColors.shimmer,
              child: const Icon(Icons.broken_image_outlined),
            ),
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onRemove,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NotSignedInScaffold extends StatelessWidget {
  const _NotSignedInScaffold();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.developmentFormTitle),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
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
              Text(
                l10n.developmentFormNotSignedInTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
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
                child: Text(l10n.developmentFormNotSignedInCta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotVerifiedScaffold extends StatelessWidget {
  const _NotVerifiedScaffold();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.developmentFormTitle),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.verified_outlined,
                size: 56,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.developmentFormNotVerifiedTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.developmentFormNotVerifiedSubtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.push(AppRoutes.agencyEdit),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(l10n.developmentFormNotVerifiedCta),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
