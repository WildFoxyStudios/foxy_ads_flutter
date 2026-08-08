import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'dart:io';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/models/category_model.dart';
import '../../../../core/models/country_model.dart';
import '../../../../core/models/listing_model.dart';
import '../../../../core/services/listing_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/country_service.dart';
import '../../../../core/router/app_router.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../real-estate/presentation/widgets/re_attribute_form.dart';
import '../../../real-estate/presentation/widgets/location_picker_map.dart';
import '../../../jobs/presentation/widgets/jobs_attribute_form.dart';
import 'listing_detail_screen.dart' show listingDetailProvider;
import '../../../profile/presentation/screens/my_listings_screen.dart'
    show myListingsProvider;

// Provider para categorías en crear anuncio
final createListingCategoriesProvider = FutureProvider<List<Category>>((
  ref,
) async {
  final listingService = ref.read(listingServiceProvider);
  return await listingService.getCategories();
});

class CreateListingScreen extends ConsumerStatefulWidget {
  final Listing? existing;

  const CreateListingScreen({super.key, this.existing});

  @override
  ConsumerState<CreateListingScreen> createState() =>
      _CreateListingScreenState();
}

class _CreateListingScreenState extends ConsumerState<CreateListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();

  Category? _selectedCategory;
  String? _subcategoryId;
  List<XFile> _selectedImages = [];
  bool _isNegotiable = false;
  bool _isLoading = false;

  // Real-estate specific attributes. Populated by `ReAttributeForm.onChanged`
  // when the user picks the real_estate category. Injected into the create
  // / edit payload via `updates['attributes']` at submit time.
  Map<String, dynamic>? _reAttributes;

  // Whether the RE form's required fields (operation, property_type, m2,
  // rooms, bathrooms) are all set. Only consulted when the selected category
  // is real_estate (see `_submitListing`); defaults to false so a listing
  // can never publish with an incomplete RE payload before the form's first
  // post-frame `onValidityChanged` callback fires.
  bool _reAttributesValid = false;

  // Jobs-specific attributes. Populated by `JobsAttributeForm.onChanged`
  // when the user picks the jobs category. Injected into the create / edit
  // payload via `updates['attributes']` at submit time. Mutually exclusive
  // with `_reAttributes` — the category dropdown clears whichever branch is
  // no longer selected, so a listing never carries cross-category keys.
  Map<String, dynamic>? _jobsAttributes;

  // Whether the jobs form's required fields (contract_type, modality) are
  // both set. Only consulted when the selected category is jobs (see
  // `_submitListing`); defaults to false so a listing can never publish with
  // an incomplete jobs payload before the form's first post-frame
  // `onValidityChanged` callback fires.
  bool _jobsAttributesValid = false;

  // Pick-on-map coordinates (real_estate only). Populated by
  // `LocationPickerMap.onChanged` when the user taps the map; stay null
  // otherwise. OPTIONAL — a listing can publish without ever setting these,
  // so `_submitListing` never gates on them the way it does on
  // `_reAttributesValid`.
  double? _latitude;
  double? _longitude;

  // Edit-mode only state. Left at their defaults (null / empty) on the
  // create path, so create behavior is unaffected.
  List<String> _existingImageUrls = [];
  String? _prefillCategoryId;
  String? _existingCountryCode;
  String? _existingCurrency;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _titleController.text = existing.title;
      _descriptionController.text = existing.description;
      _priceController.text = existing.price.toString();
      _whatsappController.text = existing.whatsapp ?? '';
      _phoneController.text = existing.phone ?? '';
      _emailController.text = existing.email ?? '';
      _cityController.text = existing.city ?? '';
      _stateController.text = existing.state ?? '';
      _isNegotiable = existing.isNegotiable;
      _latitude = existing.latitude;
      _longitude = existing.longitude;
      _existingImageUrls = List.from(existing.images);
      _prefillCategoryId = existing.categoryId;
      _subcategoryId = existing.subcategoryId;
      _existingCountryCode = existing.countryCode;
      _existingCurrency = existing.currency;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _whatsappController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage(
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );

    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
        final maxNewImages = 10 - _existingImageUrls.length;
        if (_selectedImages.length > maxNewImages) {
          _selectedImages = _selectedImages
              .take(maxNewImages < 0 ? 0 : maxNewImages)
              .toList();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.listingCreateMaxImages,
              ),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.listingCreateSelectCategoryHint),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedCategory!.id == 'real_estate' && !_reAttributesValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.realEstateFormRequiredError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedCategory!.id == 'jobs' && !_jobsAttributesValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.jobsFormRequiredError),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final user = ref.read(authStateProvider).value;
    if (user == null) {
      context.push('/login');
      return;
    }

    if (user.emailConfirmedAt == null) {
      context.push(
        '${AppRoutes.verifyEmail}?redirect=${Uri.encodeComponent(GoRouterState.of(context).uri.toString())}',
      );
      return;
    }

    if (_whatsappController.text.isEmpty &&
        _phoneController.text.isEmpty &&
        _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.listingCreateContactMethodRequired),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final listingService = ref.read(listingServiceProvider);
      final country = ref.read(selectedCountryProvider);

      // Upload newly-picked images (same path for create and edit)
      List<String> imageUrls = [];
      if (_selectedImages.isNotEmpty) {
        final imageBytes = await Future.wait(
          _selectedImages.map((img) => img.readAsBytes()),
        );
        imageUrls = await listingService.uploadImages(user.id, imageBytes);
      }

      if (widget.existing == null) {
        // Create listing
        final listing = Listing(
          id: '', // Will be generated by Supabase
          userId: user.id,
          categoryId: _selectedCategory!.id,
          subcategoryId: _subcategoryId,
          countryCode: country.code,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: double.parse(_priceController.text.replaceAll(',', '.')),
          currency: country.currency,
          images: imageUrls,
          whatsapp: _whatsappController.text.trim().isNotEmpty
              ? _whatsappController.text.trim()
              : null,
          phone: _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          email: _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : null,
          city: _cityController.text.trim().isNotEmpty
              ? _cityController.text.trim()
              : null,
          latitude: _latitude,
          longitude: _longitude,
          state: _stateController.text.trim().isNotEmpty
              ? _stateController.text.trim()
              : null,
          isNegotiable: _isNegotiable,
          createdAt: DateTime.now(),
        );

        // Real-estate attributes (encoded JSONB map). Omit the key when
        // the form hasn't been filled in (e.g. a non-RE category) so the
        // database column stays NULL for other verticals.
        final extraFields = <String, dynamic>{};
        if (_reAttributes != null && _reAttributes!.isNotEmpty) {
          extraFields['attributes'] = _reAttributes;
        }
        if (_jobsAttributes != null && _jobsAttributes!.isNotEmpty) {
          extraFields['attributes'] = _jobsAttributes;
        }

        await listingService.createListing(
          listing,
          extraFields: extraFields.isEmpty ? null : extraFields,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.listingCreatePublishedSuccess),
              backgroundColor: AppColors.success,
            ),
          );
          context.go('/');
        }
      } else {
        // Edit listing: merge kept existing image URLs with newly-uploaded
        // ones, capped at 10, and PATCH only the fields the form owns.
        var images = [..._existingImageUrls, ...imageUrls];
        if (images.length > 10) {
          images = images.take(10).toList();
        }

        final updates = <String, dynamic>{
          'title': _titleController.text.trim(),
          'description': _descriptionController.text.trim(),
          'price': double.parse(_priceController.text.replaceAll(',', '.')),
          'currency': _existingCurrency ?? country.currency,
          'category_id': _selectedCategory!.id,
          'subcategory_id': _subcategoryId,
          'country_code': _existingCountryCode ?? country.code,
          'city': _cityController.text.trim().isNotEmpty
              ? _cityController.text.trim()
              : null,
          'latitude': _latitude,
          'longitude': _longitude,
          'state': _stateController.text.trim().isNotEmpty
              ? _stateController.text.trim()
              : null,
          'whatsapp': _whatsappController.text.trim().isNotEmpty
              ? _whatsappController.text.trim()
              : null,
          'phone': _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          'email': _emailController.text.trim().isNotEmpty
              ? _emailController.text.trim()
              : null,
          'is_negotiable': _isNegotiable,
          'images': images,
        };

        // Real-estate attributes — OVERWRITE the existing JSONB with the
        // current form value. The trigger validates the new value against
        // its constraints; the form's encoding rules are the spec.
        if (_reAttributes != null && _reAttributes!.isNotEmpty) {
          updates['attributes'] = _reAttributes;
        }
        if (_jobsAttributes != null && _jobsAttributes!.isNotEmpty) {
          updates['attributes'] = _jobsAttributes;
        }

        await listingService.updateListing(widget.existing!.id, updates);

        ref.invalidate(listingDetailProvider(widget.existing!.id));
        ref.invalidate(myListingsProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.listingCreateChangesSaved),
              backgroundColor: AppColors.success,
            ),
          );
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.commonErrorWithMessage(e.toString()),
            ),
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
    final authState = ref.watch(authStateProvider);
    final categoriesAsync = ref.watch(createListingCategoriesProvider);
    // Categories-with-subcategories fetch (service layer, shared with the
    // all-categories index / category-chip row) — used ONLY to populate the
    // subcategory dropdown below. Kept separate from `categoriesAsync`
    // (which powers the category dropdown itself) since the two providers
    // hit different service methods and shapes.
    final subcategoriesAsync = ref.watch(categoriesWithSubcategoriesProvider);
    final subcategoryOptions = _subcategoriesFor(subcategoriesAsync.value);
    final country = ref.watch(selectedCountryProvider);

    // Check if user is logged in
    if (authState.value == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.listingCreateTitle),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🦊', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 24),
                Text(
                  l10n.listingCreateSignInTitle,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.listingCreateSignInSubtitle,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => context.push('/login'),
                  child: Text(l10n.authSignIn),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.push('/register'),
                  child: Text(l10n.authCreateAccountButton),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null
              ? l10n.listingCreateTitle
              : l10n.listingEditTitle,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (authState.value?.emailConfirmedAt == null)
              MaterialBanner(
                backgroundColor: AppColors.warning.withValues(alpha: 0.2),
                content: Text(l10n.authVerifyEmailBanner),
                actions: [
                  TextButton(
                    onPressed: () => context.push(
                      '${AppRoutes.verifyEmail}?redirect=${Uri.encodeComponent(GoRouterState.of(context).uri.toString())}',
                    ),
                    child: Text(l10n.authVerifyEmailCta),
                  ),
                ],
              ),
            // Images Section
            Text(
              l10n.listingCreatePhotosHeading,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 100,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  // Add Image Button
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: surfaceFor(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.border,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_a_photo,
                            color: AppColors.primary,
                            size: 32,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.listingCreateAddImage,
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Existing images (edit mode only)
                  ..._existingImageUrls.asMap().entries.map((entry) {
                    final index = entry.key;
                    final url = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              url,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeExistingImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                          if (index == 0)
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l10n.listingCreatePrimaryBadge,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),
                  // Selected Images
                  ..._selectedImages.asMap().entries.map((entry) {
                    final index = entry.key;
                    final image = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(image.path),
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                          if (index == 0 && _existingImageUrls.isEmpty)
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  l10n.listingCreatePrimaryBadge,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.listingCreateMaxPhotosHint,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 24),

            // Category
            Text(
              l10n.listingCreateCategoryLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            categoriesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Text(
                l10n.listingCreateCategoriesError,
                style: TextStyle(color: AppColors.error),
              ),
              data: (categories) {
                _maybePrefillCategory(categories);
                return DropdownButtonFormField<Category>(
                value: _selectedCategory,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: l10n.listingCreateSelectCategoryHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: categories.map((category) {
                  return DropdownMenuItem<Category>(
                    value: category,
                    child: Row(
                      children: [
                        Text(
                          category.icon,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            category.nameEs.isNotEmpty
                                ? category.nameEs
                                : category.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    _subcategoryId = null;
                    if (value?.id != 'real_estate') {
                      _reAttributes = null;
                      _reAttributesValid = false;
                      _latitude = null;
                      _longitude = null;
                    }
                    if (value?.id != 'jobs') {
                      _jobsAttributes = null;
                      _jobsAttributesValid = false;
                    }
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return l10n.listingCreateSelectCategoryHint;
                  }
                  return null;
                },
                );
              },
            ),
            const SizedBox(height: 24),

            // Subcategory (optional): only rendered when the selected
            // category has subcategories (looked up in
            // `categoriesWithSubcategoriesProvider`, not the flat
            // `categoriesAsync` list above). `_subcategoryId` is reset to
            // null whenever the category dropdown's onChanged fires, so a
            // subcategory from a previously-selected category never
            // survives a category switch.
            if (subcategoryOptions.isNotEmpty) ...[
              Text(
                l10n.listingCreateSubcategoryLabel,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                // A stale `_subcategoryId` (e.g. edit mode prefill for a
                // subcategory the DB no longer returns under this category)
                // must not be handed to the dropdown as `value` — Flutter
                // asserts that the value match one of the `items`.
                value: subcategoryOptions.any((s) => s.id == _subcategoryId)
                    ? _subcategoryId
                    : null,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: l10n.listingCreateSubcategoryHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                items: subcategoryOptions.map((sub) {
                  return DropdownMenuItem<String>(
                    value: sub.id,
                    child: Text(
                      sub.nameEs.isNotEmpty ? sub.nameEs : sub.name,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _subcategoryId = value);
                },
              ),
              const SizedBox(height: 24),
            ],

            // Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: l10n.listingCreateTitleLabel,
                hintText: l10n.listingCreateTitleHint,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.listingCreateTitleRequired;
                }
                if (value.length < 10) {
                  return l10n.listingCreateTitleTooShort;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.listingCreateDescriptionLabel,
                hintText: l10n.listingCreateDescriptionHint,
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return l10n.listingCreateDescriptionRequired;
                }
                if (value.length < 20) {
                  return l10n.listingCreateDescriptionTooShort;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Price
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: l10n.listingCreatePriceLabel,
                      prefixText: '${_priceCurrencySymbol(country)} ',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return l10n.listingCreatePriceRequired;
                      }
                      if (double.tryParse(value.replaceAll(',', '.')) ==
                          null) {
                        return l10n.listingCreatePriceInvalid;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.listingCreateNegotiable),
                    Switch(
                      value: _isNegotiable,
                      onChanged: (value) {
                        setState(() => _isNegotiable = value);
                      },
                      activeColor: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // City
            TextFormField(
              controller: _cityController,
              decoration: InputDecoration(
                labelText: l10n.listingCreateCityLabel,
                hintText: l10n.listingCreateCityHint,
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // State / province: free-text (the app has no structured geo
            // data — same rationale as the city field above). OPTIONAL,
            // never gates submit.
            TextFormField(
              controller: _stateController,
              decoration: InputDecoration(
                labelText: l10n.listingCreateStateLabel,
                hintText: l10n.listingCreateStateHint,
                prefixIcon: const Icon(Icons.map_outlined),
              ),
            ),
            const SizedBox(height: 24),

            // Pick-on-map latitude/longitude: rendered only for real_estate,
            // same gate as the attribute form below. Without this, RE
            // listings created via the app never write coordinates and
            // never show up as pins on the search map (`ReMapView`) or the
            // detail mini-map (`ListingLocationMap`). The pick is OPTIONAL —
            // `_latitude`/`_longitude` stay null until (if ever) the user
            // taps the map, and submit never blocks on them.
            if (_selectedCategory?.id == 'real_estate') ...[
              LocationPickerMap(
                initialCenter: centroidForCountry(
                  _existingCountryCode ?? country.code,
                ),
                initialValue: (_latitude != null && _longitude != null)
                    ? LatLng(_latitude!, _longitude!)
                    : null,
                onChanged: (latlng) {
                  setState(() {
                    _latitude = latlng?.latitude;
                    _longitude = latlng?.longitude;
                  });
                },
              ),
              const SizedBox(height: 24),
            ],

            // Real-estate attributes: rendered only when the user picks the
            // real_estate category. The form encodes the values into a JSONB
            // map and hands it back via `onChanged`; the submit step writes
            // that map to `updates['attributes']` (create branch uses
            // `extraFields` on the service call).
            if (_selectedCategory?.id == 'real_estate') ...[
              ReAttributeForm(
                initialAttributes: widget.existing?.attributes,
                onChanged: (m) {
                  setState(() => _reAttributes = m);
                },
                onValidityChanged: (valid) {
                  setState(() => _reAttributesValid = valid);
                },
              ),
              const SizedBox(height: 24),
            ],

            // Jobs attributes: rendered only when the user picks the jobs
            // category. Mutually exclusive with the RE block above (the
            // category dropdown's onChanged clears whichever branch is no
            // longer selected), so a submitted listing never carries both
            // RE and jobs keys.
            if (_selectedCategory?.id == 'jobs') ...[
              JobsAttributeForm(
                initialAttributes: widget.existing?.attributes,
                onChanged: (m) {
                  setState(() => _jobsAttributes = m);
                },
                onValidityChanged: (valid) {
                  setState(() => _jobsAttributesValid = valid);
                },
              ),
              const SizedBox(height: 24),
            ],

            // Contact Information
            Text(
              l10n.listingCreateContactInfoHeading,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.listingCreateContactMethodRequired,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),

            // WhatsApp
            TextFormField(
              controller: _whatsappController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.listingCreateWhatsappLabel,
                hintText: l10n.listingCreatePhoneHint,
                prefixIcon: const Icon(
                  Icons.chat,
                  color: Color(0xFF25D366),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Phone
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.listingCreatePhoneLabel,
                hintText: l10n.listingCreatePhoneHint,
                prefixIcon: const Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: l10n.listingCreateEmailLabel,
                hintText: l10n.listingCreateEmailHint,
                prefixIcon: const Icon(Icons.email_outlined),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            ElevatedButton(
              onPressed: _isLoading ? null : _submitListing,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      widget.existing == null
                          ? l10n.listingCreateSubmitButton
                          : l10n.listingCreateSaveChangesButton,
                    ),
            ),
            const SizedBox(height: 16),

            // Footer links to the static pages (Sprint 5 Task 6) — mirrors
            // the web's publish-form footer.
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 16,
                children: [
                  TextButton(
                    onPressed: () => context.push(AppRoutes.privacidad),
                    child: Text(l10n.privacyPageTitle),
                  ),
                  TextButton(
                    onPressed: () => context.push(AppRoutes.terminos),
                    child: Text(l10n.termsPageTitle),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // Once categories load, select the one matching the listing being edited.
  // No-op on the create path (widget.existing is null) and once the user has
  // picked a category themselves.
  void _maybePrefillCategory(List<Category> categories) {
    if (_selectedCategory != null || _prefillCategoryId == null) return;
    final matches = categories.where((c) => c.id == _prefillCategoryId);
    if (matches.isEmpty) return;
    final match = matches.first;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectedCategory == null) {
        setState(() => _selectedCategory = match);
      }
    });
  }

  // Subcategories of the currently-selected category, sourced from the
  // `categoriesWithSubcategoriesProvider` list (each entry's `.subcategories`
  // is only populated for MAIN categories). Returns `const []` when no
  // category is selected, the category isn't found in this list (still
  // loading / fetch error), or it has no subcategories — all of which mean
  // "don't show the dropdown".
  List<Category> _subcategoriesFor(List<Category>? categoriesWithSubs) {
    if (_selectedCategory == null || categoriesWithSubs == null) {
      return const [];
    }
    final matches = categoriesWithSubs.where(
      (c) => c.id == _selectedCategory!.id,
    );
    if (matches.isEmpty) return const [];
    return matches.first.subcategories ?? const [];
  }

  // The price prefix currency symbol: the app-wide selected country on the
  // create path (unchanged), or the listing's own country/currency when
  // editing — since this form has no country selector, editing must not let
  // whatever country the user is currently browsing silently relabel the ad.
  String _priceCurrencySymbol(Country fallback) {
    if (_existingCountryCode == null) return fallback.currencySymbol;
    final match = Country.defaultCountries.where(
      (c) => c.code == _existingCountryCode,
    );
    return match.isNotEmpty ? match.first.currencySymbol : fallback.currencySymbol;
  }
}
