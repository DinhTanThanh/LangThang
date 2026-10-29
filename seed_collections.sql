SET NOCOUNT ON;

IF NOT EXISTS (SELECT 1 FROM dbo.Collections WHERE Title LIKE N'%Hà Nội%')
BEGIN
    INSERT INTO dbo.Collections (ProvinceId, Title, Description, CoverImageUrl, IsFeatured, DisplayOrder, Status, CreatedAt)
    VALUES 
    (1, N'Khám phá Hà Nội nghìn năm văn hiến', N'Hành trình qua các di sản lịch sử cổ kính và danh thắng tiêu biểu của thủ đô.', N'https://images.unsplash.com/photo-1528127269322-539801943592?w=900&h=600&fit=crop&auto=format', 1, 1, 1, SYSUTCDATETIME());

    DECLARE @Col1 INT = SCOPE_IDENTITY();

    INSERT INTO dbo.CollectionPlaces (CollectionId, PlaceId, DisplayOrder)
    VALUES 
    (@Col1, 1, 1),
    (@Col1, 2, 2),
    (@Col1, 3, 3),
    (@Col1, 4, 4),
    (@Col1, 5, 5);
END

IF NOT EXISTS (SELECT 1 FROM dbo.Collections WHERE Title LIKE N'%Đà Nẵng%')
BEGIN
    INSERT INTO dbo.Collections (ProvinceId, Title, Description, CoverImageUrl, IsFeatured, DisplayOrder, Status, CreatedAt)
    VALUES 
    (17, N'Dạo bước biển xanh & Kỳ quan Đà Nẵng', N'Những điểm đến biểu tượng, bãi biển thơ mộng và danh thắng non nước hữu tình.', N'https://images.unsplash.com/photo-1559592413-7cec4d0cae2b?w=900&h=600&fit=crop&auto=format', 1, 2, 1, SYSUTCDATETIME());

    DECLARE @Col2 INT = SCOPE_IDENTITY();

    INSERT INTO dbo.CollectionPlaces (CollectionId, PlaceId, DisplayOrder)
    VALUES 
    (@Col2, 38, 1),
    (@Col2, 39, 2),
    (@Col2, 40, 3),
    (@Col2, 41, 4),
    (@Col2, 42, 5);
END

IF NOT EXISTS (SELECT 1 FROM dbo.Collections WHERE Title LIKE N'%Sài Gòn%')
BEGIN
    INSERT INTO dbo.Collections (ProvinceId, Title, Description, CoverImageUrl, IsFeatured, DisplayOrder, Status, CreatedAt)
    VALUES 
    (27, N'Sắc màu sôi động & Dấu ấn Sài Gòn', N'Khám phá nhịp sống hiện đại, kiến trúc hoa lệ và văn hóa ẩm thực rực rỡ.', N'https://images.unsplash.com/photo-1583417319070-4a69db38a482?w=900&h=600&fit=crop&auto=format', 1, 3, 1, SYSUTCDATETIME());

    DECLARE @Col3 INT = SCOPE_IDENTITY();

    INSERT INTO dbo.CollectionPlaces (CollectionId, PlaceId, DisplayOrder)
    VALUES 
    (@Col3, 20, 1),
    (@Col3, 21, 2),
    (@Col3, 22, 3),
    (@Col3, 23, 4),
    (@Col3, 24, 5);
END
