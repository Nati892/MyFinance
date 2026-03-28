# Build and deploy the full stack.
# Run from C:\Repos\Household\

Write-Host "Step 1: Building Angular app on host..." -ForegroundColor Cyan
Set-Location front_end
npx ng build --configuration production
if ($LASTEXITCODE -ne 0) { Write-Error "Angular build failed"; exit 1 }
Set-Location ..

Write-Host "Step 2: Starting Docker containers..." -ForegroundColor Cyan
docker-compose up --build @args
