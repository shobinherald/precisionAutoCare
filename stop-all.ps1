# Precision Auto Care - Microservices Shutdown Script
$ports = @(8761, 8080, 8081, 8082, 8083, 8084)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Stopping Precision Auto Care SOA Microservices Stack    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

foreach ($port in $ports) {
    try {
        $conns = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
        if ($conns) {
            foreach ($conn in $conns) {
                $pidVal = $conn.OwningProcess
                if ($pidVal -and $pidVal -ne 0) {
                    Write-Host "Stopping process PID $pidVal listening on port $port..." -ForegroundColor Yellow
                    Stop-Process -Id $pidVal -Force -ErrorAction SilentlyContinue
                }
            }
        } else {
            Write-Host "No process listening on port $port." -ForegroundColor Gray
        }
    } catch {
        Write-Host "Error stopping process on port ${port}: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`nAll microservices stopped." -ForegroundColor Green
