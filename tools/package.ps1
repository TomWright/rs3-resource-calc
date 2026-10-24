# Builds the zip to upload to Mod.io. Only the files the plugin needs at
# runtime are included; docs/, tests/ and tools/ are left out.
# Usage (from the plugin folder):  powershell -File tools\package.ps1
#
# Entries are written with forward slashes (src/xp.lua) so the zip extracts
# correctly on every platform; Compress-Archive in Windows PowerShell 5.1
# writes backslashes instead.

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$root = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content (Join-Path $root "plugin.json") -Raw | ConvertFrom-Json
$outDir = Join-Path $root "dist"
$zipPath = Join-Path $outDir ("resource-calc-" + $manifest.version + ".zip")

New-Item -ItemType Directory -Force $outDir | Out-Null
if (Test-Path $zipPath) { Remove-Item $zipPath -Confirm:$false }

# main.lua and plugin.json must sit at the top level of the zip.
$files = @(
    Get-Item (Join-Path $root "main.lua")
    Get-Item (Join-Path $root "plugin.json")
    Get-ChildItem (Join-Path $root "src") -Recurse -File
    Get-ChildItem (Join-Path $root "data") -Recurse -File
)

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, "Create")
try {
    foreach ($file in $files) {
        $entryName = $file.FullName.Substring($root.Length + 1).Replace("\", "/")
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file.FullName, $entryName) | Out-Null
    }
} finally {
    $zip.Dispose()
}
Write-Output "Created $zipPath ($($files.Count) files)"
