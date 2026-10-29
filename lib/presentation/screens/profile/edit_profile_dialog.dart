import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/image_utils.dart';
import '../../../data/models/user_model.dart';

class EditProfileDialog extends StatefulWidget {
  final UserModel user;
  final Future<String?> Function({
    required UserModel updatedUser,
    String? avatarFilePath,
    String? coverFilePath,
  }) onSave;

  const EditProfileDialog({
    super.key,
    required this.user,
    required this.onSave,
  });

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;

  XFile? _avatarFile;
  XFile? _coverFile;

  bool _isSaving = false;
  String? _errorMessage;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _phoneController = TextEditingController(text: widget.user.phone);
    _bioController = TextEditingController(text: widget.user.bio);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _avatarFile = picked;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Không thể chọn ảnh đại diện: $e');
    }
  }

  Future<void> _pickCover() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null) {
        setState(() {
          _coverFile = picked;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Không thể chọn ảnh bìa: $e');
    }
  }

  void _clearAvatar() {
    setState(() => _avatarFile = null);
  }

  void _clearCover() {
    setState(() => _coverFile = null);
  }

  Future<void> _handleSave() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || name.length < 2) {
      setState(() => _errorMessage = 'Họ và tên phải từ 2 đến 50 ký tự.');
      return;
    }
    if (name.length > 50) {
      setState(() => _errorMessage = 'Họ và tên không được vượt quá 50 ký tự.');
      return;
    }

    final phone = _phoneController.text.trim();
    if (phone.length > 20) {
      setState(() => _errorMessage = 'Số điện thoại không được vượt quá 20 ký tự.');
      return;
    }

    final bio = _bioController.text.trim();
    if (bio.length > 500) {
      setState(() => _errorMessage = 'Tiểu sử không được vượt quá 500 ký tự.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    final updated = widget.user.copyWith(
      fullName: name,
      phone: phone,
      bio: bio,
    );

    final error = await widget.onSave(
      updatedUser: updated,
      avatarFilePath: _avatarFile?.path,
      coverFilePath: _coverFile?.path,
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
        _errorMessage = error;
      });
      if (error == null) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chỉnh sửa thông tin cá nhân',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  InkWell(
                    onTap: _isSaving ? null : () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
            ),

            // Modal Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // SECTION 1: THÔNG TIN CƠ BẢN
                    const Text(
                      'THÔNG TIN CƠ BẢN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Họ và tên
                    _buildInputLabel('Họ và tên', isRequired: true),
                    const SizedBox(height: 6),
                    _buildInputField(
                      controller: _nameController,
                      hintText: 'Nhập họ và tên đầy đủ',
                      prefixIcon: Icons.person_outline,
                      maxLength: 50,
                    ),
                    const SizedBox(height: 14),

                    // Số điện thoại
                    _buildInputLabel('Số điện thoại'),
                    const SizedBox(height: 6),
                    _buildInputField(
                      controller: _phoneController,
                      hintText: '0912 345 678',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      maxLength: 20,
                    ),
                    _buildInputLabel('Tiểu sử (Bio)'),
                    const SizedBox(height: 6),
                    _buildInputField(
                      controller: _bioController,
                      hintText: 'Viết đôi dòng giới thiệu bản thân và đam mê du lịch...',
                      prefixIcon: Icons.description_outlined,
                      maxLines: 3,
                      maxLength: 500,
                    ),
                    const SizedBox(height: 20),

                    // SECTION 2: HÌNH ẢNH HỒ SƠ (TẢI LÊN TỪ THIẾT BỊ)
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 16),
                    const Text(
                      'HÌNH ẢNH HỒ SƠ (TẢI LÊN TỪ THIẾT BỊ)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Ảnh đại diện (Avatar)
                    _buildInputLabel('Ảnh đại diện (Avatar - Tối đa 5MB)'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Avatar Preview
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: _avatarFile != null
                              ? (kIsWeb
                                  ? Image.network(_avatarFile!.path, fit: BoxFit.cover)
                                  : Image.file(File(_avatarFile!.path), fit: BoxFit.cover))
                              : buildAppImage(
                                  widget.user.avatarUrl,
                                  fit: BoxFit.cover,
                                  errorWidget: Image.network(
                                    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=200&auto=format&fit=crop',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                        const SizedBox(width: 12),
                        // Avatar buttons
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _isSaving ? null : _pickAvatar,
                                icon: const Icon(Icons.upload_outlined, size: 15, color: Color(0xFF334155)),
                                label: Text(
                                  _avatarFile != null ? 'Chọn ảnh khác' : 'Tải ảnh đại diện',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                ),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF1F5F9),
                                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              if (_avatarFile != null)
                                TextButton.icon(
                                  onPressed: _isSaving ? null : _clearAvatar,
                                  icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFDC2626)),
                                  label: const Text(
                                    'Hủy',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Ảnh bìa (Cover Banner)
                    _buildInputLabel('Ảnh bìa (Cover Banner - Tối đa 5MB)'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 90,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: _coverFile != null
                          ? (kIsWeb
                              ? Image.network(_coverFile!.path, fit: BoxFit.cover, width: double.infinity)
                              : Image.file(File(_coverFile!.path), fit: BoxFit.cover, width: double.infinity))
                          : buildAppImage(
                              widget.user.coverUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorWidget: Image.network(
                                'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?q=80&w=1920&auto=format&fit=crop',
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _pickCover,
                          icon: const Icon(Icons.upload_outlined, size: 15, color: Color(0xFF334155)),
                          label: Text(
                            _coverFile != null ? 'Chọn ảnh khác' : 'Tải ảnh bìa mới',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F5F9),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        if (_coverFile != null)
                          TextButton.icon(
                            onPressed: _isSaving ? null : _clearCover,
                            icon: const Icon(Icons.delete_outline, size: 15, color: Color(0xFFDC2626)),
                            label: const Text(
                              'Hủy',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Modal Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    child: const Text(
                      'Hủy',
                      style: TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _isSaving ? null : _handleSave,
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Lưu thay đổi',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Color(0xFF334155),
        ),
        children: [
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    int maxLines = 1,
    int? maxLength,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      autocorrect: false,
      enableSuggestions: false,
      smartDashesType: SmartDashesType.disabled,
      smartQuotesType: SmartQuotesType.disabled,
      style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
        prefixIcon: Icon(prefixIcon, size: 18, color: const Color(0xFF94A3B8)),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
