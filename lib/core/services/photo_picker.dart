import 'package:evasion/core/config/business_rules.dart';
import 'package:flutter/services.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'photo_picker.g.dart';

enum PhotoSource { gallery, camera }

/// How the photo is cropped.
enum PhotoShape {
  /// Square, shown in a round frame: the profile photo.
  round(
    BusinessRules.avatarSizePixels,
    BusinessRules.avatarSizePixels,
    CameraDevice.front,
  ),

  /// Portrait 4:5, the shape of the carousel cards: the page photos.
  portrait(
    BusinessRules.pagePhotoWidthPixels,
    BusinessRules.pagePhotoHeightPixels,
    CameraDevice.rear,
  );

  const PhotoShape(this.width, this.height, this.camera);

  /// Size of the cropped photo, in pixels.
  final int width;
  final int height;

  /// A profile photo is usually a selfie; a page photo rather not.
  final CameraDevice camera;
}

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

/// Lets the user take or choose a photo, then crop it to [PhotoShape].
abstract interface class PhotoPicker {
  /// The cropped photo, or null if the user cancelled. Throws
  /// [PhotoAccessDenied] when access to the photos or camera is refused.
  Future<Uint8List?> pickPhoto(
    PhotoSource source,
    PhotoShape shape,
    CropAppearance appearance,
  );
}

@Riverpod(keepAlive: true)
PhotoPicker photoPicker(Ref ref) => DevicePhotoPicker();

/// Uses the system photo picker and camera, then the native crop screen.
///
/// The crop screen always re-encodes the photo as a JPEG of at most the size
/// of the [PhotoShape]: an iPhone HEIC photo comes out as a JPEG.
class DevicePhotoPicker implements PhotoPicker {
  @override
  Future<Uint8List?> pickPhoto(
    PhotoSource source,
    PhotoShape shape,
    CropAppearance appearance,
  ) async {
    final cropStyle = switch (shape) {
      // A round frame shows how the photo will appear on the profile.
      PhotoShape.round => CropStyle.circle,
      PhotoShape.portrait => CropStyle.rectangle,
    };
    try {
      final picked = await ImagePicker().pickImage(
        source: switch (source) {
          PhotoSource.gallery => ImageSource.gallery,
          PhotoSource.camera => ImageSource.camera,
        },
        // Leaves room to crop, while keeping huge camera photos manageable.
        maxWidth: shape.height * 2.0,
        maxHeight: shape.height * 2.0,
        preferredCameraDevice: shape.camera,
      );
      if (picked == null) return null;

      final cropped = await ImageCropper().cropImage(
        sourcePath: picked.path,
        aspectRatio: CropAspectRatio(
          ratioX: shape.width.toDouble(),
          ratioY: shape.height.toDouble(),
        ),
        maxWidth: shape.width,
        maxHeight: shape.height,
        compressQuality: 85,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: appearance.title,
            toolbarColor: appearance.toolbarColor,
            toolbarWidgetColor: appearance.toolbarForeground,
            backgroundColor: appearance.backgroundColor,
            activeControlsWidgetColor: appearance.accentColor,
            cropStyle: cropStyle,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: appearance.title,
            cropStyle: cropStyle,
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
