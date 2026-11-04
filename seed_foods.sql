-- Script tạo dữ liệu đặc sản ẩm thực cho LangThang / TravelReviewDB
IF NOT EXISTS (SELECT * FROM sys.columns WHERE object_id = OBJECT_ID(N'dbo.Foods') AND name = 'Slug')
BEGIN
    ALTER TABLE dbo.Foods ADD Slug NVARCHAR(255) NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Foods WHERE Name = N'Chả Cá Lã Vọng')
BEGIN
    INSERT INTO dbo.Foods (Name, Description, HistoryInfo, CoverImageUrl, MinPrice, MaxPrice, Status, CreatedAt, Slug)
    VALUES 
    (N'Chả Cá Lã Vọng', N'Hương vị ẩm thực truyền thống địa phương nổi tiếng với công thức chế biến độc đáo.', N'Món ăn gia truyền hơn 130 năm của người Hà Nội', 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600&auto=format&fit=crop', 120000, 250000, 1, GETUTCDATE(), 'cha-ca-la-vong'),
    (N'Cà Phê Trứng Hà Nội', N'Hương vị ẩm thực truyền thống địa phương nổi tiếng với công thức chế biến độc đáo.', N'Món đồ uống trứ danh khởi nguồn từ quán Cà phê Giảng', 'https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=600&auto=format&fit=crop', 35000, 60000, 1, GETUTCDATE(), 'ca-phe-trung-ha-noi'),
    (N'Bánh Đa Cua Hải Phòng', N'Hương vị ẩm thực truyền thống địa phương nổi tiếng với công thức chế biến độc đáo.', N'Món ăn mang đậm nét văn hóa đất Cảng với bánh đa đỏ và riêu cua đồng', 'https://images.unsplash.com/photo-1569718212165-3a8278d5f624?w=600&auto=format&fit=crop', 40000, 65000, 1, GETUTCDATE(), 'banh-da-cua-hai-phong'),
    (N'Bánh Mì Cay Hải Phòng', N'Hương vị ẩm thực truyền thống địa phương nổi tiếng với công thức chế biến độc đáo.', N'Bánh mì que giòn rụm kẹp pa-tê béo ngậy kèm tương ớt chí chương', 'https://images.unsplash.com/photo-1626082927389-6cd097cdc6ec?w=600&auto=format&fit=crop', 15000, 35000, 1, GETUTCDATE(), 'banh-mi-cay-hai-phong'),
    (N'Phở Bò Gia Truyền', N'Hương vị ẩm thực truyền thống địa phương nổi tiếng với công thức chế biến độc đáo.', N'Món quốc hồn quốc túy của Việt Nam', 'https://images.unsplash.com/photo-1582878826629-29b7ad1cdc43?w=600&auto=format&fit=crop', 50000, 90000, 1, GETUTCDATE(), 'pho-bo-gia-truyen'),
    (N'Bún Chả Hà Nội', N'Hương vị ẩm thực truyền thống địa phương nổi tiếng với công thức chế biến độc đáo.', N'Thịt nướng than hoa thơm lừng cùng nước chấm chua ngọt', 'https://images.unsplash.com/photo-1574484284002-952d92456975?w=600&auto=format&fit=crop', 45000, 70000, 1, GETUTCDATE(), 'bun-cha-ha-noi');
END
GO
