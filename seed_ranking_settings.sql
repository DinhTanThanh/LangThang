IF NOT EXISTS (SELECT 1 FROM dbo.SystemSettings WHERE SettingKey = 'RANKING_TITLE')
BEGIN
    INSERT INTO dbo.SystemSettings (SettingKey, SettingValue, Description, SettingGroup, UpdatedAt)
    VALUES ('RANKING_TITLE', N'Bảng Xếp Hạng Du Lịch Xuất Sắc Nhất 2026', N'Tiêu đề chính của trang Bảng Xếp Hạng', 'RANKING', GETDATE());
END
ELSE
BEGIN
    UPDATE dbo.SystemSettings SET SettingValue = N'Bảng Xếp Hạng Du Lịch Xuất Sắc Nhất 2026', UpdatedAt = GETDATE() WHERE SettingKey = 'RANKING_TITLE';
END

IF NOT EXISTS (SELECT 1 FROM dbo.SystemSettings WHERE SettingKey = 'RANKING_SUBTITLE')
BEGIN
    INSERT INTO dbo.SystemSettings (SettingKey, SettingValue, Description, SettingGroup, UpdatedAt)
    VALUES ('RANKING_SUBTITLE', N'Hàng năm, chúng tôi tôn vinh những điểm đến, khách sạn, nhà hàng và hoạt động du lịch yêu thích nhất của du khách dựa trên các đánh giá thực tế được thu thập qua 12 tháng. Vì vậy, những người chiến thắng Giải thưởng Bảng Xếp Hạng Xuất Sắc Nhất được quyết định bởi chính bạn: những du khách thực thụ từ khắp mọi nơi, chia sẻ những trải nghiệm và câu chuyện chân thực nhất.', N'Mô tả trang Bảng Xếp Hạng', 'RANKING', GETDATE());
END
ELSE
BEGIN
    UPDATE dbo.SystemSettings SET SettingValue = N'Hàng năm, chúng tôi tôn vinh những điểm đến, khách sạn, nhà hàng và hoạt động du lịch yêu thích nhất của du khách dựa trên các đánh giá thực tế được thu thập qua 12 tháng. Vì vậy, những người chiến thắng Giải thưởng Bảng Xếp Hạng Xuất Sắc Nhất được quyết định bởi chính bạn: những du khách thực thụ từ khắp mọi nơi, chia sẻ những trải nghiệm và câu chuyện chân thực nhất.', UpdatedAt = GETDATE() WHERE SettingKey = 'RANKING_SUBTITLE';
END

IF NOT EXISTS (SELECT 1 FROM dbo.SystemSettings WHERE SettingKey = 'RANKING_BADGE')
BEGIN
    INSERT INTO dbo.SystemSettings (SettingKey, SettingValue, Description, SettingGroup, UpdatedAt)
    VALUES ('RANKING_BADGE', N'Bình chọn 2026', N'Huy hiệu giải thưởng', 'RANKING', GETDATE());
END

IF NOT EXISTS (SELECT 1 FROM dbo.SystemSettings WHERE SettingKey = 'RANKING_PLACES_TITLE')
BEGIN
    INSERT INTO dbo.SystemSettings (SettingKey, SettingValue, Description, SettingGroup, UpdatedAt)
    VALUES ('RANKING_PLACES_TITLE', N'Địa điểm toàn quốc', N'Tiêu đề tiếng Anh/gốc', 'RANKING', GETDATE());
END
ELSE
BEGIN
    UPDATE dbo.SystemSettings SET SettingValue = N'Địa điểm toàn quốc', UpdatedAt = GETDATE() WHERE SettingKey = 'RANKING_PLACES_TITLE';
END

IF NOT EXISTS (SELECT 1 FROM dbo.SystemSettings WHERE SettingKey = 'RANKING_PLACES_VN_TITLE')
BEGIN
    INSERT INTO dbo.SystemSettings (SettingKey, SettingValue, Description, SettingGroup, UpdatedAt)
    VALUES ('RANKING_PLACES_VN_TITLE', N'Địa điểm toàn quốc', N'Tiêu đề tiếng Việt', 'RANKING', GETDATE());
END
ELSE
BEGIN
    UPDATE dbo.SystemSettings SET SettingValue = N'Địa điểm toàn quốc', UpdatedAt = GETDATE() WHERE SettingKey = 'RANKING_PLACES_VN_TITLE';
END

IF NOT EXISTS (SELECT 1 FROM dbo.SystemSettings WHERE SettingKey = 'RANKING_PLACES_TAGLINE')
BEGIN
    INSERT INTO dbo.SystemSettings (SettingKey, SettingValue, Description, SettingGroup, UpdatedAt)
    VALUES ('RANKING_PLACES_TAGLINE', N'Khám phá các tọa độ du lịch, ẩm thực và trải nghiệm được cộng đồng bình chọn xuất sắc nhất Việt Nam', N'Khẩu hiệu địa điểm', 'RANKING', GETDATE());
END
ELSE
BEGIN
    UPDATE dbo.SystemSettings SET SettingValue = N'Khám phá các tọa độ du lịch, ẩm thực và trải nghiệm được cộng đồng bình chọn xuất sắc nhất Việt Nam', UpdatedAt = GETDATE() WHERE SettingKey = 'RANKING_PLACES_TAGLINE';
END

IF NOT EXISTS (SELECT 1 FROM dbo.SystemSettings WHERE SettingKey = 'RANKING_PLACES_COVER')
BEGIN
    INSERT INTO dbo.SystemSettings (SettingKey, SettingValue, Description, SettingGroup, UpdatedAt)
    VALUES ('RANKING_PLACES_COVER', 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?q=80&w=1920&auto=format&fit=crop', N'Ảnh bìa danh mục Địa điểm toàn quốc', 'RANKING', GETDATE());
END
ELSE
BEGIN
    UPDATE dbo.SystemSettings SET SettingValue = 'https://images.unsplash.com/photo-1506744038136-46273834b3fb?q=80&w=1920&auto=format&fit=crop', UpdatedAt = GETDATE() WHERE SettingKey = 'RANKING_PLACES_COVER';
END

IF NOT EXISTS (SELECT 1 FROM dbo.SystemSettings WHERE SettingKey = 'RANKING_DESTINATIONS_TITLE')
BEGIN
    INSERT INTO dbo.SystemSettings (SettingKey, SettingValue, Description, SettingGroup, UpdatedAt)
    VALUES ('RANKING_DESTINATIONS_TITLE', N'Tỉnh thành', N'Tiêu đề Tỉnh thành', 'RANKING', GETDATE());
END
ELSE
BEGIN
    UPDATE dbo.SystemSettings SET SettingValue = N'Tỉnh thành', UpdatedAt = GETDATE() WHERE SettingKey = 'RANKING_DESTINATIONS_TITLE';
END

IF NOT EXISTS (SELECT 1 FROM dbo.SystemSettings WHERE SettingKey = 'RANKING_DESTINATIONS_VN_TITLE')
BEGIN
    INSERT INTO dbo.SystemSettings (SettingKey, SettingValue, Description, SettingGroup, UpdatedAt)
    VALUES ('RANKING_DESTINATIONS_VN_TITLE', N'Tỉnh thành', N'Tiêu đề tiếng Việt Tỉnh thành', 'RANKING', GETDATE());
END
ELSE
BEGIN
    UPDATE dbo.SystemSettings SET SettingValue = N'Tỉnh thành', UpdatedAt = GETDATE() WHERE SettingKey = 'RANKING_DESTINATIONS_VN_TITLE';
END

IF NOT EXISTS (SELECT 1 FROM dbo.SystemSettings WHERE SettingKey = 'RANKING_DESTINATIONS_TAGLINE')
BEGIN
    INSERT INTO dbo.SystemSettings (SettingKey, SettingValue, Description, SettingGroup, UpdatedAt)
    VALUES ('RANKING_DESTINATIONS_TAGLINE', N'Khám phá các điểm đến, tỉnh thành du lịch xuất sắc nhất trên dải đất hình chữ S', N'Khẩu hiệu Tỉnh thành', 'RANKING', GETDATE());
END
ELSE
BEGIN
    UPDATE dbo.SystemSettings SET SettingValue = N'Khám phá các điểm đến, tỉnh thành du lịch xuất sắc nhất trên dải đất hình chữ S', UpdatedAt = GETDATE() WHERE SettingKey = 'RANKING_DESTINATIONS_TAGLINE';
END

IF NOT EXISTS (SELECT 1 FROM dbo.SystemSettings WHERE SettingKey = 'RANKING_DESTINATIONS_COVER')
BEGIN
    INSERT INTO dbo.SystemSettings (SettingKey, SettingValue, Description, SettingGroup, UpdatedAt)
    VALUES ('RANKING_DESTINATIONS_COVER', 'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=1920&auto=format&fit=crop', N'Ảnh bìa danh mục Tỉnh thành', 'RANKING', GETDATE());
END
ELSE
BEGIN
    UPDATE dbo.SystemSettings SET SettingValue = 'https://images.unsplash.com/photo-1528127269322-539801943592?q=80&w=1920&auto=format&fit=crop', UpdatedAt = GETDATE() WHERE SettingKey = 'RANKING_DESTINATIONS_COVER';
END
