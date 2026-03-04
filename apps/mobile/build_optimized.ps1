# TopScore AI - Optimized Web Build Script
# This script builds the Flutter web app with optimal performance settings

Write-Host "Starting optimized Flutter web build..." -ForegroundColor Cyan

# Clean previous build
Write-Host "`nCleaning previous build..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "`nGetting dependencies..." -ForegroundColor Yellow
flutter pub get

# Build with optimizations
Write-Host "`nBuilding with optimizations..." -ForegroundColor Yellow
Write-Host "   - Release mode (minification + tree shaking)" -ForegroundColor Gray
Write-Host "   - Auto renderer (Flutter 3.38+ default: HTML for fast load, CanvasKit for complex graphics)" -ForegroundColor Gray
Write-Host "   - Source maps for debugging" -ForegroundColor Gray

flutter build web --release --source-maps

if ($LASTEXITCODE -eq 0) {
    Write-Host "`nBuild completed successfully!" -ForegroundColor Green

    # Auto-generate version.json with build timestamp
    Write-Host "`nGenerating version.json..." -ForegroundColor Yellow
    $pubspec = Get-Content "pubspec.yaml" -Raw
    if ($pubspec -match 'version:\s*(.+)') {
        $appVersion = $Matches[1].Trim()
    } else {
        $appVersion = "0.0.0"
    }
    $buildTimestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $versionJson = @"
{
  "version": "$appVersion",
  "buildTimestamp": "$buildTimestamp"
}
"@
    # Write to both source (for git tracking) and build output
    $versionJson | Set-Content "web\version.json" -Encoding UTF8
    $versionJson | Set-Content "build\web\version.json" -Encoding UTF8
    Write-Host "   version.json -> v$appVersion @ $buildTimestamp" -ForegroundColor Gray
    
    # Show build size
    $mainDartJs = "build\web\main.dart.js"
    if (Test-Path $mainDartJs) {
        $size = (Get-Item $mainDartJs).Length / 1MB
        Write-Host "`nBundle size: $($size.ToString('0.00')) MB" -ForegroundColor Cyan
        
        if ($size -gt 2) {
            Write-Host "   Large bundle detected. Consider:" -ForegroundColor Yellow
            Write-Host "   - Running 'flutter pub run dependency_validator' to check unused dependencies" -ForegroundColor Gray
            Write-Host "   - Analyzing with 'source-map-explorer build\web\main.dart.js'" -ForegroundColor Gray
            Write-Host "   - Using deferred loading for large features" -ForegroundColor Gray
        }
    }
    Write-Host "`nBuild output: build\web\" -ForegroundColor Green
    Write-Host "Deploy with: firebase deploy --only hosting" -ForegroundColor Cyan
} else {
    Write-Host "`nBuild failed!" -ForegroundColor Red
    exit 1
}
