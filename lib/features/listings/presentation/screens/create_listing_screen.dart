import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/category_model.dart';
import '../../../../core/models/country_model.dart';
import '../../../../core/models/listing_model.dart';
import '../../../../core/services/listing_service.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/country_service.dart';
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

  Category? _selectedCategory;
  List<XFile> _selectedImages = [];
  bool _isNegotiable = false;
  bool _isLoading = false;

  // Edit-mode only state. Left at their defaults (null / empty) on the
  // create path, so create behavior is unaffected.
  List<String> _existingImageUrls = [];
  String? _prefillCategoryId;
  String? _existingSubcategoryId;
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
      _isNegotiable = existing.isNegotiable;
      _existingImageUrls = List.from(existing.images);
      _prefillCategoryId = existing.categoryId;
      _existingSubcategoryId = existing.subcategoryId;
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
            const SnackBar(
              content: Text('Máximo 10 imágenes permitidas'),
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

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona una categoría'),
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

    if (_whatsappController.text.isEmpty &&
        _phoneController.text.isEmpty &&
        _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un método de contacto'),
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
          countryCode: country.code,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: double.parse(_priceController.text),
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
          isNegotiable: _isNegotiable,
          createdAt: DateTime.now(),
        );

        await listingService.createListing(listing);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Anuncio publicado con éxito!'),
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
          'price': double.parse(_priceController.text),
          'currency': _existingCurrency ?? country.currency,
          'category_id': _selectedCategory!.id,
          'subcategory_id': _existingSubcategoryId,
          'country_code': _existingCountryCode ?? country.code,
          'city': _cityController.text.trim().isNotEmpty
              ? _cityController.text.trim()
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

        await listingService.updateListing(widget.existing!.id, updates);

        ref.invalidate(listingDetailProvider(widget.existing!.id));
        ref.invalidate(myListingsProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cambios guardados'),
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
            content: Text('Error: ${e.toString()}'),
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
    final authState = ref.watch(authStateProvider);
    final categoriesAsync = ref.watch(createListingCategoriesProvider);
    final country = ref.watch(selectedCountryProvider);

    // Check if user is logged in
    if (authState.value == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Publicar Anuncio'),
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
                const Text(
                  'Inicia sesión para publicar',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Necesitas una cuenta para publicar anuncios en Foxy Ads',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('Iniciar Sesión'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => context.push('/register'),
                  child: const Text('Crear Cuenta'),
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
          widget.existing == null ? 'Publicar Anuncio' : 'Editar anuncio',
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
            // Images Section
            const Text(
              'Fotos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                        color: AppColors.surface,
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
                            'Agregar',
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
                                child: const Text(
                                  'Principal',
                                  style: TextStyle(
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
                                child: const Text(
                                  'Principal',
                                  style: TextStyle(
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
              'Máximo 10 fotos. La primera será la principal.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 24),

            // Category
            const Text(
              'Categoría *',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
                'Error al cargar categorías',
                style: TextStyle(color: AppColors.error),
              ),
              data: (categories) {
                _maybePrefillCategory(categories);
                return DropdownButtonFormField<Category>(
                value: _selectedCategory,
                isExpanded: true,
                decoration: InputDecoration(
                  hintText: 'Selecciona una categoría',
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
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Selecciona una categoría';
                  }
                  return null;
                },
                );
              },
            ),
            const SizedBox(height: 24),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Título del anuncio *',
                hintText: 'Ej: iPhone 13 Pro Max 256GB',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'El título es obligatorio';
                }
                if (value.length < 10) {
                  return 'El título debe tener al menos 10 caracteres';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Descripción *',
                hintText: 'Describe tu producto o servicio...',
                alignLabelWithHint: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'La descripción es obligatoria';
                }
                if (value.length < 20) {
                  return 'La descripción debe tener al menos 20 caracteres';
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
                      labelText: 'Precio *',
                      prefixText: '${_priceCurrencySymbol(country)} ',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'El precio es obligatorio';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Ingresa un precio válido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Negociable'),
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
              decoration: const InputDecoration(
                labelText: 'Ciudad',
                hintText: 'Ej: Madrid, Ciudad de México...',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 24),

            // Contact Information
            const Text(
              'Información de Contacto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega al menos un método de contacto',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 16),

            // WhatsApp
            TextFormField(
              controller: _whatsappController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp',
                hintText: '+34 612 345 678',
                prefixIcon: Icon(Icons.chat, color: Color(0xFF25D366)),
              ),
            ),
            const SizedBox(height: 16),

            // Phone
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                hintText: '+34 612 345 678',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                hintText: 'tu@email.com',
                prefixIcon: Icon(Icons.email_outlined),
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
                          ? 'Publicar Anuncio'
                          : 'Guardar cambios',
                    ),
            ),
            const SizedBox(height: 32),
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
