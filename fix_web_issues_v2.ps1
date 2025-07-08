# Fix Flutter Web Issues Script - Improved

Write-Host "Starting to fix Flutter web issues..." -ForegroundColor Green

# 1. Find and fix web_plugin_registrant.dart
$registrantFiles = Get-ChildItem -Path ".dart_tool" -Recurse -Filter "web_plugin_registrant.dart"

if ($registrantFiles.Count -eq 0) {
    Write-Host "No web_plugin_registrant.dart files found." -ForegroundColor Yellow
} else {
    foreach ($file in $registrantFiles) {
        Write-Host "Found registrant file: $($file.FullName)" -ForegroundColor Yellow
        
        # Read file content
        $content = Get-Content -Path $file.FullName -Raw
        
        # Check if file contains flutter_sound_web
        if ($content -match "flutter_sound_web") {
            Write-Host "Found flutter_sound_web reference in $($file.FullName)" -ForegroundColor Yellow
            
            # Create backup
            Copy-Item -Path $file.FullName -Destination "$($file.FullName).bak"
            
            # Create new content by removing flutter_sound_web imports and registerWith calls
            $newContent = $content -replace "import 'package:flutter_sound_web/flutter_sound_web.dart';", "// REMOVED: flutter_sound_web import"
            $newContent = $newContent -replace "FlutterSoundPlugin\.registerWith\(registrar\);", "// REMOVED: FlutterSoundPlugin.registerWith(registrar);"
            
            # Save modified content
            $newContent | Set-Content -Path $file.FullName
            
            Write-Host "Modified $($file.FullName) to remove flutter_sound_web references" -ForegroundColor Green
        } else {
            Write-Host "No flutter_sound_web references found in $($file.FullName)" -ForegroundColor Green
        }
    }
}

# 2. Create empty FontManifest.json if it doesn't exist
$fontManifestPath = "web\assets\FontManifest.json"
if (-not (Test-Path $fontManifestPath)) {
    Write-Host "Creating empty FontManifest.json" -ForegroundColor Yellow
    
    # Create directory if it doesn't exist
    $fontManifestDir = Split-Path -Path $fontManifestPath -Parent
    if (-not (Test-Path $fontManifestDir)) {
        New-Item -ItemType Directory -Path $fontManifestDir -Force | Out-Null
    }
    
    # Create empty JSON array
    "[]" | Set-Content -Path $fontManifestPath
    
    Write-Host "Created empty FontManifest.json at $fontManifestPath" -ForegroundColor Green
}

# 3. Create en-US.json as a copy of en.json
$enJsonPath = "assets\translations\en.json"
$enUSJsonPath = "assets\translations\en-US.json"

if ((Test-Path $enJsonPath) -and (-not (Test-Path $enUSJsonPath))) {
    Write-Host "Creating en-US.json from en.json" -ForegroundColor Yellow
    
    Copy-Item -Path $enJsonPath -Destination $enUSJsonPath
    
    Write-Host "Created en-US.json at $enUSJsonPath" -ForegroundColor Green
}

# 4. Run the app
Write-Host "All fixes applied! You can now run your app with:" -ForegroundColor Green
Write-Host "flutter run -d chrome --web-port=8081" -ForegroundColor Cyan
