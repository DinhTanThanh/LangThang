$loginPayload = @{
    email = "test@example.com"
    password = "Password123!"
} | ConvertTo-Json

$loginRes = Invoke-RestMethod -Uri "http://localhost:5000/api/auth/login" -Method Post -Body $loginPayload -ContentType "application/json"
$token = $loginRes.data.accessToken
Write-Host "Token acquired for user: $($loginRes.data.user.fullName)"

# Get report reasons
$reasons = Invoke-RestMethod -Uri "http://localhost:5000/api/reports/reasons?targetType=blog" -Method Get -Headers @{ Authorization = "Bearer $token" }
Write-Host "Available reasons count: $($reasons.data.Count)"
$firstReason = $reasons.data[0]
Write-Host "First Reason: Id=$($firstReason.id), Name=$($firstReason.name), Code=$($firstReason.code)"

# Submit report for blog 10001
$reportPayload = @{
    targetType = "blog"
    targetId = 10001
    reasonId = [int]$firstReason.id
    description = "Test reporting blog 10001 via script"
} | ConvertTo-Json

$res = Invoke-RestMethod -Uri "http://localhost:5000/api/reports" -Method Post -Headers @{ Authorization = "Bearer $token" } -Body $reportPayload -ContentType "application/json"
Write-Host "Report Response: $($res | ConvertTo-Json -Depth 3)"

# Query SQL database dbo.BlogReports
sqlcmd -S localhost -U sa -P "ChangeThisPassword123!" -C -d TravelReviewDB -Q "SELECT TOP 5 * FROM dbo.BlogReports ORDER BY Id DESC;"
