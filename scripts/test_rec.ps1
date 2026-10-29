$loginPayload = @{
    email = "test@example.com"
    password = "Password123!"
} | ConvertTo-Json

$loginRes = Invoke-RestMethod -Uri "http://localhost:5000/api/auth/login" -Method Post -Body $loginPayload -ContentType "application/json"
$token = $loginRes.data.accessToken
Write-Host "User: $($loginRes.data.user.fullName), ID: $($loginRes.data.user.id)"

$recRes = Invoke-RestMethod -Uri "http://localhost:5000/api/recommendations/places/for-you?topK=4" -Method Get -Headers @{ Authorization = "Bearer $token" }
Write-Host "isPersonalized: $($recRes.data.isPersonalized)"
$recRes.data.items | ForEach-Object {
    Write-Host "- $($_.name) ($($_.avgRating) star, $($_.reviewCount) reviews, isColdStart: $($_.isColdStartFallback))"
}
