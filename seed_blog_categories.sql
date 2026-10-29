-- Seed blog categories into Categories table if not existing
IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE Name = N'Di tích lịch sử - Văn hóa')
    INSERT INTO dbo.Categories (PlaceTypeId, Name, Slug, DisplayOrder, Status) VALUES (3, N'Di tích lịch sử - Văn hóa', 'di-tich-lich-su-van-hoa', 1, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE Name = N'Điểm tham quan du lịch')
    INSERT INTO dbo.Categories (PlaceTypeId, Name, Slug, DisplayOrder, Status) VALUES (3, N'Điểm tham quan du lịch', 'diem-tham-quan-du-lich', 3, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE Name = N'Điểm chụp ảnh & Check-in')
    INSERT INTO dbo.Categories (PlaceTypeId, Name, Slug, DisplayOrder, Status) VALUES (3, N'Điểm chụp ảnh & Check-in', 'diem-chup-anh-check-in', 4, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE Name = N'Ẩm thực & Nhà hàng')
    INSERT INTO dbo.Categories (PlaceTypeId, Name, Slug, DisplayOrder, Status) VALUES (1, N'Ẩm thực & Nhà hàng', 'am-thuc-nha-hang', 5, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE Name = N'Quán cà phê & Giải trí')
    INSERT INTO dbo.Categories (PlaceTypeId, Name, Slug, DisplayOrder, Status) VALUES (1, N'Quán cà phê & Giải trí', 'quan-ca-phe-giai-tri', 6, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE Name = N'Khách sạn & Nghỉ dưỡng')
    INSERT INTO dbo.Categories (PlaceTypeId, Name, Slug, DisplayOrder, Status) VALUES (2, N'Khách sạn & Nghỉ dưỡng', 'khach-san-nghi-duong', 7, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE Name = N'Kinh nghiệm du lịch')
    INSERT INTO dbo.Categories (PlaceTypeId, Name, Slug, DisplayOrder, Status) VALUES (3, N'Kinh nghiệm du lịch', 'kinh-nghiem-du-lich', 8, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE Name = N'Cẩm nang tự túc')
    INSERT INTO dbo.Categories (PlaceTypeId, Name, Slug, DisplayOrder, Status) VALUES (3, N'Cẩm nang tự túc', 'cam-nang-tu-tuc', 9, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE Name = N'Phượt & Khám phá')
    INSERT INTO dbo.Categories (PlaceTypeId, Name, Slug, DisplayOrder, Status) VALUES (3, N'Phượt & Khám phá', 'phuot-kham-pha', 10, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE Name = N'Đặc sản vùng miền')
    INSERT INTO dbo.Categories (PlaceTypeId, Name, Slug, DisplayOrder, Status) VALUES (1, N'Đặc sản vùng miền', 'dac-san-vung-mien', 11, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.Categories WHERE Name = N'Mẹo & Kinh nghiệm')
    INSERT INTO dbo.Categories (PlaceTypeId, Name, Slug, DisplayOrder, Status) VALUES (3, N'Mẹo & Kinh nghiệm', 'meo-kinh-nghiem', 12, 1);
