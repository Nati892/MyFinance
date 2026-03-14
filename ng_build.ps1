# Build and Deploy Script
Write-Host "starting deployment" -ForegroundColor Cyan

# Step 1: Navigate to front_end directory and build
Write-Host "Building Angular project..." -ForegroundColor Yellow

# Save current location
$originalLocation = Get-Location

# Navigate to front_end directory
Set-Location -Path ".\front_end"

# Build the project
ng build

if ($LASTEXITCODE -ne 0) {
    Write-Host "Build failed! The dark side has interfered." -ForegroundColor Red
    Set-Location -Path $originalLocation
    exit 1
}

Write-Host "Build successful!" -ForegroundColor Green

# Step 2: Go back to base directory
Set-Location -Path $originalLocation

# Step 3: Remove old dist folder
Write-Host "Removing old distribution..." -ForegroundColor Yellow

$publicFront = ".\public\front"

if (Test-Path $publicFront) {
    Remove-Item -Path $publicFront -Recurse -Force
    Write-Host "Old dist removed!" -ForegroundColor Green
} else {
    Write-Host "No old dist to remove, proceeding..." -ForegroundColor Cyan
}

# Step 4: Create public directory if it doesn't exist
$publicDir = ".\public"
if (-not (Test-Path $publicDir)) {
    New-Item -ItemType Directory -Path $publicDir -Force | Out-Null
    Write-Host "Created public directory" -ForegroundColor Cyan
}

# Step 5: Copy new build to public/front
Write-Host "Deploying new build..." -ForegroundColor Yellow

# Adjust this path based on your Angular project name
$sourcePath = ".\front_end\dist\front_end\browser"

if (Test-Path $sourcePath) {
    Copy-Item -Path $sourcePath -Destination $publicFront -Recurse -Force
    Write-Host "Deployment complete! The Force is strong with this build." -ForegroundColor Green
} else {
    Write-Host "Source path not found at: $sourcePath" -ForegroundColor Red
    Write-Host "Looking for dist directory contents:" -ForegroundColor Yellow
    
    # Try to find the actual build output
    $distPath = ".\front_end\dist"
    if (Test-Path $distPath) {
        Get-ChildItem -Path $distPath -Recurse | Select-Object FullName
        
        # Try to auto-detect the correct path
        $browserPaths = Get-ChildItem -Path $distPath -Recurse -Directory -Filter "browser" | Select-Object -First 1
        if ($browserPaths) {
            Write-Host "Found browser directory at: $($browserPaths.FullName)" -ForegroundColor Yellow
            Write-Host "Update the script's sourcePath variable to use this path." -ForegroundColor Yellow
        }
    } else {
        Write-Host "No dist directory found in front_end folder" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Deployment successful! May the Force serve you well." -ForegroundColor Cyan