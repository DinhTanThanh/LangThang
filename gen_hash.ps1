$dll = (Get-ChildItem -Path "d:\LangThang\Share_Locations\Backend" -Filter "BCrypt.Net-Next.dll" -Recurse | Select-Object -First 1).FullName
Write-Host "Found DLL: $dll"
[System.Reflection.Assembly]::LoadFrom($dll) | Out-Null
$hLang = [BCrypt.Net.BCrypt]::HashPassword("LangThang@2026", 11)
$h123 = [BCrypt.Net.BCrypt]::HashPassword("123456", 11)
Write-Host "HASH_LANGTHANG: $hLang"
Write-Host "HASH_123456: $h123"
