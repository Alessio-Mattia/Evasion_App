import 'package:evasion/core/config/business_rules.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'photo_picker.g.dart';

enum PhotoSource { gallery, camera }

/// The user refused access to their photos or camera.
class PhotoAccessDenied implements Exception {
  const PhotoAccessDenied();
}

/// Title and colors of the crop screen, taken from the app theme.
class CropAppearance {
  const CropAppearance({
    required this.title,
    required this.toolbarColor,
    required this.toolbarForeground,
    required this.backgroundColor,
    required this.accentColor,
  });

  final String title;
  final Color toolbarColor;
  final Color toolbarForeground;
  final Color backgroundColor;
  final Color accentColor;
}

/// Lets the user take or choose a photo, then crop it square.
abstract interface class PhotoPicker {
  /// The cropped photo, or null if the user cancelled. Throws
  /// [PhotoAccessDenied] when access to the photos or camera is refused.
  Future<Uint8List?> pickSquarePhoto(
    PhotoSource source,
    CropAppearance appearance,
  );
}

@Riverpod(keepAlive: true)
PhotoPicker photoPicker(Ref ref) => DevicePhotoPicker();

/// Uses the system photo picker and camera, then the native crop screen.
///
/// The crop screen always re-encodes the photo as a JPEG of at most
/// [BusinessRules.avatarSizePixels]: an iPhone HEIC photo comes out as a JPEG.
class DevicePhotoPicker implements PhotoPicker {
  @override
  Future<Uint8List?> pickSquarePhoto(
    PhotoSource source,
    CropAppearance appearance,
  ) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: switch (source) {
          PhotoSource.gallery => ImageSource.gallery,
          PhotoSource.camera => ImageSource.camera,
        },
        // Leaves room to crop, while keeping huge camera photos manageable.
        maxWidth: BusinessRules.avatarSizePixels * 2,
        maxHeight: BusinessRules.avatarSizePixels * 2,
        preferredCameraDevice: CameraDevice.front,
      );
      if (picked == null) return null;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        maxWidth: BusinessRules.avatarSizePixels,
        maxHeight: BusinessRules.avatarSizePixels,
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: appearance.title,
            toolbarColor: appearance.toolbarColor,
            toolbarWidgetColor: appearance.toolbarForeground,
            backgroundColor: appearance.backgroundColor,
            activeControlsWidgetColor: appearance.accentColor,
            // A round frame shows how the photo will appear on the profile.
            cropStyle: CropStyle.circle,
          ),
          IOSUiSettings(
            title: appearance.title,
            cropStyle: CropStyle.circle,
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
            aspectRatioPickerButtonHidden: true,
          ),
        ],
      );
      return await cropped?.readAsBytes();
    } on PlatformException catch (error) {
      if (error.code case 'photo_access_denied' || 'camera_access_denied') {
        throw const PhotoAccessDenied();
      }
      rethrow;
    }
  }
}
