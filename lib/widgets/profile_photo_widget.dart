import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

/// Widget for displaying and updating user profile photo
class ProfilePhotoWidget extends StatefulWidget {
  final String? photoUrl;
  final int userId;
  final double size;
  final Function(UserModel)? onPhotoUpdated;

  const ProfilePhotoWidget({
    super.key,
    this.photoUrl,
    required this.userId,
    this.size = 100,
    this.onPhotoUpdated,
  });

  @override
  State<ProfilePhotoWidget> createState() => _ProfilePhotoWidgetState();
}

class _ProfilePhotoWidgetState extends State<ProfilePhotoWidget> {
  bool _isUploading = false;
  String? _currentPhotoUrl;

  @override
  void initState() {
    super.initState();
    _currentPhotoUrl = widget.photoUrl;
  }

  @override
  void didUpdateWidget(ProfilePhotoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) {
      setState(() {
        _currentPhotoUrl = widget.photoUrl;
      });
    }
  }

  void _showProfilePhotoMenu() {
    print('Showing profile photo menu'); // Debug
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // View Photo (if exists)
              if (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.visibility),
                  title: const Text('View Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _viewPhoto();
                  },
                ),
              // Update Photo
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Update Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadPhoto();
                },
              ),
              // Delete Photo (if exists)
              if (_currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Delete Photo',
                      style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deletePhoto();
                  },
                ),
              // Cancel
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _viewPhoto() {
    if (_currentPhotoUrl == null || _currentPhotoUrl!.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            Center(
              child: Image.network(
                _currentPhotoUrl!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text('Failed to load image'),
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      // Show image source selection dialog
      final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Photo Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );

      if (source == null) return;

      setState(() => _isUploading = true);

      // Pick image
      final File? imageFile = await StorageService.pickImage(source: source);
      if (imageFile == null) {
        setState(() => _isUploading = false);
        return;
      }

      // Upload to Firebase Storage
      final String downloadUrl = await StorageService.uploadProfilePhoto(
        imageFile,
        widget.userId.toString(),
      );

      // Update profile photo URL in backend
      final UserModel updatedUser = await AuthService.updateProfilePhoto(
        userId: widget.userId,
        profilePhotoUrl: downloadUrl,
      );

      setState(() {
        _currentPhotoUrl = downloadUrl;
        _isUploading = false;
      });

      // Notify parent widget
      if (widget.onPhotoUpdated != null) {
        widget.onPhotoUpdated!(updatedUser);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deletePhoto() async {
    // Confirm deletion
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Profile Photo'),
        content:
            const Text('Are you sure you want to delete your profile photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isUploading = true);

      // Delete from Firebase Storage and backend
      final UserModel updatedUser = await AuthService.deleteProfilePhoto(
        userId: widget.userId,
        photoUrl: _currentPhotoUrl,
      );

      setState(() {
        _currentPhotoUrl = null;
        _isUploading = false;
      });

      // Notify parent widget
      if (widget.onPhotoUpdated != null) {
        widget.onPhotoUpdated!(updatedUser);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo deleted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          print('Profile photo tapped!'); // Debug
          _showProfilePhotoMenu();
        },
        borderRadius: BorderRadius.circular(widget.size),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Main photo/placeholder
              ClipOval(
                child: _currentPhotoUrl != null && _currentPhotoUrl!.isNotEmpty
                    ? IgnorePointer(
                        child: Image.network(
                          _currentPhotoUrl!,
                          fit: BoxFit.cover,
                          width: widget.size,
                          height: widget.size,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholder();
                          },
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: loadingProgress.expectedTotalBytes !=
                                        null
                                    ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                    : null,
                                strokeWidth: 2,
                              ),
                            );
                          },
                        ),
                      )
                    : _buildPlaceholder(),
              ),
              // Uploading overlay
              if (_isUploading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ),
              // Camera icon overlay - always visible to indicate it's clickable
              // Note: This is just visual - taps are handled by parent InkWell
              Positioned(
                bottom: -2,
                right: -2,
                child: IgnorePointer(
                  child: Container(
                    width: widget.size * 0.35,
                    height: widget.size * 0.35,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).primaryColor,
                      border: Border.all(
                        color: Colors.white,
                        width: 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _isUploading ? Icons.hourglass_empty : Icons.camera_alt,
                      size: widget.size * 0.18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.size,
      height: widget.size,
      color: Colors.grey.shade200,
      child: Icon(
        Icons.person,
        size: widget.size * 0.5,
        color: Colors.grey.shade600,
      ),
    );
  }
}
