SET NOCOUNT ON;

-- 1. admin@langthang.vn
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = 'admin@langthang.vn')
BEGIN
    INSERT INTO dbo.Users (Email, PasswordHash, Status, CreatedAt, UpdatedAt, IsDeleted)
    VALUES ('admin@langthang.vn', '123456', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), 0);

    DECLARE @AdminId BIGINT = SCOPE_IDENTITY();

    INSERT INTO dbo.UserProfiles (UserId, FullName, AvatarUrl, Bio, ReputationScore, RankLevel, UpdatedAt)
    VALUES (@AdminId, N'Quản Trị Viên', 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=300', N'Ban quản trị hệ thống du lịch LangThang.', 100, N'Admin', SYSUTCDATETIME());

    INSERT INTO dbo.UserRoles (UserId, RoleId, AssignedBy, AssignedAt)
    VALUES (@AdminId, 3, 1, SYSUTCDATETIME());
END
ELSE
BEGIN
    UPDATE dbo.Users 
    SET PasswordHash = '123456',
        Status = 1,
        IsDeleted = 0
    WHERE Email = 'admin@langthang.vn';
END

-- 2. demo@langthang.vn
IF NOT EXISTS (SELECT 1 FROM dbo.Users WHERE Email = 'demo@langthang.vn')
BEGIN
    INSERT INTO dbo.Users (Email, PasswordHash, Status, CreatedAt, UpdatedAt, IsDeleted)
    VALUES ('demo@langthang.vn', '123456', 1, SYSUTCDATETIME(), SYSUTCDATETIME(), 0);

    DECLARE @DemoId BIGINT = SCOPE_IDENTITY();

    INSERT INTO dbo.UserProfiles (UserId, FullName, AvatarUrl, Bio, ReputationScore, RankLevel, UpdatedAt)
    VALUES (@DemoId, N'Thổ Địa Lang Thang', 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=300', N'Đam mê khám phá các vùng đất mới.', 50, N'Thổ địa', SYSUTCDATETIME());

    INSERT INTO dbo.UserRoles (UserId, RoleId, AssignedBy, AssignedAt)
    VALUES (@DemoId, 1, 1, SYSUTCDATETIME());
END
ELSE
BEGIN
    UPDATE dbo.Users 
    SET PasswordHash = '123456',
        Status = 1,
        IsDeleted = 0
    WHERE Email = 'demo@langthang.vn';
END
