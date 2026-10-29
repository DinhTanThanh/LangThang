-- =========================================================================
-- Script SQL: Thêm/cập nhật dữ liệu cấu hình hệ thống vào bảng [SystemSettings]
-- Bao gồm: DEFAULT_USER_AVATAR, DEFAULT_GROUP_AVATAR, HOME_HERO_IMAGE
-- =========================================================================

MERGE dbo.SystemSettings AS target
USING (VALUES 
    (
        'DEFAULT_USER_AVATAR', 
        'https://imageshare13.blob.core.windows.net/avatar/11d7a376c4374c87a8bffbe8ed54587b.png', 
        N'Ảnh đại diện mặc định người dùng', 
        'MEDIA'
    ),
    (
        'DEFAULT_GROUP_AVATAR', 
        'https://cdn.pixabay.com/photo/2016/11/14/17/39/group-1824145_1280.png', 
        N'Ảnh đại diện mặc định nhóm trò chuyện', 
        'MEDIA'
    ),
    (
        'HOME_HERO_IMAGE', 
        'https://images.unsplash.com/photo-1506744038136-46273834b3fb?q=80&w=1920&auto=format&fit=crop', 
        N'Ảnh nền màn hình chính (Hero Banner)', 
        'MEDIA'
    )
) AS source (SettingKey, SettingValue, Description, SettingGroup)
ON target.SettingKey = source.SettingKey
WHEN MATCHED THEN
    UPDATE SET 
        target.SettingValue = source.SettingValue,
        target.Description = source.Description,
        target.SettingGroup = source.SettingGroup,
        target.UpdatedAt = SYSUTCDATETIME()
WHEN NOT MATCHED THEN
    INSERT (SettingKey, SettingValue, Description, SettingGroup, UpdatedAt)
    VALUES (source.SettingKey, source.SettingValue, source.Description, source.SettingGroup, SYSUTCDATETIME());

PRINT N'Đã cập nhật thành công 3 cấu hình MEDIA vào bảng SystemSettings.';
GO
