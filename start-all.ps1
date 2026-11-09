# Precision Auto Care - Microservices Startup Script
$ErrorActionPreference = "Continue"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Starting Precision Auto Care SOA Microservices Stack    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$services = @(
    @{ Name = "Eureka Server";   Path = "eureka-server";   Port = 8761; WaitSec = 12 },
    @{ Name = "Auth Service";    Path = "auth-service";    Port = 8081; WaitSec = 6 },
    @{ Name = "Billing Service"; Path = "billing-service"; Port = 8084; WaitSec = 6 },
    @{ Name = "Record Service";  Path = "record-service";  Port = 8083; WaitSec = 6 },
    @{ Name = "Booking Service"; Path = "booking-service"; Port = 8082; WaitSec = 6 },
    @{ Name = "API Gateway";     Path = "api-gateway";     Port = 8080; WaitSec = 8 }
)

$rootDir = $PSScriptRoot
if (-not $rootDir) {
    $rootDir = (Get-Location).Path
}

foreach ($svc in $services) {
    Write-Host "`n[STARTING] $($svc.Name) on port $($svc.Port)..." -ForegroundColor Yellow
    $svcPath = Join-Path $rootDir $svc.Path
    $jarName = "$($svc.Path)-0.0.1-SNAPSHOT.jar"
    $jarPath = Join-Path $svcPath "target\$jarName"

    if (-not (Test-Path $jarPath)) {
        Write-Host "Jar not found at $jarPath. Building service..." -ForegroundColor Gray
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c mvnw.cmd package -DskipTests" -WorkingDirectory $svcPath -NoNewWindow -Wait
    }

    $proc = Start-Process -FilePath "java" -ArgumentList "-jar target\$jarName" -WorkingDirectory $svcPath -PassThru
    Write-Host "Started $($svc.Name) (PID: $($proc.Id)). Waiting $($svc.WaitSec)s..." -ForegroundColor Green
    Start-Sleep -Seconds $svc.WaitSec
}

Write-Host "`nAll microservices launched." -ForegroundColor Cyan
Write-Host "API Gateway:       http://localhost:8080" -ForegroundColor Cyan
Write-Host "Eureka Dashboard:  http://localhost:8761" -ForegroundColor Cyan
