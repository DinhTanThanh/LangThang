import 'package:flutter/material.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';

class ItineraryAuthGate extends StatelessWidget {
  final VoidCallback? onAuthSuccess;

  const ItineraryAuthGate({
    super.key,
    this.onAuthSuccess,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Lock Icon Container
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: const Center(
                child: Icon(
                  Icons.lock_rounded,
                  size: 32,
                  color: Color(0xFF047857),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Amber Pill Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.shield_outlined, size: 14, color: Color(0xFFD97706)),
                  SizedBox(width: 6),
                  Text(
                    'NỘI DUNG DÀNH RIÊNG CHO THÀNH VIÊN',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF92400E),
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Heading
            const Text(
              'Đăng nhập để mở khóa toàn bộ lịch trình',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111827),
                letterSpacing: -0.3,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 8),

            // Description
            const Text(
              'Để xem chi tiết lộ trình từng ngày (Sáng, Trưa, Chiều, Tối), ước tính chi phí, vị trí tọa độ bản đồ và lưu lịch trình vào bộ sưu tập cá nhân, vui lòng đăng nhập vào tài khoản của bạn.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF4B5563),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),

            // Action Buttons
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                      );
                      onAuthSuccess?.call();
                    },
                    icon: const Icon(Icons.login_rounded, size: 18, color: Colors.white),
                    label: const Text(
                      'Đăng nhập ngay',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );
                      onAuthSuccess?.call();
                    },
                    icon: const Icon(Icons.person_add_outlined, size: 18, color: Color(0xFF1F2937)),
                    label: const Text(
                      'Tạo tài khoản mới',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFF9FAFB),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 18),

            // Benefit feature cards
            Column(
              children: [
                _buildBenefitRow(
                  title: 'Tiết kiệm thời gian',
                  desc: 'Lộ trình được sắp xếp khoa học, tránh đi lại ngược đường.',
                ),
                const SizedBox(height: 10),
                _buildBenefitRow(
                  title: 'Dự toán chi phí',
                  desc: 'Bảng giá tham khảo chi tiết vé tham quan, ăn uống và khách sạn.',
                ),
                const SizedBox(height: 10),
                _buildBenefitRow(
                  title: 'Tùy biến linh hoạt',
                  desc: 'Dễ dàng lưu lại và điều chỉnh theo sở thích riêng của bạn.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitRow({required String title, required String desc}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.auto_awesome_rounded, size: 15, color: Color(0xFF059669)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
