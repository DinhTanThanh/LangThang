-- =========================================================================
-- Script SQL: Seed Thông báo thật cho người dùng trong database LangThang
-- Bảng: dbo.Notifications, dbo.Users, dbo.UserProfiles
-- =========================================================================

SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

-- 1. Đảm bảo có User "Dương Đức Thắng" làm Actor tương tác
DECLARE @ActorUserId BIGINT;
SELECT @ActorUserId = Id FROM dbo.Users WHERE Email = 'thang.duong@langthang.vn';

IF @ActorUserId IS NULL
BEGIN
    INSERT INTO dbo.Users (Email, PasswordHash, Status, CreatedAt, UpdatedAt, IsDeleted)
    VALUES ('thang.duong@langthang.vn', '$2a$11$lIZ54TvPYy.dhfpP7OIbhuouKwqm2YF82OTDtK/QR8fvLNOKU5uPu', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), 0);

    SET @ActorUserId = SCOPE_IDENTITY();

    INSERT INTO dbo.UserProfiles (UserId, FullName, AvatarUrl, Bio, ReputationScore, RankLevel, UpdatedAt)
    VALUES (@ActorUserId, N'Dương Đức Thắng', 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=300', N'Đam mê trải nghiệm và đánh giá địa điểm.', 85, N'Thổ địa', SYSUTCDATETIME());

    PRINT N'Đã tạo người dùng Dương Đức Thắng với ID: ' + CAST(@ActorUserId AS NVARCHAR(20));
END
ELSE
BEGIN
    UPDATE dbo.UserProfiles
    SET FullName = N'Dương Đức Thắng',
        AvatarUrl = COALESCE(AvatarUrl, 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=300')
    WHERE UserId = @ActorUserId;

    PRINT N'Người dùng Dương Đức Thắng đã tồn tại với ID: ' + CAST(@ActorUserId AS NVARCHAR(20));
END

-- 2. Thêm thông báo thật cho tài khoản dinhtanthanh19@gmail.com (UserId: 206)
DECLARE @TargetUserId BIGINT;
SELECT @TargetUserId = Id FROM dbo.Users WHERE Email = 'dinhtanthanh19@gmail.com';

IF @TargetUserId IS NOT NULL
BEGIN
    -- Xóa các thông báo trùng để tránh duplicate khi chạy lại script
    DELETE FROM dbo.Notifications 
    WHERE UserId = @TargetUserId 
      AND DeduplicationKey IN ('LIKE_THANG_206_1', 'LIKE_THANG_206_2', 'PROPOSAL_APPROVED_206', 'WELCOME_206');

    -- Thông báo 1: Lượt thích bài đánh giá (Hôm qua - Chưa đọc)
    INSERT INTO dbo.Notifications (
        UserId, ActorUserId, Title, Content, Type, Priority, 
        GroupKey, DeduplicationKey, EntityType, EntityId, ReferenceId, 
        TargetUrl, IsRead, ReadAt, CreatedAt, UpdatedAt
    )
    VALUES (
        @TargetUserId, @ActorUserId, 
        N'Lượt thích mới cho bài đánh giá', 
        N'Dương Đức Thắng đã thích bài đánh giá của bạn.', 
        3, -- Review
        3,
        'REVIEW_LIKE_10801',
        'LIKE_THANG_206_1',
        'REVIEW', 10801, 10801,
        '/places/653#review-10801',
        0, NULL,
        DATEADD(day, -1, SYSUTCDATETIME()),
        DATEADD(day, -1, SYSUTCDATETIME())
    );

    -- Thông báo 2: Lượt thích bài đánh giá khác (Hôm qua - Chưa đọc)
    INSERT INTO dbo.Notifications (
        UserId, ActorUserId, Title, Content, Type, Priority, 
        GroupKey, DeduplicationKey, EntityType, EntityId, ReferenceId, 
        TargetUrl, IsRead, ReadAt, CreatedAt, UpdatedAt
    )
    VALUES (
        @TargetUserId, @ActorUserId, 
        N'Lượt thích mới cho bài đánh giá', 
        N'Dương Đức Thắng đã thích bài đánh giá của bạn.', 
        3, -- Review
        3,
        'REVIEW_LIKE_10802',
        'LIKE_THANG_206_2',
        'REVIEW', 10802, 10802,
        '/places/652#review-10802',
        0, NULL,
        DATEADD(day, -1, SYSUTCDATETIME()),
        DATEADD(day, -1, SYSUTCDATETIME())
    );

    -- Thông báo 3: Đề xuất địa điểm đã duyệt (3 ngày trước - Đã đọc)
    INSERT INTO dbo.Notifications (
        UserId, ActorUserId, Title, Content, Type, Priority, 
        GroupKey, DeduplicationKey, EntityType, EntityId, ReferenceId, 
        TargetUrl, IsRead, ReadAt, CreatedAt, UpdatedAt
    )
    VALUES (
        @TargetUserId, 1, 
        N'Đề xuất địa điểm đã được duyệt', 
        N'Đề xuất địa điểm mới của bạn đã được ban quản trị kiểm duyệt và xuất bản thành công.', 
        5, -- Proposal
        2,
        'PROPOSAL_APPROVED',
        'PROPOSAL_APPROVED_206',
        'PLACE', 1, 1,
        '/places/1',
        1, DATEADD(day, -2, SYSUTCDATETIME()),
        DATEADD(day, -3, SYSUTCDATETIME()),
        DATEADD(day, -3, SYSUTCDATETIME())
    );

    -- Thông báo 4: Chào mừng hệ thống (5 ngày trước - Đã đọc)
    INSERT INTO dbo.Notifications (
        UserId, ActorUserId, Title, Content, Type, Priority, 
        GroupKey, DeduplicationKey, EntityType, EntityId, ReferenceId, 
        TargetUrl, IsRead, ReadAt, CreatedAt, UpdatedAt
    )
    VALUES (
        @TargetUserId, NULL, 
        N'Chào mừng đến với LangThang', 
        N'Khám phá thế giới du lịch tiện lợi cùng LangThang. Hãy lưu lại những địa điểm và chia sẻ trải nghiệm đầu tiên nhé!', 
        1, -- System
        1,
        'WELCOME',
        'WELCOME_206',
        'SYSTEM', NULL, NULL,
        '/destinations',
        1, DATEADD(day, -4, SYSUTCDATETIME()),
        DATEADD(day, -5, SYSUTCDATETIME()),
        DATEADD(day, -5, SYSUTCDATETIME())
    );

    PRINT N'Đã thêm dữ liệu thông báo thật cho dinhtanthanh19@gmail.com.';
END
ELSE
BEGIN
    PRINT N'Không tìm thấy user dinhtanthanh19@gmail.com';
END
GO
