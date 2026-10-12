param(
    [double]$Latitude = 0,
    [double]$Longitude = 0,
    [string]$City = "",
    [string]$EmulatorSerial = "emulator-5554"
)

Write-Host "🌍 Karipa Emulator Location Sync Tool" -ForegroundColor Cyan

# Locate adb executable
$adbPath = "adb"
$possiblePaths = @(
    "C:\Users\alzat\AppData\Local\Android\Sdk\platform-tools\adb.exe",
    "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe",
    "$env:ANDROID_HOME\platform-tools\adb.exe",
    "$env:USERPROFILE\AppData\Local\Android\Sdk\platform-tools\adb.exe"
)

foreach ($path in $possiblePaths) {
    if ($path -and (Test-Path $path)) {
        $adbPath = $path
        break
    }
}

Write-Host "[*] Using adb path: $adbPath" -ForegroundColor DarkGray

# Check if emulator is running
$devices = & $adbPath devices
if ($devices -notmatch $EmulatorSerial) {
    Write-Host "[-] Warning: Target emulator '$EmulatorSerial' not found in adb devices." -ForegroundColor Yellow
}

# Determine Coordinates
if ($Latitude -ne 0 -and $Longitude -ne 0) {
    Write-Host "[*] Using specified coordinates: Lat=$Latitude, Lon=$Longitude" -ForegroundColor Green
} elseif ($City -ne "") {
    Write-Host "[*] Looking up coordinates for city: $City..." -ForegroundColor Yellow
    try {
        $geoUri = "https://geocoding-api.open-meteo.com/v1/search?name=$([Uri]::EscapeDataString($City))&count=1"
        $geoRes = Invoke-RestMethod -Uri $geoUri -TimeoutSec 10
        if ($geoRes -and $geoRes.results -and $geoRes.results.Count -gt 0) {
            $Latitude = [double]$geoRes.results[0].latitude
            $Longitude = [double]$geoRes.results[0].longitude
            Write-Host "[+] Found $($geoRes.results[0].name), $($geoRes.results[0].country): Lat = $Latitude, Lon = $Longitude" -ForegroundColor Green
        } else {
            throw "City not found."
        }
    } catch {
        Write-Host "[-] Geocoding failed: $_" -ForegroundColor Red
        $Latitude = 14.5995
        $Longitude = 120.9842
    }
} else {
    Write-Host "[*] Fetching your current location via IP geolocation (ip-api.com)..." -ForegroundColor Yellow
    try {
        $response = Invoke-RestMethod -Uri "http://ip-api.com/json" -TimeoutSec 10
        if ($response -and $response.status -eq "success") {
            $Latitude = [double]$response.lat
            $Longitude = [double]$response.lon
            Write-Host "[+] Location detected: $($response.city), $($response.regionName), $($response.country)" -ForegroundColor Green
            Write-Host "[+] Coordinates: Lat = $Latitude, Lon = $Longitude" -ForegroundColor Green
        } else {
            throw "IP geolocation failed."
        }
    } catch {
        Write-Host "[-] Failed to fetch IP location: $_" -ForegroundColor Red
        Write-Host "[*] Falling back to default coordinates (Manila: Lat 14.5995, Lon 120.9842)" -ForegroundColor Yellow
        $Latitude = 14.5995
        $Longitude = 120.9842
    }
}

# Apply location to emulator via ADB
Write-Host "[*] Setting emulator ($EmulatorSerial) GPS location to Lon: $Longitude, Lat: $Latitude..." -ForegroundColor Cyan
& $adbPath -s $EmulatorSerial emu geo fix $Longitude $Latitude

if ($LASTEXITCODE -eq 0) {
    Write-Host "[SUCCESS] Emulator GPS location successfully updated to ($Latitude, $Longitude)!" -ForegroundColor Green
    Write-Host "[*] You can now test route generation in Karipa app with routes around your location." -ForegroundColor Cyan
} else {
    Write-Host "[-] Failed to set emulator location via adb." -ForegroundColor Red
}
