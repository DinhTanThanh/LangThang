$bodyAdmin = '{"email":"admin@langthang.vn","password":"123456"}'
try {
    $res = Invoke-RestMethod -Uri 'http://localhost:5000/api/auth/login' -Method Post -Body $bodyAdmin -ContentType 'application/json'
    Write-Host "ADMIN LOGIN SUCCESS: User=$($res.data.user.email), FullName=$($res.data.user.fullName), TokenLen=$($res.data.accessToken.Length)"
} catch {
    Write-Host "ADMIN LOGIN ERROR:" $_.Exception.Message
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        Write-Host "DETAIL:" $reader.ReadToEnd()
    }
}

$bodyDemo = '{"email":"demo@langthang.vn","password":"123456"}'
try {
    $res2 = Invoke-RestMethod -Uri 'http://localhost:5000/api/auth/login' -Method Post -Body $bodyDemo -ContentType 'application/json'
    Write-Host "DEMO LOGIN SUCCESS: User=$($res2.data.user.email), FullName=$($res2.data.user.fullName)"
} catch {
    Write-Host "DEMO LOGIN ERROR:" $_.Exception.Message
}

$bodyGoogle = '{"idToken":"google_test_123","email":"test_google@gmail.com","fullName":"Google Tester","googleId":"g_123456"}'
try {
    $res3 = Invoke-RestMethod -Uri 'http://localhost:5000/api/auth/google' -Method Post -Body $bodyGoogle -ContentType 'application/json'
    Write-Host "GOOGLE LOGIN SUCCESS: User=$($res3.data.user.email), FullName=$($res3.data.user.fullName)"
} catch {
    Write-Host "GOOGLE LOGIN ERROR:" $_.Exception.Message
}
