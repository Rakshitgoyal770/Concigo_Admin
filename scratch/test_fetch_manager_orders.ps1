$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc"
$headers = @{
    "apikey" = $anonKey
    "Authorization" = "Bearer $anonKey"
}

$propId = "b0000001-0000-0000-0000-000000000001"

Write-Host "1. Rooms for property:"
$rooms = Invoke-RestMethod -Uri "https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1/rooms?property_id=eq.$propId&select=room_id" -Headers $headers
Write-Host "Rooms count: $($rooms.Count)"
$roomIds = $rooms | ForEach-Object { $_.room_id }

Write-Host "2. Stays for property:"
$stays = Invoke-RestMethod -Uri "https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1/stay?hotel_id=eq.$propId&select=stay_id" -Headers $headers
Write-Host "Stays count: $($stays.Count)"
$stayIds = $stays | ForEach-Object { $_.stay_id }

Write-Host "3. Open service orders with anon key:"
try {
    $orders = Invoke-RestMethod -Uri "https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1/service_orders?select=so_id,serv_id,stay_id,room_id,delivery_location,so_total,status,created_at,updated_at,order_type,user_phone_no,services(name),service_order_items(soi_id,item_name,qty,item_sp,cost)&status=in.(ordered,in_progress)&order=created_at.desc" -Headers $headers
    Write-Host "Open orders returned: $($orders.Count)"
    foreach ($o in $orders) {
        $sid = $o.stay_id
        $rid = $o.room_id
        $inStays = $stayIds -contains $sid
        $inRooms = $roomIds -contains $rid
        Write-Host "Order $($o.so_id) status=$($o.status) stay_id=$sid (inStays=$inStays) room_id=$rid (inRooms=$inRooms) items=$($o.service_order_items.Count)"
    }
} catch {
    $ex = $_.Exception
    if ($ex.Response) {
        $reader = New-Object System.IO.StreamReader($ex.Response.GetResponseStream())
        Write-Host "Error: $($reader.ReadToEnd())"
    } else {
        Write-Host "Error: $($ex.Message)"
    }
}
