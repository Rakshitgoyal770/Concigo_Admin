$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc"
$headers = @{
    "apikey" = $anonKey
    "Authorization" = "Bearer $anonKey"
}

$propId = "b0000001-0000-0000-0000-000000000001"

$rooms = Invoke-RestMethod -Uri "https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1/rooms?property_id=eq.$propId&select=room_id,room_number" -Headers $headers
$roomMap = @{}
$rooms | ForEach-Object { $roomMap[$_.room_id] = $_.room_number }

$stays = Invoke-RestMethod -Uri "https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1/stay?hotel_id=eq.$propId&select=stay_id,status" -Headers $headers
$stayMap = @{}
$stays | ForEach-Object { $stayMap[$_.stay_id] = $_.status }

$orders = Invoke-RestMethod -Uri "https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1/service_orders?select=so_id,serv_id,stay_id,room_id,delivery_location,so_total,status,created_at,updated_at,order_type,user_phone_no,services(name),service_order_items(soi_id,item_name,qty,item_sp,cost)&status=in.(ordered,in_progress)&order=created_at.desc" -Headers $headers

Write-Host "Total open orders in DB: $($orders.Count)"

$propertyOrders = $orders | Where-Object {
    $rid = $_.room_id
    $sid = $_.stay_id
    ($rid -ne $null -and $roomMap.ContainsKey($rid)) -or ($sid -ne $null -and $stayMap.ContainsKey($sid))
}

Write-Host "Orders for Grand Hotel Berlin: $($propertyOrders.Count)"
foreach ($o in $propertyOrders) {
    $stayStatus = if ($o.stay_id) { $stayMap[$o.stay_id] } else { "N/A" }
    $roomNum = if ($o.room_id) { $roomMap[$o.room_id] } else { "N/A" }
    Write-Host "  -> Order $($o.so_id): status=$($o.status), stay_status=$stayStatus, room=$roomNum, items=$($o.service_order_items.Count), serv=$($o.services.name)"
}
