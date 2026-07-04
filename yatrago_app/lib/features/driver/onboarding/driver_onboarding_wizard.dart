import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_spacing.dart';
import '../../../core/router/route_names.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/widgets/primary_button.dart';

class DriverOnboardingWizard extends StatefulWidget {
  const DriverOnboardingWizard({super.key});

  @override
  State<DriverOnboardingWizard> createState() => _DriverOnboardingWizardState();
}

class _DriverOnboardingWizardState extends State<DriverOnboardingWizard> {
  int _step = 0;
  bool _isLoading = false;
  String? _error;

  // Doc files
  File? _citizenshipFront;
  File? _citizenshipBack;
  File? _licenseFront;
  File? _licenseBack;
  File? _selfie;

  // Vehicle info
  final _makeController = TextEditingController();
  final _modelController = TextEditingController();
  final _plateController = TextEditingController();
  final _colorController = TextEditingController();
  int _year = DateTime.now().year;
  String _vehicleType = 'car';
  int _totalSeats = 4;

  final List<String> _stepTitles = [
    'Citizenship',
    'Driving License',
    'Selfie',
    'Vehicle Info',
    'Vehicle Docs',
  ];

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _plateController.dispose();
    _colorController.dispose();
    super.dispose();
  }

  Future<File?> _pickImage({bool camera = false}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    return picked != null ? File(picked.path) : null;
  }

  Future<void> _uploadDoc(
    String endpoint,
    File file, {
    String? queryParam,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: 'doc_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    });

    final uri = queryParam != null ? '$endpoint?$queryParam' : endpoint;
    await DioClient.instance.post(
      uri,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<void> _nextStep() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      switch (_step) {
        case 0: // Citizenship
          if (_citizenshipFront == null || _citizenshipBack == null) {
            setState(() => _error = 'Upload both front and back');
            return;
          }
          await _uploadDoc(
            '/drivers/citizenship',
            _citizenshipFront!,
            queryParam: 'side=front',
          );
          await _uploadDoc(
            '/drivers/citizenship',
            _citizenshipBack!,
            queryParam: 'side=back',
          );
          break;

        case 1: // License
          if (_licenseFront == null || _licenseBack == null) {
            setState(() => _error = 'Upload both front and back');
            return;
          }
          await _uploadDoc(
            '/drivers/license',
            _licenseFront!,
            queryParam: 'side=front',
          );
          await _uploadDoc(
            '/drivers/license',
            _licenseBack!,
            queryParam: 'side=back',
          );
          break;

        case 2: // Selfie
          if (_selfie == null) {
            setState(() => _error = 'Please take a selfie');
            return;
          }
          await _uploadDoc('/drivers/selfie', _selfie!);
          break;

        case 3: // Vehicle info
          if (_makeController.text.isEmpty ||
              _modelController.text.isEmpty ||
              _plateController.text.isEmpty) {
            setState(() => _error = 'Please fill in all required fields');
            return;
          }
          await DioClient.instance.post(
            '/vehicles',
            data: {
              'make': _makeController.text.trim(),
              'model': _modelController.text.trim(),
              'year': _year,
              'plateNumber': _plateController.text.trim().toUpperCase(),
              'color': _colorController.text.trim(),
              'vehicleType': _vehicleType,
              'totalSeats': _totalSeats,
            },
          );
          break;

        case 4: // Done — go to under review
          if (!mounted) return;
          context.go(RouteNames.driverUnderReview);
          return;
      }

      if (mounted) setState(() => _step++);
    } on DioException catch (e) {
      setState(() => _error = ApiException.fromDioError(e).message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _step > 0
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.textPrimary,
                ),
                onPressed: () => setState(() => _step--),
              )
            : IconButton(
                icon: const Icon(Icons.close, color: AppColors.textPrimary),
                onPressed: () => context.pop(),
              ),
        title: Text(
          'Step ${_step + 1} of ${_stepTitles.length}: ${_stepTitles[_step]}',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: (_step + 1) / _stepTitles.length,
              backgroundColor: AppColors.borderLight,
              color: AppColors.driver,
              minHeight: 4,
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: _buildStep(),
              ),
            ),

            // Error
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),

            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: PrimaryButton(
                text: _step == _stepTitles.length - 1
                    ? 'Submit for Review'
                    : 'Continue',
                isLoading: _isLoading,
                backgroundColor: AppColors.driver,
                onPressed: _nextStep,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _DocUploadStep(
          title: 'Upload Citizenship Certificate',
          subtitle:
              'Upload clear photos of both sides of your citizenship certificate.',
          frontFile: _citizenshipFront,
          backFile: _citizenshipBack,
          onPickFront: () async {
            final f = await _pickImage();
            if (f != null) setState(() => _citizenshipFront = f);
          },
          onPickBack: () async {
            final f = await _pickImage();
            if (f != null) setState(() => _citizenshipBack = f);
          },
        );

      case 1:
        return _DocUploadStep(
          title: 'Upload Driving License',
          subtitle:
              'Upload clear photos of both sides of your driving license.',
          frontFile: _licenseFront,
          backFile: _licenseBack,
          onPickFront: () async {
            final f = await _pickImage();
            if (f != null) setState(() => _licenseFront = f);
          },
          onPickBack: () async {
            final f = await _pickImage();
            if (f != null) setState(() => _licenseBack = f);
          },
        );

      case 2:
        return _SelfieStep(
          selfie: _selfie,
          onPick: () async {
            final f = await _pickImage(camera: true);
            if (f != null) setState(() => _selfie = f);
          },
        );

      case 3:
        return _VehicleInfoStep(
          makeController: _makeController,
          modelController: _modelController,
          plateController: _plateController,
          colorController: _colorController,
          year: _year,
          vehicleType: _vehicleType,
          totalSeats: _totalSeats,
          onYearChanged: (y) => setState(() => _year = y),
          onTypeChanged: (t) => setState(() => _vehicleType = t),
          onSeatsChanged: (s) => setState(() => _totalSeats = s),
        );

      case 4:
        return _ReviewStep();

      default:
        return const SizedBox.shrink();
    }
  }
}

// Doc upload widget
class _DocUploadStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final File? frontFile;
  final File? backFile;
  final VoidCallback onPickFront;
  final VoidCallback onPickBack;

  const _DocUploadStep({
    required this.title,
    required this.subtitle,
    required this.frontFile,
    required this.backFile,
    required this.onPickFront,
    required this.onPickBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        _UploadBox(label: 'Front Side', file: frontFile, onTap: onPickFront),
        const SizedBox(height: 16),
        _UploadBox(label: 'Back Side', file: backFile, onTap: onPickBack),
      ],
    );
  }
}

class _UploadBox extends StatelessWidget {
  final String label;
  final File? file;
  final VoidCallback onTap;

  const _UploadBox({
    required this.label,
    required this.file,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: AppColors.borderLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: file != null ? AppColors.driver : AppColors.border,
            width: file != null ? 2 : 1,
          ),
        ),
        child: file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(11),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(file!, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: AppColors.driver,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_photo_alternate_rounded,
                    size: 36,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap to upload',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// Selfie step
class _SelfieStep extends StatelessWidget {
  final File? selfie;
  final VoidCallback onPick;

  const _SelfieStep({required this.selfie, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 8),
        const Text(
          'Selfie Verification',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Take a clear selfie in good lighting. Make sure your face is fully visible.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 32),
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.borderLight,
              border: Border.all(
                color: selfie != null ? AppColors.driver : AppColors.border,
                width: 2,
              ),
            ),
            child: selfie != null
                ? ClipOval(child: Image.file(selfie!, fit: BoxFit.cover))
                : const Icon(
                    Icons.camera_alt_rounded,
                    size: 56,
                    color: AppColors.textTertiary,
                  ),
          ),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          onPressed: onPick,
          icon: const Icon(Icons.camera_alt_rounded),
          label: Text(selfie != null ? 'Retake Selfie' : 'Take Selfie'),
        ),
      ],
    );
  }
}

// Vehicle info step
class _VehicleInfoStep extends StatelessWidget {
  final TextEditingController makeController;
  final TextEditingController modelController;
  final TextEditingController plateController;
  final TextEditingController colorController;
  final int year;
  final String vehicleType;
  final int totalSeats;
  final Function(int) onYearChanged;
  final Function(String) onTypeChanged;
  final Function(int) onSeatsChanged;

  const _VehicleInfoStep({
    required this.makeController,
    required this.modelController,
    required this.plateController,
    required this.colorController,
    required this.year,
    required this.vehicleType,
    required this.totalSeats,
    required this.onYearChanged,
    required this.onTypeChanged,
    required this.onSeatsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vehicle Information',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 24),
        _Field(label: 'Make *', controller: makeController, hint: 'Toyota'),
        const SizedBox(height: 14),
        _Field(label: 'Model *', controller: modelController, hint: 'Vitz'),
        const SizedBox(height: 14),
        _Field(
          label: 'Plate Number *',
          controller: plateController,
          hint: 'BA 1 CHA 2345',
          caps: TextCapitalization.characters,
        ),
        const SizedBox(height: 14),
        _Field(label: 'Color', controller: colorController, hint: 'White'),
        const SizedBox(height: 14),
        // Year
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Year',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<int>(
              value: year,
              decoration: const InputDecoration(),
              items:
                  List.generate(
                        DateTime.now().year - 1989,
                        (i) => DateTime.now().year - i,
                      )
                      .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                      .toList(),
              onChanged: (v) => onYearChanged(v!),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Vehicle type
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vehicle Type',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: ['motorcycle', 'car', 'suv', 'microbus'].map((t) {
                final selected = vehicleType == t;
                return GestureDetector(
                  onTap: () => onTypeChanged(t),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.driver : Colors.white,
                      border: Border.all(
                        color: selected ? AppColors.driver : AppColors.border,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      t[0].toUpperCase() + t.substring(1),
                      style: TextStyle(
                        fontSize: 13,
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Seats
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Total Seats to Offer',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (totalSeats > 1) onSeatsChanged(totalSeats - 1);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.borderLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.remove_rounded, size: 18),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '$totalSeats',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    if (totalSeats < 20) onSeatsChanged(totalSeats + 1);
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.driverLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: AppColors.driver,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final TextCapitalization caps;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.caps = TextCapitalization.words,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          textCapitalization: caps,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

// Review step
class _ReviewStep extends StatelessWidget {
  const _ReviewStep();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(
            color: AppColors.driverLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 48,
            color: AppColors.driver,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'All documents uploaded!',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        const Text(
          'Our team will review your application within 24-48 hours. You will be notified once approved.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
