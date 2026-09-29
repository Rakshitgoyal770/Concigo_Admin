$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFtZ3Jrb2d4cWZxYWltdGNmdnNwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4ODM0MTgsImV4cCI6MjA4ODQ1OTQxOH0.xXiwmR1EMrPwdLJJszJhIwWt-Rza-RKg2zBUtzoATLc"
$headers = @{
    "apikey" = $anonKey
    "Authorization" = "Bearer $anonKey"
}

$propId = "b0000001-0000-0000-0000-000000000001"

Write-Host "Employees for Grand Hotel Berlin ($propId):"
$emps = Invoke-RestMethod -Uri "https://qmgrkogxqfqaimtcfvsp.supabase.co/rest/v1/property_employees?property_id=eq.$propId&select=emp_id,emp_f_name,emp_l_name,role,phone_no,is_active,service_dept" -Headers $headers
$emps | Format-Table
