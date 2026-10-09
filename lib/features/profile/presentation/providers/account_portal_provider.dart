import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../patient/presentation/providers/patient_providers.dart';
import '../../data/account_portal_data.dart';

final accountPortalProvider = FutureProvider.autoDispose<AccountPortalData>((
  ref,
) async {
  ref.watch(authProvider.select((state) => state.user?.id));
  final profile = await ref.watch(patientRepositoryProvider).getProfile();
  return AccountPortalData.fromProfile(profile);
});

class SelectedAccountPhoto {
  const SelectedAccountPhoto({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

class AccountPhotoPicker {
  Future<SelectedAccountPhoto?> pick() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
      requestFullMetadata: false,
    );
    if (image == null) return null;
    if (await image.length() > 10 * 1024 * 1024) {
      throw const FormatException('Choose a photo smaller than 10 MB.');
    }
    return SelectedAccountPhoto(
      name: image.name,
      bytes: await image.readAsBytes(),
    );
  }
}

final accountPhotoPickerProvider = Provider<AccountPhotoPicker>(
  (ref) => AccountPhotoPicker(),
);
