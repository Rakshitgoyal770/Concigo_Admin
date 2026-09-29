$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc"
$headers = @{
    "apikey" = $anonKey
    "Authorization" = "Bearer $anonKey"
}

function Get-ErrorDetails($ex) {
    if ($ex.Response) {
        $reader = New-Object System.IO.StreamReader($ex.Response.GetResponseStream())
        return $reader.ReadToEnd()
    }
    return $ex.Message
}

Write-Host "=== TEST SERVICE ORDERS WITH ANON KEY ==="
try {
    $orders = Invoke-RestMethod -Uri "https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1/service_orders?select=so_id,status,stay_id,created_at&order=created_at.desc&limit=5" -Headers $headers
    Write-Host "Orders count with anon key: $($orders.Count)"
    $orders | Format-Table
} catch {
    Write-Host "Error: $(Get-ErrorDetails $_.Exception)"
}



Write-Host "=== SERVICE ORDER ITEMS ==="
try {
    $items = Invoke-RestMethod -Uri "https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1/service_order_items?select=*&limit=5" -Headers $headers
    Write-Host "Items Count: $($items.Count)"
} catch {
    Write-Host "Error: $(Get-ErrorDetails $_.Exception)"
}

Write-Host "=== SPA ORDERS ==="
try {
    $spa = Invoke-RestMethod -Uri "https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1/spa_orders?select=*&limit=5" -Headers $headers
    Write-Host "Spa Count: $($spa.Count)"
} catch {
    Write-Host "Error: $(Get-ErrorDetails $_.Exception)"
}

Write-Host "=== LAUNDRY REQUESTS ==="
try {
    $laundry = Invoke-RestMethod -Uri "https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1/laundry_requests?select=*&limit=5" -Headers $headers
    Write-Host "Laundry Count: $($laundry.Count)"
} catch {
    Write-Host "Error: $(Get-ErrorDetails $_.Exception)"
}

Write-Host "=== ACTIVE STAY 30933b41-41ca-45d9-bbdf-7cc152c0952d DETAILS ==="
try {
    $activeStay = Invoke-RestMethod -Uri "https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1/stay?stay_id=eq.30933b41-41ca-45d9-bbdf-7cc152c0952d" -Headers $headers
    $activeStay | Format-List
    $user = Invoke-RestMethod -Uri "https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1/users?user_id=eq.$($activeStay.main_user_id)" -Headers $headers
    Write-Host "User for active stay:"
    $user | Format-List
} catch {
    Write-Host "Error: $(Get-ErrorDetails $_.Exception)"
}



