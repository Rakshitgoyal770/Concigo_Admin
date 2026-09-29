$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc"
$headers = @{
    "apikey" = $anonKey
    "Authorization" = "Bearer $anonKey"
    "Content-Type" = "application/json"
}

function Get-ErrorDetails($ex) {
    if ($ex.Response) {
        $reader = New-Object System.IO.StreamReader($ex.Response.GetResponseStream())
        return $reader.ReadToEnd()
    }
    return $ex.Message
}

Write-Host "=== TEST INSERT INTO service_orders ==="
$body = @{
    "serv_id" = "b0000001-0000-0000-0000-000000000001"
    "stay_id" = "30933b41-41ca-45d9-bbdf-7cc152c0952d"
    "user_id" = "ccfd3e2f-1d78-4c64-8198-024654e74fa0"
    "status" = "ordered"
    "order_type" = "silver"
    "so_total" = 100.0
} | ConvertTo-Json

try {
    $res = Invoke-RestMethod -Uri "https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1/service_orders" -Method Post -Headers $headers -Body $body
    Write-Host "Insert success! Result: $($res | ConvertTo-Json)"
    $afterOrders = Invoke-RestMethod -Uri "https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1/service_orders?select=*" -Headers $headers
    Write-Host "After insert, service_orders count: $($afterOrders.Count)"
} catch {
    Write-Host "Insert error: $(Get-ErrorDetails $_.Exception)"
}


Write-Host "=== CHECK STAYS FOR RAKSHIT ==="
$uids = @('ccfd3e2f-1d78-4c64-8198-024654e74fa0', '7d574dc7-bba7-4ff3-b216-eca994e348c4')
foreach ($uid in $uids) {
    $stays = Invoke-RestMethod -Uri "https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1/stay?user_id=eq.$uid" -Headers $headers
    Write-Host "Stays count for $uid : $($stays.Count)"
    foreach ($s in $stays) {
        Write-Host "  stay_id=$($s.stay_id) hotel_id=$($s.hotel_id) status=$($s.status) check_in=$($s.check_in) check_out=$($s.check_out)"
    }
}
