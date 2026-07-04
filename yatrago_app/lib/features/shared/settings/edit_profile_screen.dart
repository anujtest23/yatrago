import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/data/auth_api.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  String? _selectedGender;
  String? _profilePhotoUrl;
  File? _newPhoto;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  final List<String> _genders = [
    'male',
    'female',
    'other',
    'prefer_not_to_say',
  ];
  final Map<String, String> _genderLabels = {
    'male': 'Male',
    'female': 'Female',
    'other': 'Other',
    'prefer_not_to_say': 'Prefer not to say',
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthApi.getMe();
      if (!mounted) return;
      setState(() {
        _nameController.text = user['fullName'] ?? '';
        _selectedGender = user['gender'];
        _profilePhotoUrl = user['profilePhotoUrl'];
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 800,
    );
    if (picked != null) {
      setState(() => _newPhoto = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Name cannot be empty');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      // Upload photo if new one selected
      if (_newPhoto != null) {
        final formData = FormData.fromMap({
          'file': await MultipartFile.fromFile(
            _newPhoto!.path,
            filename: 'profile.jpg',
          ),
        });
        await DioClient.instance.post(
          '/users/profile-photo',
          data: formData,
          options: Options(contentType: 'multipart/form-data'),
        );
      }

      // Update profile
      await DioClient.instance.patch(
        '/users/me',
        data: {
          'fullName': _nameController.text.trim(),
          if (_selectedGender != null) 'gender': _selectedGender,
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: AppColors.success,
        ),
      );
      context.pop();
    } on DioException catch (e) {
      setState(() => _error = ApiException.fromDioError(e).message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Edit Profile'),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // Photo picker
                    Center(
                      child: GestureDetector(
                        onTap: _pickPhoto,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: AppColors.primaryLight,
                              backgroundImage: _newPhoto != null
                                  ? FileImage(_newPhoto!)
                                  : (_profilePhotoUrl != null
                                        ? NetworkImage(_profilePhotoUrl!)
                                              as ImageProvider
                                        : null),
                              child:
                                  (_newPhoto == null &&
                                      _profilePhotoUrl == null)
                                  ? const Icon(
                                      Icons.person_rounded,
                                      size: 52,
                                      color: AppColors.primary,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Center(
                      child: Text(
                        'Tap to change photo',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Full name
                    const Text(
                      'Full Name',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() => _error = null),
                      decoration: InputDecoration(
                        hintText: 'Enter your full name',
                        errorText: _error,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Gender
                    const Text(
                      'Gender',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _genders.map((g) {
                        final selected = _selectedGender == g;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedGender = g),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : Colors.white,
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _genderLabels[g]!,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: selected
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 48),

                    PrimaryButton(
                      text: 'Save Changes',
                      isLoading: _isSaving,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
