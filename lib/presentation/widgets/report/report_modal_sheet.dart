import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../data/models/report_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/report_api_service.dart';
import '../../screens/auth/login_screen.dart';

enum ReportModalView { form, guide, history }

class ReportModalSheet extends StatefulWidget {
  final ReportTargetInfo targetInfo;
  final ReportModalView defaultView;
  final VoidCallback? onReportSubmitted;

  const ReportModalSheet({
    super.key,
    required this.targetInfo,
    this.defaultView = ReportModalView.form,
    this.onReportSubmitted,
  });

  /// Universal static method to show the Report Modal from anywhere
  static Future<void> show(
    BuildContext context, {
    required ReportTargetInfo targetInfo,
    ReportModalView defaultView = ReportModalView.form,
    VoidCallback? onReportSubmitted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportModalSheet(
        targetInfo: targetInfo,
        defaultView: defaultView,
        onReportSubmitted: onReportSubmitted,
      ),
    );
  }

  @override
  State<ReportModalSheet> createState() => _ReportModalSheetState();
}

class _ReportModalSheetState extends State<ReportModalSheet> {
  final ReportApiService _apiService = ReportApiService();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _contactEmailController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  late ReportModalView _currentView;
  List<ReportReasonModel> _reasons = [];
  List<SubmittedUserReport> _myReports = [];
  bool _isLoadingReasons = true;
  bool _isLoadingHistory = false;

  String? _selectedReasonCode;
  String? _selectedReasonName;
  XFile? _evidenceImage;
  bool _isSubmitting = false;
  SubmittedUserReport? _submittedReport;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _currentView = widget.defaultView;
    _loadReasons();
    _loadHistory();
  }

  @override
  void dispose() {
    _descController.dispose();
    _contactEmailController.dispose();
    super.dispose();
  }

  Future<bool> _ensureAuthenticated({bool forceLogin = false}) async {
    if (!forceLogin) {
      final token = await AuthService().getAccessToken();
      final hasToken = token != null && token.isNotEmpty && !token.startsWith('google_session_token_');
      if (hasToken) return true;
    }

    if (!mounted) return false;

    final shouldLogin = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.lock_person_rounded, color: Color(0xFFD97706), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                forceLogin ? 'Phiên đăng nhập hết hạn' : 'Yêu cầu đăng nhập',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              forceLogin
                  ? 'Phiên đăng nhập của bạn đã hết hạn. Vui lòng đăng nhập lại để hệ thống lưu báo cáo vào Database.'
                  : 'Bạn cần đăng nhập tài khoản để gửi báo cáo vi phạm và lưu trực tiếp vào cơ sở dữ liệu hệ thống.',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF475569), height: 1.45),
            ),
            const SizedBox(height: 12),
            const Text(
              '✨ Toàn bộ lý do và nội dung bạn đang chọn sẽ được giữ nguyên 100%!',
              style: TextStyle(fontSize: 12, color: Color(0xFF166534), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy bỏ', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Đăng nhập ngay', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (shouldLogin == true && mounted) {
      final loggedIn = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return loggedIn == true;
    }
    return false;
  }

  Future<void> _loadReasons() async {
    setState(() => _isLoadingReasons = true);
    final res = await _apiService.getReportReasons(targetType: widget.targetInfo.targetType);
    if (mounted) {
      setState(() {
        _reasons = res.data ?? [];
        if (_reasons.isNotEmpty && _selectedReasonCode == null) {
          _selectedReasonCode = _reasons.first.code;
          _selectedReasonName = _reasons.first.name;
        }
        _isLoadingReasons = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    final res = await _apiService.getMyReports();
    if (mounted) {
      setState(() {
        _myReports = res.data ?? [];
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final img = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (img != null && mounted) {
        setState(() {
          _evidenceImage = img;
        });
      }
    } catch (e) {
      debugPrint('[ReportModalSheet] pick image error: $e');
    }
  }

  void _showImagePickerSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF059669)),
                title: const Text('Chọn ảnh từ Thư viện', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF059669)),
                title: const Text('Chụp ảnh bằng Máy ảnh', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_selectedReasonCode == null) {
      setState(() => _errorMsg = 'Vui lòng chọn một lý do vi phạm');
      return;
    }

    final isAuthed = await _ensureAuthenticated();
    if (!isAuthed) return;

    setState(() {
      _isSubmitting = true;
      _errorMsg = '';
    });

    final reasonObj = _reasons.firstWhere(
      (r) => r.code == _selectedReasonCode,
      orElse: () => ReportReasonModel(
        code: _selectedReasonCode ?? 'OTHER',
        name: _selectedReasonName ?? 'Vi phạm quy định',
      ),
    );

    try {
      final res = await _apiService.submitReport(
        targetInfo: widget.targetInfo,
        reasonCode: reasonObj.code,
        reasonName: reasonObj.name,
        reasonId: reasonObj.id,
        description: _descController.text.trim(),
        evidenceUrl: _evidenceImage?.path,
        contactEmail: _contactEmailController.text.trim(),
      );

      if (mounted) {
        setState(() => _isSubmitting = false);

        if (res.code == '401') {
          setState(() {
            _errorMsg = res.message;
          });
          final reAuthed = await _ensureAuthenticated(forceLogin: true);
          if (reAuthed && mounted) {
            _handleSubmit();
          }
          return;
        }

        if (res.success && res.data != null) {
          setState(() {
            _submittedReport = res.data;
            _myReports.insert(0, res.data!);
          });
          widget.onReportSubmitted?.call();
        } else {
          setState(() {
            _errorMsg = res.message.isNotEmpty ? res.message : 'Có lỗi khi gửi báo cáo.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMsg = 'Lỗi kết nối. Vui lòng thử lại.';
        });
      }
    }
  }

  String _getModalTitle() {
    if (_currentView == ReportModalView.guide) {
      return 'Quy chuẩn báo cáo vi phạm';
    }
    if (_currentView == ReportModalView.history) {
      return 'Lịch sử báo cáo của bạn';
    }
    switch (widget.targetInfo.targetType) {
      case ReportTargetType.place:
        return 'Báo cáo Quán ăn / Địa điểm';
      case ReportTargetType.review:
        return 'Báo cáo Đánh giá vi phạm';
      case ReportTargetType.comment:
        return 'Báo cáo Bình luận vi phạm';
      case ReportTargetType.blog:
        return 'Báo cáo Bài viết vi phạm';
      case ReportTargetType.food:
        return 'Báo cáo Món ăn đặc sản';
      case ReportTargetType.photo:
        return 'Báo cáo Hình ảnh vi phạm';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      margin: EdgeInsets.only(
        left: 12,
        right: 12,
        bottom: bottomInset > 0 ? bottomInset + 10 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle bar
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          _buildHeader(),

          // Body Views (Success / Guide / History / Form)
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              child: _submittedReport != null
                  ? _buildSuccessView()
                  : _currentView == ReportModalView.guide
                      ? _buildGuideView()
                      : _currentView == ReportModalView.history
                          ? _buildHistoryView()
                          : _buildFormView(),
            ),
          ),

          // Footer Action Bar (Only shown for Form view when not submitted)
          if (_submittedReport == null && _currentView == ReportModalView.form)
            _buildFooter(),
        ],
      ),
    );
  }

  // ==================== 1. HEADER ====================
  Widget _buildHeader() {
    final isSubView = _currentView != ReportModalView.form && _submittedReport == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (isSubView)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => setState(() => _currentView = ReportModalView.form),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 15,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECDD3)),
              ),
              child: const Icon(
                Icons.flag_rounded,
                size: 18,
                color: Color(0xFFE11D48),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getModalTitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 1),
                const Text(
                  'Gửi phản hồi ẩn danh tới Quản trị viên để kiểm duyệt',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 17,
                  color: Color(0xFF64748B),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 2. FORM VIEW ====================
  Widget _buildFormView() {
    final target = widget.targetInfo;
    final type = target.targetType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Target Summary Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: type.backgroundColor,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: type.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(type.icon, size: 12, color: type.color),
                        const SizedBox(width: 4),
                        Text(
                          type.displayName,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: type.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (target.targetRating != null && target.targetRating! > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 12, color: Color(0xFFD97706)),
                          const SizedBox(width: 2),
                          Text(
                            target.targetRating!.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                target.targetTitle,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              if (target.targetSubtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  target.targetSubtitle!,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
              ],
              if (target.targetContent != null && target.targetContent!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    '"${target.targetContent}"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF374151),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Reasons selection
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: const [
                Text(
                  'Chọn lý do vi phạm',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(' *', style: TextStyle(color: Color(0xFFE11D48), fontWeight: FontWeight.bold)),
              ],
            ),
            InkWell(
              onTap: () => setState(() => _currentView = ReportModalView.guide),
              child: Row(
                children: const [
                  Icon(Icons.help_outline_rounded, size: 13, color: Color(0xFF2563EB)),
                  SizedBox(width: 3),
                  Text(
                    'Xem quy chuẩn',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        if (_isLoadingReasons)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE11D48)),
              ),
            ),
          )
        else
          Column(
            children: _reasons.map((reason) {
              final isSelected = _selectedReasonCode == reason.code;
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFFF1F2) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFFE11D48) : const Color(0xFFE5E7EB),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _selectedReasonCode = reason.code;
                      _selectedReasonName = reason.name;
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? const Color(0xFFE11D48) : const Color(0xFF9CA3AF),
                              width: isSelected ? 4.5 : 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                reason.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? const Color(0xFF881337) : const Color(0xFF1F2937),
                                ),
                              ),
                              if (reason.description != null && reason.description!.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  reason.description!,
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    color: isSelected ? const Color(0xFF9F1239) : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

        const SizedBox(height: 12),

        // Detailed Description Input
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mô tả chi tiết vi phạm',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
              ),
            ),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _descController,
              builder: (context, value, child) {
                return Text(
                  '${value.text.length}/500 ký tự',
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF9CA3AF)),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 6),

        TextField(
          controller: _descController,
          maxLines: 3,
          maxLength: 500,
          style: const TextStyle(fontSize: 12, color: Color(0xFF111827)),
          decoration: InputDecoration(
            hintText: 'Vui lòng cung cấp thêm thông tin hoặc dẫn chứng để Quản trị viên dễ dàng xác minh...',
            hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF)),
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.all(10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5),
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Photo Attachment
        const Text(
          'Ảnh bằng chứng (tùy chọn)',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111827),
          ),
        ),

        const SizedBox(height: 6),

        if (_evidenceImage != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF1F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFECDD3)),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: kIsWeb
                      ? Image.network(
                          _evidenceImage!.path,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, e, s) => const Icon(Icons.broken_image, size: 28),
                        )
                      : Image.file(
                          File(_evidenceImage!.path),
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, e, s) => const Icon(Icons.broken_image, size: 28),
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _evidenceImage!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF881337),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Đã đính kèm ảnh bằng chứng',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF9F1239)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _evidenceImage = null),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFE11D48)),
                  tooltip: 'Xóa ảnh',
                ),
              ],
            ),
          )
        else
          InkWell(
            onTap: _showImagePickerSheet,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD1D5DB), style: BorderStyle.solid),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.cloud_upload_outlined, size: 18, color: Color(0xFF6B7280)),
                  SizedBox(width: 8),
                  Text(
                    'Tải lên ảnh chụp màn hình vi phạm',
                    style: TextStyle(fontSize: 12, color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 10),

        // Anonymous Guarantee
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFECFDF5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFA7F3D0)),
          ),
          child: Row(
            children: const [
              Icon(Icons.verified_user_rounded, size: 16, color: Color(0xFF059669)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Báo cáo của bạn được gửi ẩn danh và bảo mật tuyệt đối.',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF065F46)),
                ),
              ),
            ],
          ),
        ),

        if (_errorMsg.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            _errorMsg,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFE11D48)),
          ),
        ],
      ],
    );
  }

  // ==================== 3. FOOTER ====================
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFFF9FAFB),
        border: Border(top: BorderSide(color: Color(0xFFF3F4F6))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () => setState(() => _currentView = ReportModalView.history),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              foregroundColor: const Color(0xFF6B7280),
            ),
            child: Text(
              'Lịch sử (${_myReports.length})',
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFE5E7EB),
                  foregroundColor: const Color(0xFF374151),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Hủy bỏ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSubmitting || _selectedReasonCode == null ? null : _handleSubmit,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded, size: 14, color: Colors.white),
                label: Text(
                  _isSubmitting ? 'Đang gửi...' : 'Gửi Báo Cáo',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE11D48),
                  disabledBackgroundColor: const Color(0xFFD1D5DB),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==================== 4. SUCCESS VIEW ====================
  Widget _buildSuccessView() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 38,
              color: Color(0xFF059669),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Đã tiếp nhận báo cáo của bạn',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Mã theo dõi: ', style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              Text(
                '#REP-${_submittedReport?.id ?? 1024}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF065F46),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '• Đối tượng: ${widget.targetInfo.targetTitle}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Cảm ơn bạn đã hỗ trợ cộng đồng du lịch trung thực và văn minh. Đội ngũ điều phối viên sẽ kiểm tra và giải quyết trong vòng 24 giờ.',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF4B5563), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Đã hiểu & Đóng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 5. GUIDE VIEW ====================
  Widget _buildGuideView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: Color(0xFF1D4ED8),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Nguyên tắc tiếp nhận báo cáo',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E3A8A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Mọi thành viên đều có quyền báo cáo các nội dung vi phạm tiêu chuẩn cộng đồng, bao gồm thông tin sai lệch, đánh giá bôi nhọ hoặc spam phá hoại.',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Các lý do vi phạm phổ biến:',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _reasons.map((r) {
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6, right: 10),
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE11D48),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        if (r.description != null && r.description!.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            r.description!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: () => setState(() => _currentView = ReportModalView.form),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE11D48),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Tiến hành gửi báo cáo',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatReportDate(String raw) {
    if (raw.isEmpty || raw.toLowerCase().contains('vừa xong')) {
      return 'Vừa xong';
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    final local = parsed.toLocal();
    final diff = DateTime.now().difference(local);

    if (diff.inSeconds < 60) {
      return 'Vừa xong';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} phút trước';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} giờ trước';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} ngày trước';
    } else {
      final d = local.day.toString().padLeft(2, '0');
      final m = local.month.toString().padLeft(2, '0');
      final y = local.year;
      final h = local.hour.toString().padLeft(2, '0');
      final min = local.minute.toString().padLeft(2, '0');
      return '$d/$m/$y • $h:$min';
    }
  }

  // ==================== 6. HISTORY VIEW ====================
  Widget _buildHistoryView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Header Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, size: 16, color: Color(0xFF475569)),
                  const SizedBox(width: 6),
                  Text(
                    'Tổng số: ${_myReports.length} báo cáo',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
              if (_isLoadingHistory)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF059669)),
                )
              else
                TextButton.icon(
                  onPressed: _loadHistory,
                  icon: const Icon(Icons.refresh_rounded, size: 13, color: Color(0xFF059669)),
                  label: const Text(
                    'Làm mới',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        if (_myReports.isEmpty && !_isLoadingHistory)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.inbox_outlined,
                    size: 28,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Chưa có báo cáo nào',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Các nội dung bạn phản ánh sẽ hiển thị ở đây để bạn dễ dàng theo dõi tiến độ xử lý của Quản trị viên.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _myReports.map((rep) {
              final isPending = rep.status == 'pending';
              final isResolved = rep.status == 'resolved';

              // Clean up extracted reason and detail
              String reasonName = rep.reasonContent;
              String detailText = rep.description.trim();

              if (reasonName.contains(' - Chi tiết:')) {
                final parts = reasonName.split(' - Chi tiết:');
                reasonName = parts.first.trim();
                if (detailText.isEmpty && parts.length > 1) {
                  detailText = parts.sublist(1).join(' - Chi tiết:').trim();
                }
              }

              // Status badge styling
              Color statusBg;
              Color statusBorder;
              Color statusText;
              IconData statusIcon;
              String statusLabel;

              if (isPending) {
                statusBg = const Color(0xFFFFFBEB);
                statusBorder = const Color(0xFFFDE68A);
                statusText = const Color(0xFFB45309);
                statusIcon = Icons.schedule_rounded;
                statusLabel = 'Đang thẩm định';
              } else if (isResolved) {
                statusBg = const Color(0xFFECFDF5);
                statusBorder = const Color(0xFFA7F3D0);
                statusText = const Color(0xFF047857);
                statusIcon = Icons.check_circle_rounded;
                statusLabel = 'Đã xử lý';
              } else {
                statusBg = const Color(0xFFF1F5F9);
                statusBorder = const Color(0xFFCBD5E1);
                statusText = const Color(0xFF64748B);
                statusIcon = Icons.cancel_outlined;
                statusLabel = 'Đã đóng';
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Target Title + Status Tag
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 2, right: 8),
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: rep.targetType.backgroundColor,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Icon(
                            rep.targetType.icon,
                            size: 13,
                            color: rep.targetType.color,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            rep.targetTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusBorder),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 11.5, color: statusText),
                              const SizedBox(width: 4),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: statusText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Row 2: Reason Pill Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECDD3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flag_rounded, size: 12, color: Color(0xFFE11D48)),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              reasonName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFBE123C),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Row 3: User Detail Note Bubble (if any)
                    if (detailText.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.format_quote_rounded,
                              size: 15,
                              color: Color(0xFF94A3B8),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                detailText,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF334155),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Row 4: Admin Feedback Note (if resolved/reviewed)
                    if (rep.resolutionNote != null && rep.resolutionNote!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFA7F3D0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.admin_panel_settings_rounded, size: 13, color: Color(0xFF059669)),
                                SizedBox(width: 5),
                                Text(
                                  'Phản hồi từ Ban Quản Trị:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF065F46),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              rep.resolutionNote!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF047857),
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 8),

                    // Row 5: Metadata Footer (Time + Report ID)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 4),
                            Text(
                              'Gửi lúc: ${_formatReportDate(rep.submittedAt)}',
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '#REP-${rep.id}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
