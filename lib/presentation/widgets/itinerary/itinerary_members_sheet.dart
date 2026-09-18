import 'package:flutter/material.dart';
import '../../../data/models/itinerary_model.dart';

class ItineraryMembersSheet extends StatefulWidget {
  final List<TripMemberModel> members;
  final ValueChanged<List<TripMemberModel>> onMembersChanged;

  const ItineraryMembersSheet({
    super.key,
    required this.members,
    required this.onMembersChanged,
  });

  static void show(
    BuildContext context, {
    required List<TripMemberModel> members,
    required ValueChanged<List<TripMemberModel>> onMembersChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ItineraryMembersSheet(
        members: members,
        onMembersChanged: onMembersChanged,
      ),
    );
  }

  @override
  State<ItineraryMembersSheet> createState() => _ItineraryMembersSheetState();
}

class _ItineraryMembersSheetState extends State<ItineraryMembersSheet> {
  late List<TripMemberModel> _currentMembers;
  final TextEditingController _inviteEmailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentMembers = List.from(widget.members);
    if (_currentMembers.isEmpty) {
      _currentMembers.add(
        const TripMemberModel(
          id: 1,
          name: 'Bạn (Trưởng đoàn)',
          avatar: null,
          role: 'Owner',
        ),
      );
    }
  }

  @override
  void dispose() {
    _inviteEmailController.dispose();
    super.dispose();
  }

  void _handleAddMember() {
    final email = _inviteEmailController.text.trim();
    if (email.isEmpty) return;

    final newMember = TripMemberModel(
      id: DateTime.now().millisecondsSinceEpoch % 10000,
      name: email.split('@').first,
      email: email,
      role: 'Member',
    );

    setState(() {
      _currentMembers.add(newMember);
      _inviteEmailController.clear();
    });
    widget.onMembersChanged(_currentMembers);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã gửi lời mời tham gia đến $email!'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.group_rounded, color: Color(0xFF059669), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Thành viên chuyến đi (${_currentMembers.length})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF3F4F6)),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Invite Box
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
                        const Text(
                          'Mời bạn bè cùng lên lịch trình',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _inviteEmailController,
                                decoration: InputDecoration(
                                  hintText: 'Nhập email hoặc tên bạn bè...',
                                  hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
                                  isDense: true,
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _handleAddMember,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF059669),
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              child: const Text(
                                'Mời',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Members List
                  const Text(
                    'Danh sách người tham gia',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 8),

                  ..._currentMembers.map((member) {
                    final isOwner = member.role == 'Owner';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: isOwner ? const Color(0xFF059669) : const Color(0xFF3B82F6),
                            backgroundImage: member.avatar != null && member.avatar!.isNotEmpty
                                ? NetworkImage(member.avatar!)
                                : null,
                            child: member.avatar == null || member.avatar!.isEmpty
                                ? Text(
                                    member.name.isNotEmpty ? member.name[0].toUpperCase() : 'M',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.name,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                                ),
                                if (member.email.isNotEmpty)
                                  Text(
                                    member.email,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isOwner ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: isOwner ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE)),
                            ),
                            child: Text(
                              isOwner ? 'Trưởng đoàn' : (member.role == 'Editor' ? 'Chỉnh sửa' : 'Xem'),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isOwner ? const Color(0xFF92400E) : const Color(0xFF1D4ED8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
