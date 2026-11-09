# Precision Auto Care - End-to-End Architectural Integration Test
$ErrorActionPreference = "Stop"

$gatewayUrl = "http://localhost:8080"
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Running End-to-End SOA Integration & Security Verification" -ForegroundColor Cyan
Write-Host " Gateway URL: $gatewayUrl" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

function Assert-Step($title, [scriptblock]$action) {
    Write-Host "`n[TEST] $title" -ForegroundColor Yellow
    try {
        & $action
        Write-Host "  -> PASSED" -ForegroundColor Green
    } catch {
        Write-Host "  -> FAILED: $($_.Exception.Message)" -ForegroundColor Red
        throw $_
    }
}

# 1. Security Check: Unauthenticated request should be rejected by Gateway with 401
Assert-Step "1. Security: Access /api/bookings without Authorization header (Expect 401)" {
    try {
        Invoke-RestMethod -Uri "$gatewayUrl/api/bookings" -Method GET -ErrorAction Stop
        throw "Expected 401 Unauthorized but request succeeded!"
    } catch {
        $status = $_.Exception.Response.StatusCode.value__
        if ($status -eq 401) {
            Write-Host "     Received HTTP 401 Unauthorized as expected." -ForegroundColor Gray
        } else {
            throw "Expected status 401, but got $status"
        }
    }
}

# 2. Security Check: Request with invalid/expired token should be rejected with 401
Assert-Step "2. Security: Access /api/bookings with invalid token (Expect 401)" {
    try {
        Invoke-RestMethod -Uri "$gatewayUrl/api/bookings" -Method GET -Headers @{ Authorization = "Bearer invalid.fake.token" } -ErrorAction Stop
        throw "Expected 401 Unauthorized but request succeeded!"
    } catch {
        $status = $_.Exception.Response.StatusCode.value__
        if ($status -eq 401) {
            Write-Host "     Received HTTP 401 Unauthorized as expected." -ForegroundColor Gray
        } else {
            throw "Expected status 401, but got $status"
        }
    }
}

# 3. User Registration
$username = "pilot_user_" + (Get-Random -Minimum 1000 -Maximum 9999)
Assert-Step "3. Register New User: $username" {
    $registerBody = @{
        username = $username
        password = "Password@123"
        role = "CUSTOMER"
    } | ConvertTo-Json

    $regResponse = Invoke-RestMethod -Uri "$gatewayUrl/api/auth/register" -Method POST -Body $registerBody -ContentType "application/json"
    Write-Host "     Response: $($regResponse | ConvertTo-Json -Compress)" -ForegroundColor Gray
}

# 4. User Login & Token Acquisition
$script:jwtToken = ""
Assert-Step "4. Authenticate User and Acquire JWT Token" {
    $loginBody = @{
        username = $username
        password = "Password@123"
    } | ConvertTo-Json

    $loginResponse = Invoke-RestMethod -Uri "$gatewayUrl/api/auth/login" -Method POST -Body $loginBody -ContentType "application/json"
    $script:jwtToken = $loginResponse.token
    if (-not $script:jwtToken) {
        throw "Login succeeded but token was empty!"
    }
    Write-Host "     JWT Token successfully acquired (User: $($loginResponse.username), Role: $($loginResponse.role))" -ForegroundColor Gray
}

# 5. Token Validation Endpoint Check
Assert-Step "5. Verify Token Validation via /api/auth/validate" {
    $validateResponse = Invoke-RestMethod -Uri "$gatewayUrl/api/auth/validate?token=$script:jwtToken" -Method GET
    if (-not $validateResponse.valid) {
        throw "Token validation reported token as invalid!"
    }
    Write-Host "     Token is valid for user: $($validateResponse.username)" -ForegroundColor Gray
}

# 6. End-to-End Orchestrated Booking Workflow:
# Booking Service -> Record Service -> Billing Service
$script:bookingId = $null
Assert-Step "6. Create Booking (Orchestrates Booking -> Record -> Billing)" {
    $authHeaders = @{
        Authorization = "Bearer $script:jwtToken"
    }

    $bookingBody = @{
        userId = 101
        vehicleId = 502
        serviceDate = (Get-Date).ToString("yyyy-MM-dd")
        serviceType = "Full Transmission Diagnostic & Service"
    } | ConvertTo-Json

    $bookingResponse = Invoke-RestMethod -Uri "$gatewayUrl/api/bookings" -Method POST -Body $bookingBody -ContentType "application/json" -Headers $authHeaders
    $script:bookingId = $bookingResponse.id
    if (-not $script:bookingId) {
        throw "Booking creation did not return an id!"
    }

    Write-Host "     Created Booking ID: $($bookingResponse.id), Status: $($bookingResponse.status)" -ForegroundColor Gray
    if ($bookingResponse.status -ne "CONFIRMED") {
        throw "Expected booking status 'CONFIRMED', got '$($bookingResponse.status)'"
    }
}

# 7. Verify Service Record was automatically created via inter-service Feign call
Assert-Step "7. Verify Downstream Record Service Creation" {
    $authHeaders = @{
        Authorization = "Bearer $script:jwtToken"
    }

    $records = Invoke-RestMethod -Uri "$gatewayUrl/api/records" -Method GET -Headers $authHeaders
    $matchingRecord = $records | Where-Object { $_.bookingId -eq $script:bookingId }
    if (-not $matchingRecord) {
        throw "Record Service does not contain a record for bookingId $script:bookingId"
    }
    Write-Host "     Verified ServiceRecord ID: $($matchingRecord.id), BookingId: $($matchingRecord.bookingId), Tech: $($matchingRecord.technicianName)" -ForegroundColor Gray
}

# 8. Verify Invoice was automatically generated via inter-service Feign call
Assert-Step "8. Verify Downstream Billing Service Creation" {
    $authHeaders = @{
        Authorization = "Bearer $script:jwtToken"
    }

    $invoices = Invoke-RestMethod -Uri "$gatewayUrl/api/billing" -Method GET -Headers $authHeaders
    $matchingInvoice = $invoices | Where-Object { $_.bookingId -eq $script:bookingId }
    if (-not $matchingInvoice) {
        throw "Billing Service does not contain an invoice for bookingId $script:bookingId"
    }
    Write-Host "     Verified Invoice ID: $($matchingInvoice.id), Amount: `$$($matchingInvoice.amount), Status: $($matchingInvoice.status)" -ForegroundColor Gray
}

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host " ALL END-TO-END SOA INTEGRATION TESTS PASSED SUCCESSFULLY! " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
