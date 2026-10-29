import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/image_utils.dart';
import '../../../data/models/user_model.dart';
import '../../../data/services/auth_service.dart';
import '../auth/login_screen.dart';
import '../auth/register_screen.dart';
import '../../widgets/common/user_utility_drawer_modal.dart';
import '../../widgets/profile/favorites_section_widget.dart';

class ProfileScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const ProfileScreen({super.key, this.onNavigateTab});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  UserModel? _user;
  bool _isLoading = true;
  bool _isLoggedIn = true;

  // Main Account Management Tabs (Matching SettingsPage.tsx & SettingsSidebar.tsx)
  // 0: Profile Settings (Thông tin cá nhân)
  // 1: Security Settings (Đổi mật khẩu & Bảo mật)
  // 2: Preferences (Tùy chọn & Quyền riêng tư)
  int _mainTabIndex = 0;

  // Profile Form Controllers
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  XFile? _pickedAvatar;
  Uint8List? _avatarBytes;
  XFile? _pickedCover;
  Uint8List? _coverBytes;
  bool _isSavingProfile = false;
  bool _isUploadingAvatar = false;
  bool _isUploadingCover = false;
  String? _profileError;
  String? _profileSuccess;

  // Security Form Controllers
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;
  bool _isUpdatingPassword = false;
  String? _securityError;
  String? _securitySuccess;

  // Preferences Form State
  bool _prefNotifyReviews = true;
  bool _prefNotifyComments = true;
  bool _prefPublicLogs = true;
  String? _prefSuccess;

  StreamSubscription<UserModel?>? _userSubscription;

  @override
  void initState() {
    super.initState();
    _userSubscription = _authService.onUserUpdated.listen((user) {
      if (mounted) {
        setState(() {
          _user = user;
          _isLoggedIn = user != null;
          if (user != null) {
            _syncFormFields(user);
          }
        });
      }
    });
    _loadProfile();
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    _fullNameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile({bool forceRefresh = false}) async {
    if (!mounted) return;
    if (_user == null) {
      setState(() => _isLoading = true);
    }

    final loggedIn = await _authService.isLoggedIn();
    if (!loggedIn) {
      _authService.notifyUserChanged(null);
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
          _user = null;
        });
      }
      return;
    }

    final res = await _authService.getProfile();
    if (mounted) {
      if (res.success && res.data != null) {
        setState(() {
          _isLoggedIn = true;
          _isLoading = false;
          _user = res.data;
          _syncFormFields(res.data!);
        });
      } else {
        _authService.notifyUserChanged(null);
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
          _user = null;
        });
      }
    }
  }

  void _syncFormFields(UserModel user) {
    if (_fullNameController.text.isEmpty || _fullNameController.text != user.fullName) {
      _fullNameController.text = user.fullName;
    }
    if (_phoneController.text.isEmpty || _phoneController.text != user.phone) {
      _phoneController.text = user.phone;
    }
    if (_bioController.text.isEmpty || _bioController.text != user.bio) {
      _bioController.text = user.bio;
    }
  }


  Future<void> _showImagePickerModal({required bool isAvatar}) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isAvatar ? Icons.account_circle_outlined : Icons.image_outlined,
                      color: const Color(0xFF047857),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAvatar ? 'Cập nhật ảnh đại diện' : 'Tải ảnh bìa từ thiết bị',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAvatar
                              ? 'Chọn ảnh chân dung rõ nét (JPG, PNG, WEBP, tối đa 10MB)'
                              : 'Chọn ảnh phong cảnh chất lượng cao (JPG, PNG, WEBP, tối đa 10MB)',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.drive_folder_upload_outlined, color: Color(0xFF047857), size: 20),
                ),
                title: Text(
                  isAvatar ? 'Tải ảnh từ thư viện máy' : 'Tải ảnh bìa từ máy lên',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                subtitle: const Text('Chọn tệp ảnh có sẵn từ bộ nhớ máy', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageWithSource(ImageSource.gallery, isAvatar: isAvatar);
                },
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF2563EB), size: 20),
                ),
                title: const Text('Chụp ảnh trực tiếp bằng Camera', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                subtitle: const Text('Mở máy ảnh để chụp và cập nhật ngay', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImageWithSource(ImageSource.camera, isAvatar: isAvatar);
                },
              ),
              if ((isAvatar && (_avatarBytes != null || _pickedAvatar != null)) ||
                  (!isAvatar && (_coverBytes != null || _pickedCover != null))) ...[
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_outline, color: Color(0xFFDC2626), size: 20),
                  ),
                  title: const Text('Hủy ảnh vừa chọn', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
                  subtitle: const Text('Khôi phục về ảnh ban đầu', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8))),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (isAvatar) {
                      _clearPickedAvatar();
                    } else {
                      _clearPickedCover();
                    }
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickImageWithSource(ImageSource source, {required bool isAvatar}) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: isAvatar ? 1024 : 1920,
        maxHeight: isAvatar ? 1024 : 1080,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (bytes.length > 10 * 1024 * 1024) {
          if (mounted) {
            setState(() {
              _profileError = isAvatar
                  ? 'Kích thước ảnh đại diện không được vượt quá 10MB.'
                  : 'Kích thước ảnh bìa không được vượt quá 10MB.';
              _profileSuccess = null;
            });
          }
          return;
        }

        if (mounted) {
          setState(() {
            if (isAvatar) {
              _pickedAvatar = file;
              _avatarBytes = bytes;
            } else {
              _pickedCover = file;
              _coverBytes = bytes;
            }
            _profileError = null;
          });
        }

        // Tự động tải lên & cập nhật ngay vào Database
        await _uploadDirectly(isAvatar: isAvatar, bytes: bytes, fileName: file.name);
      }
    } catch (e) {
      if (mounted) setState(() => _profileError = 'Không thể chọn ảnh: $e');
    }
  }

  Future<void> _uploadDirectly({required bool isAvatar, required Uint8List bytes, required String fileName}) async {
    if (_user == null) return;
    if (mounted) {
      setState(() {
        if (isAvatar) {
          _isUploadingAvatar = true;
        } else {
          _isUploadingCover = true;
        }
        _profileError = null;
      });
    }

    final res = await _authService.updateProfile(
      fullName: _fullNameController.text.trim().isNotEmpty ? _fullNameController.text.trim() : _user!.fullName,
      phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : _user!.phone,
      bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : _user!.bio,
      avatarBytes: isAvatar ? bytes : null,
      avatarFileName: isAvatar ? fileName : null,
      coverBytes: !isAvatar ? bytes : null,
      coverFileName: !isAvatar ? fileName : null,
    );

    if (mounted) {
      setState(() {
        if (isAvatar) {
          _isUploadingAvatar = false;
        } else {
          _isUploadingCover = false;
        }
        if (res.success && res.data != null) {
          _user = res.data;
          _syncFormFields(_user!);
          if (isAvatar) {
            _pickedAvatar = null;
            _avatarBytes = null;
          } else {
            _pickedCover = null;
            _coverBytes = null;
          }
          _profileSuccess = isAvatar ? 'Đã cập nhật ảnh đại diện thành công!' : 'Đã cập nhật ảnh bìa thành công!';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_profileSuccess!),
              backgroundColor: const Color(0xFF047857),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          _profileError = res.message.isNotEmpty ? res.message : 'Không thể cập nhật ảnh lên máy chủ';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_profileError!),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      });
    }
  }

  Future<void> _pickAvatarImage() async {
    await _showImagePickerModal(isAvatar: true);
  }

  void _clearPickedAvatar() {
    setState(() {
      _pickedAvatar = null;
      _avatarBytes = null;
    });
  }

  Future<void> _pickCoverImage() async {
    await _showImagePickerModal(isAvatar: false);
  }

  void _clearPickedCover() {
    setState(() {
      _pickedCover = null;
      _coverBytes = null;
    });
  }

  Future<void> _handleSaveProfile() async {
    if (_user == null) return;
    final fullName = _fullNameController.text.trim();
    if (fullName.length < 2 || fullName.length > 50) {
      setState(() {
        _profileError = 'Họ và tên phải từ 2 đến 50 ký tự.';
        _profileSuccess = null;
      });
      return;
    }

    setState(() {
      _isSavingProfile = true;
      _profileError = null;
      _profileSuccess = null;
    });

    final res = await _authService.updateProfile(
      fullName: fullName,
      phone: _phoneController.text.trim(),
      bio: _bioController.text.trim(),
      avatarBytes: _avatarBytes,
      avatarFileName: _pickedAvatar?.name,
      coverBytes: _coverBytes,
      coverFileName: _pickedCover?.name,
    );

    if (mounted) {
      setState(() {
        _isSavingProfile = false;
        if (res.success && res.data != null) {
          _user = res.data;
          _pickedAvatar = null;
          _avatarBytes = null;
          _pickedCover = null;
          _coverBytes = null;
          _profileSuccess = 'Đã lưu thay đổi thông tin cá nhân thành công!';
        } else {
          _profileError = res.message.isNotEmpty ? res.message : 'Không thể cập nhật hồ sơ';
        }
      });
    }
  }

  Future<void> _handleUpdatePassword() async {
    final currentPass = _currentPasswordController.text;
    final newPass = _newPasswordController.text;
    final confirmPass = _confirmPasswordController.text;

    if (currentPass.isEmpty) {
      setState(() {
        _securityError = 'Vui lòng nhập mật khẩu hiện tại.';
        _securitySuccess = null;
      });
      return;
    }

    if (newPass.length < 6) {
      setState(() {
        _securityError = 'Mật khẩu mới phải có ít nhất 6 ký tự.';
        _securitySuccess = null;
      });
      return;
    }

    if (newPass != confirmPass) {
      setState(() {
        _securityError = 'Xác nhận mật khẩu mới chưa khớp.';
        _securitySuccess = null;
      });
      return;
    }

    setState(() {
      _isUpdatingPassword = true;
      _securityError = null;
      _securitySuccess = null;
    });

    final res = await AuthService().changePassword(
      currentPassword: currentPass,
      newPassword: newPass,
      confirmPassword: confirmPass,
    );

    if (mounted) {
      setState(() {
        _isUpdatingPassword = false;
        if (res.success) {
          _currentPasswordController.clear();
          _newPasswordController.clear();
          _confirmPasswordController.clear();
          _securitySuccess = res.message.isNotEmpty ? res.message : 'Đã cập nhật mật khẩu mới thành công!';
        } else {
          _securityError = res.message.isNotEmpty ? res.message : 'Đổi mật khẩu thất bại. Vui lòng kiểm tra lại mật khẩu hiện tại.';
        }
      });
    }
  }

  void _handleSavePreferences() {
    setState(() {
      _prefSuccess = 'Đã lưu tùy chọn quyền riêng tư thành công!';
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _prefSuccess = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
        ),
      );
    }

    if (!_isLoggedIn || _user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _buildGuestView(),
              ),
            ),
          ),
        ),
      );
    }

    final user = _user!;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            await _loadProfile(forceRefresh: true);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ===== 1. HERO HEADER CARD (Cover, Avatar, User Summary) =====
                    _buildHeroHeaderCard(user),

                    const SizedBox(height: 16),

                    // ===== 2. MAIN NAVIGATION TABS (Matching SettingsPage.tsx & SettingsSidebar.tsx) =====
                    _buildMainAccountTabs(),

                    const SizedBox(height: 16),

                    // ===== 3. ACTIVE TAB CONTENT (Profile, Security, Preferences) =====
                    _buildActiveMainTabContent(user),

                    const SizedBox(height: 20),

                    // ===== 4. LOGOUT & REPUTATION SUMMARY =====
                    _buildAccountSettingsCard(),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 1. HERO HEADER CARD ====================
  Widget _buildHeroHeaderCard(UserModel user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner & Avatar Stack with full height 195 to ensure 100% of hit-testing is within bounds!
          SizedBox(
            height: 195,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. Cover Banner Image (Top 0 to 150)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 150,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _coverBytes != null
                            ? Image.memory(_coverBytes!, fit: BoxFit.cover)
                            : (_pickedCover != null
                                ? (kIsWeb
                                    ? Image.network(_pickedCover!.path, fit: BoxFit.cover)
                                    : Image.file(File(_pickedCover!.path), fit: BoxFit.cover))
                                : buildAppImage(
                                    user.coverUrl,
                                    key: ValueKey('cover_${user.coverUrl}'),
                                    fit: BoxFit.cover,
                                    errorWidget: Container(
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [Color(0xFF064E3B), Color(0xFF134E4A), Color(0xFF0F172A)],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                    ),
                                  )),
                      ),
                      Positioned.fill(
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black54, Colors.transparent],
                            ),
                          ),
                        ),
                      ),
                      // Loading Spinner for Cover
                      if (_isUploadingCover)
                        Positioned.fill(
                          child: Container(
                            color: Colors.black45,
                            child: const Center(
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                            ),
                          ),
                        ),
                      // Button: Change Cover Photo
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isUploadingCover ? null : _pickCoverImage,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white38),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_isUploadingCover) ...[
                                    const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.8)),
                                    const SizedBox(width: 6),
                                    const Text('Đang lưu...', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                                  ] else ...[
                                    const Icon(Icons.camera_alt_outlined, size: 14, color: Colors.white),
                                    const SizedBox(width: 4),
                                    Text(
                                      _coverBytes != null ? 'Đổi ảnh bìa khác' : 'Đổi ảnh bìa',
                                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Overlapping Circular Avatar with Camera Edit Badge (Matching Web rounded-full)
                Positioned(
                  left: 20,
                  bottom: 0,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GestureDetector(
                        onTap: () => UserUtilityDrawerModal.show(
                          context,
                          initialUtility: UtilityType.favorites,
                          onNavigateTab: widget.onNavigateTab,
                        ),
                        child: Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color: const Color(0xFF047857).withValues(alpha: 0.08),
                                blurRadius: 20,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(3.5),
                          child: ClipOval(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                _avatarBytes != null
                                    ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                                    : (_pickedAvatar != null
                                        ? (kIsWeb
                                            ? Image.network(_pickedAvatar!.path, fit: BoxFit.cover)
                                            : Image.file(File(_pickedAvatar!.path), fit: BoxFit.cover))
                                        : buildAppImage(
                                            user.avatarUrl,
                                            key: ValueKey('avatar_${user.avatarUrl}'),
                                            fit: BoxFit.cover,
                                            errorWidget: Container(
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [Color(0xFF059669), Color(0xFF047857)],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                                                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Colors.white),
                                                ),
                                              ),
                                            ),
                                          )),
                                if (_isUploadingAvatar)
                                  Container(
                                    color: Colors.black45,
                                    child: const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: _isUploadingAvatar ? null : _pickAvatarImage,
                          child: Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: const Color(0xFF047857),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // User Profile Info & Badges
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                user.fullName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.4,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.shield_outlined, size: 12, color: Color(0xFF047857)),
                                    const SizedBox(width: 4),
                                    Text(
                                      user.jobTitle.isNotEmpty ? user.jobTitle : 'Thành viên',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF065F46),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.mail_outline, size: 13, color: Color(0xFF059669)),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  user.email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.check_circle, size: 13, color: Color(0xFF10B981)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Quick Score Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFD97706)),
                              const SizedBox(width: 4),
                              Text(
                                '${user.reviewsCount} điểm',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Quick Utility Drawer Trigger Button (Matching Share_Locations)
                        InkWell(
                          onTap: () => UserUtilityDrawerModal.show(
                            context,
                            onNavigateTab: widget.onNavigateTab,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFBFDBFE)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.apps_rounded, size: 13, color: Color(0xFF2563EB)),
                                SizedBox(width: 4),
                                Text(
                                  'Tiện ích',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1D4ED8)),
                                ),
                                SizedBox(width: 2),
                                Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF1D4ED8)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                if (user.bio.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    user.bio,
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 2. MAIN SETTINGS TABS ====================
  Widget _buildMainAccountTabs() {
    final navTabs = [
      {'title': 'Mục đã lưu', 'icon': Icons.bookmark_outline_rounded},
      {'title': 'Hồ sơ', 'icon': Icons.person_outline_rounded},
      {'title': 'Bảo mật', 'icon': Icons.lock_outline_rounded},
      {'title': 'Tùy chọn', 'icon': Icons.tune_rounded},
    ];

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: List.generate(navTabs.length, (index) {
          final isSelected = _mainTabIndex == index;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _mainTabIndex = index;
                    _profileError = null;
                    _profileSuccess = null;
                    _securityError = null;
                    _securitySuccess = null;
                  });
                },
                borderRadius: BorderRadius.circular(14),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF047857) : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        navTabs[index]['icon'] as IconData,
                        size: 15,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          navTabs[index]['title'] as String,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ==================== 3. ACTIVE MAIN TAB CONTENT ====================
  Widget _buildActiveMainTabContent(UserModel user) {
    switch (_mainTabIndex) {
      case 0:
        return const FavoritesSectionWidget();
      case 1:
        return _buildProfileSettingsTab(user);
      case 2:
        return _buildSecuritySettingsTab();
      case 3:
      default:
        return _buildPreferencesSettingsTab();
    }
  }

  // ==================== TAB 0: PROFILE SETTINGS (Matching ProfileSettingsTab.tsx) ====================
  Widget _buildProfileSettingsTab(UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.badge_outlined, size: 18, color: Color(0xFF047857)),
              SizedBox(width: 8),
              Text(
                'Chỉnh sửa thông tin cá nhân',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Cập nhật họ tên, ảnh đại diện, ảnh bìa và thông tin giới thiệu bản thân.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          if (_profileError != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Color(0xFFEF4444)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_profileError!, style: const TextStyle(fontSize: 12, color: Color(0xFFB91C1C))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (_profileSuccess != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_profileSuccess!, style: const TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ===== HÌNH ẢNH ĐẠI DIỆN & ẢNH BÌA (Matching ProfileSettingsTab.tsx) =====
          const Text(
            'HÌNH ẢNH ĐẠI DIỆN & ẢNH BÌA',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.4),
          ),
          const SizedBox(height: 8),

          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 450;
              return Flex(
                direction: isNarrow ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Avatar Card
                  Expanded(
                    flex: isNarrow ? 0 : 1,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ảnh đại diện (Hình tròn)',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              ClipOval(
                                child: Container(
                                  width: 54,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFECFDF5),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
                                  ),
                                  child: _avatarBytes != null
                                      ? Image.memory(_avatarBytes!, fit: BoxFit.cover)
                                      : (user.avatarUrl.isNotEmpty
                                          ? Image.network(
                                              user.avatarUrl,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                color: const Color(0xFF047857),
                                                child: Center(
                                                  child: Text(
                                                    user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Container(
                                              color: const Color(0xFF047857),
                                              child: Center(
                                                child: Text(
                                                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : 'U',
                                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                                ),
                                              ),
                                            )),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _isUploadingAvatar ? null : _pickAvatarImage,
                                      icon: _isUploadingAvatar
                                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Color(0xFF047857), strokeWidth: 1.5))
                                          : const Icon(Icons.upload_rounded, size: 14, color: Color(0xFF047857)),
                                      label: Text(
                                        _avatarBytes != null || user.avatarUrl.isNotEmpty ? 'Đổi ảnh khác' : 'Tải ảnh đại diện',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: const Color(0xFF0F172A),
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                                        ),
                                      ),
                                    ),
                                    if (_avatarBytes != null) ...[
                                      const SizedBox(height: 4),
                                      InkWell(
                                        onTap: _clearPickedAvatar,
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(vertical: 2),
                                          child: Text(
                                            'Xóa ảnh đã chọn',
                                            style: TextStyle(fontSize: 10.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (isNarrow) const SizedBox(height: 10) else const SizedBox(width: 12),

                  // 2. Cover Card
                  Expanded(
                    flex: isNarrow ? 0 : 1,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ảnh bìa hồ sơ',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: double.infinity,
                              height: 54,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: _coverBytes != null
                                  ? Image.memory(_coverBytes!, fit: BoxFit.cover, width: double.infinity)
                                  : (user.coverUrl.isNotEmpty
                                      ? Image.network(
                                          user.coverUrl,
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            color: const Color(0xFF064E3B),
                                            child: const Center(
                                              child: Text('Ảnh bìa mặc định', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                            ),
                                          ),
                                        )
                                      : Container(
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [Color(0xFF064E3B), Color(0xFF134E4A), Color(0xFF0F172A)],
                                            ),
                                          ),
                                          child: const Center(
                                            child: Text('Ảnh bìa mặc định', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                          ),
                                        )),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _isUploadingCover ? null : _pickCoverImage,
                                icon: _isUploadingCover
                                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Color(0xFF047857), strokeWidth: 1.5))
                                    : const Icon(Icons.drive_folder_upload_outlined, size: 14, color: Color(0xFF047857)),
                                label: Text(
                                  _coverBytes != null || user.coverUrl.isNotEmpty ? 'Đổi ảnh khác' : 'Tải ảnh bìa từ máy',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF0F172A),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  ),
                                ),
                              ),
                              if (_coverBytes != null) ...[
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: _clearPickedCover,
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      'Xóa ảnh',
                                      style: TextStyle(fontSize: 10.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // Form fields
          // 1. Full Name
          const Text('HỌ VÀ TÊN *', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          TextField(
            controller: _fullNameController,
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.person_outline, size: 18, color: Color(0xFF64748B)),
              hintText: 'Nhập họ và tên đầy đủ',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5)),
            ),
          ),
          const SizedBox(height: 14),

          // 2. Email (Readonly)
          const Text('ĐỊA CHỈ EMAIL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          TextField(
            readOnly: true,
            controller: TextEditingController(text: user.email),
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.mail_outline, size: 18, color: Color(0xFF94A3B8)),
              suffixIcon: const Padding(
                padding: EdgeInsets.only(right: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
                    SizedBox(width: 4),
                    Text('Đã xác thực', style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            ),
          ),
          const SizedBox(height: 14),

          // 3. Phone
          const Text('SỐ ĐIỆN THOẠI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF64748B)),
              hintText: 'Nhập số điện thoại liên hệ (VD: 0912 345 678)',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5)),
            ),
          ),
          const SizedBox(height: 14),

          // 4. Bio
          const Text('GIỚI THIỆU BẢN THÂN / TIỂU SỬ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF475569))),
          const SizedBox(height: 6),
          TextField(
            controller: _bioController,
            maxLines: 3,
            maxLength: 500,
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), height: 1.4),
            decoration: InputDecoration(
              hintText: 'Chia sẻ ngắn gọn về sở thích xê dịch, gu du lịch hoặc câu nói yêu thích...',
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5)),
            ),
          ),
          const SizedBox(height: 16),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isSavingProfile ? null : _handleSaveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isSavingProfile
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Lưu thay đổi', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== TAB 1: SECURITY SETTINGS (Matching SecuritySettingsTab.tsx) ====================
  Widget _buildSecuritySettingsTab() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.security_outlined, size: 18, color: Color(0xFF047857)),
              SizedBox(width: 8),
              Text(
                'Đổi mật khẩu & Bảo mật tài khoản',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Quản lý mật khẩu đăng nhập để bảo vệ an toàn cho tài khoản và dữ liệu du lịch của bạn.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          // Security Alert Card (Matching SecuritySettingsTab.tsx)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFDE68A).withValues(alpha: 0.8)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_user_outlined, size: 18, color: Color(0xFFD97706)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Tiêu chuẩn mật khẩu an toàn:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Mật khẩu phải có tối thiểu 6 ký tự. Hãy kết hợp chữ cái viết hoa, viết thường và các chữ số để tài khoản được bảo vệ tốt nhất.',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF334155), height: 1.45),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_securityError != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 16, color: Color(0xFFE11D48)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_securityError!, style: const TextStyle(fontSize: 12, color: Color(0xFFE11D48), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          if (_securitySuccess != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_securitySuccess!, style: const TextStyle(fontSize: 12, color: Color(0xFF047857), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 1. Current Password
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'MẬT KHẨU HIỆN TẠI',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF334155), letterSpacing: 0.4),
                ),
                TextSpan(
                  text: ' *',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF43F5E)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _currentPasswordController,
            obscureText: !_showCurrentPassword,
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18, color: Color(0xFF94A3B8)),
              suffixIcon: IconButton(
                icon: Icon(_showCurrentPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: const Color(0xFF94A3B8)),
                onPressed: () => setState(() => _showCurrentPassword = !_showCurrentPassword),
              ),
              hintText: 'Nhập mật khẩu đang dùng',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5)),
            ),
          ),
          const SizedBox(height: 14),

          // 2. New Password
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'MẬT KHẨU MỚI',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF334155), letterSpacing: 0.4),
                ),
                TextSpan(
                  text: ' *',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF43F5E)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _newPasswordController,
            obscureText: !_showNewPassword,
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
              suffixIcon: IconButton(
                icon: Icon(_showNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: const Color(0xFF94A3B8)),
                onPressed: () => setState(() => _showNewPassword = !_showNewPassword),
              ),
              hintText: 'Tối thiểu 6 ký tự',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5)),
            ),
          ),
          const SizedBox(height: 14),

          // 3. Confirm New Password
          RichText(
            text: const TextSpan(
              children: [
                TextSpan(
                  text: 'XÁC NHẬN MẬT KHẨU MỚI',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF334155), letterSpacing: 0.4),
                ),
                TextSpan(
                  text: ' *',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF43F5E)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _confirmPasswordController,
            obscureText: !_showConfirmPassword,
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF94A3B8)),
              suffixIcon: IconButton(
                icon: Icon(_showConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: const Color(0xFF94A3B8)),
                onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
              ),
              hintText: 'Nhập lại mật khẩu mới',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF047857), width: 1.5)),
            ),
          ),
          const SizedBox(height: 18),

          // Submit Button (Matching SecuritySettingsTab.tsx)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton(
                onPressed: _isUpdatingPassword ? null : _handleUpdatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  disabledBackgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.7),
                ),
                child: _isUpdatingPassword
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Cập nhật mật khẩu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== TAB 2: PREFERENCES SETTINGS (Matching PreferencesSettingsTab.tsx) ====================
  Widget _buildPreferencesSettingsTab() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.tune_outlined, size: 18, color: Color(0xFF047857)),
              SizedBox(width: 8),
              Text(
                'Tùy chọn & Quyền riêng tư',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Tùy chỉnh thông báo tương tác và thiết lập hiển thị hành trình trên cộng đồng.',
            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          if (_prefSuccess != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_prefSuccess!, style: const TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Card 1: Notifications
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'THÔNG BÁO & TƯƠNG TÁC CỘNG ĐỒNG',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.3),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeThumbColor: const Color(0xFF047857),
                  title: const Text('Thông báo phản hồi đánh giá', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  subtitle: const Text('Nhận thông báo khi có người trả lời hoặc thả cảm xúc đánh giá của bạn', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  value: _prefNotifyReviews,
                  onChanged: (val) => setState(() => _prefNotifyReviews = val),
                ),
                const Divider(height: 12, color: Color(0xFFE2E8F0)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeThumbColor: const Color(0xFF047857),
                  title: const Text('Thông báo bài viết & bình luận', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  subtitle: const Text('Nhận cập nhật khi bài viết cẩm nang được kiểm duyệt hoặc có bình luận mới', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  value: _prefNotifyComments,
                  onChanged: (val) => setState(() => _prefNotifyComments = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Card 2: Privacy
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'QUYỀN RIÊNG TƯ MẶC ĐỊNH',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: 0.3),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  activeThumbColor: const Color(0xFF047857),
                  title: const Text('Nhật ký hành trình công khai', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                  subtitle: const Text('Cho phép người dùng khác xem các chuyến đi được chia sẻ của bạn', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                  value: _prefPublicLogs,
                  onChanged: (val) => setState(() => _prefPublicLogs = val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Save Preferences Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _handleSavePreferences,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.done_all_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Lưu tùy chọn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  // ==================== 4. ACCOUNT & LOGOUT CARD ====================
  Widget _buildAccountSettingsCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified_user_outlined, size: 20, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bảo mật & Phiên hoạt động',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tài khoản đang đăng nhập trên thiết bị này',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
                side: const BorderSide(color: Color(0xFFFCA5A5)),
                backgroundColor: const Color(0xFFFEF2F2),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text(
                'Đăng xuất khỏi thiết bị',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
              ),
              onPressed: _showLogoutConfirmDialog,
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text('Xác nhận đăng xuất', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Bạn có chắc chắn muốn đăng xuất khỏi tài khoản trên ứng dụng này không?',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _authService.logout();
              if (mounted) {
                _loadProfile(forceRefresh: true);
              }
            },
            child: const Text('Đăng xuất', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==================== GUEST / UNAUTHENTICATED VIEW ====================
  Widget _buildGuestView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // Hero Avatar & Greeting Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF047857), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF047857).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  size: 48,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Chào mừng bạn đến với LangThang',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Đăng nhập để đồng bộ thông tin tài khoản, lưu các điểm đến yêu thích, viết đánh giá và chia sẻ cẩm nang của riêng bạn.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 26),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.login_rounded, size: 18),
                      label: const Text(
                        'Đăng nhập ngay',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoginScreen(redirectToHome: true),
                          ),
                        ).then((_) {
                          _loadProfile(forceRefresh: true);
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Tạo tài khoản',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        ).then((_) {
                          _loadProfile(forceRefresh: true);
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Features Highlight
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Quyền lợi khi có tài khoản',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
        ),
        const SizedBox(height: 12),

        _buildGuestFeatureTile(
          icon: Icons.bookmark_added_outlined,
          color: const Color(0xFF047857),
          title: 'Lưu & Đồng bộ địa điểm',
          description: 'Lưu lại điểm đến, quán ăn và cẩm nang du lịch yêu thích mọi lúc mọi nơi.',
        ),
        const SizedBox(height: 10),
        _buildGuestFeatureTile(
          icon: Icons.rate_review_outlined,
          color: const Color(0xFF3B82F6),
          title: 'Viết đánh giá & Đăng ảnh',
          description: 'Chia sẻ trải nghiệm thực tế và cảm nhận của bạn cùng cộng đồng du lịch.',
        ),
        const SizedBox(height: 10),
        _buildGuestFeatureTile(
          icon: Icons.add_location_alt_outlined,
          color: const Color(0xFFF59E0B),
          title: 'Đề xuất địa điểm mới',
          description: 'Góp phần giới thiệu những nét đẹp cảnh sắc và văn hóa ẩm thực Việt Nam.',
        ),

        const SizedBox(height: 24),

        // App Information Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF94A3B8), size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'LangThang App • Phiên bản 1.0.0',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGuestFeatureTile({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
