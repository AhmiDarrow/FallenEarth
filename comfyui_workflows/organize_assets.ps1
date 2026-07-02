# organize_assets.ps1
# Run after ComfyUI batches: moves curated assets from ComfyUI output (or current dir) into structured FallenEarth/assets/
# Usage: cd to FallenEarth root or comfyui_workflows; pwsh .\comfyui_workflows\organize_assets.ps1
# Customize SOURCE and patterns as needed.

$ErrorActionPreference = "SilentlyContinue"

$root = "C:\Users\Administrator\FallenEarth"
$source = "$env:USERPROFILE\Documents\ComfyUI\output"   # typical Comfy output; change if you save elsewhere
$destTiles = "$root\assets\tilesets"
$destChars = "$root\assets\characters"
$destMobs = "$root\assets\mobs"
$destProps = "$root\assets\props"
$destStyle = "$root\assets\style_references"

# Create dirs
New-Item -ItemType Directory -Force -Path $destTiles, $destChars, $destMobs, $destProps, $destStyle | Out-Null

Write-Host "Organizing assets from $source to structured folders..."

# Tiles (common patterns from our batches)
Get-ChildItem -Path $source -Filter "*FallenEarth_Tile*" -File | ForEach-Object {
    Move-Item $_.FullName $destTiles -Force
    Write-Host "Moved tile: $($_.Name)"
}
Get-ChildItem -Path $source -Filter "*ash_wastes*" -File | ForEach-Object { Move-Item $_.FullName $destTiles -Force }
Get-ChildItem -Path $source -Filter "*rust_canyons*" -File | ForEach-Object { Move-Item $_.FullName $destTiles -Force }
# Add more biome patterns as generated

# Characters
Get-ChildItem -Path $source -Filter "*FallenEarth_Char*" -File | ForEach-Object {
    Move-Item $_.FullName $destChars -Force
    Write-Host "Moved char: $($_.Name)"
}
Get-ChildItem -Path $source -Filter "*_scavenger*" -File | ForEach-Object { Move-Item $_.FullName $destChars -Force }
Get-ChildItem -Path $source -Filter "*_technician*" -File | ForEach-Object { Move-Item $_.FullName $destChars -Force }
Get-ChildItem -Path $source -Filter "*_survivor*" -File | ForEach-Object { Move-Item $_.FullName $destChars -Force }

# Mobs
Get-ChildItem -Path $source -Filter "*FallenEarth_Mob*" -File | ForEach-Object {
    Move-Item $_.FullName $destMobs -Force
}

# Props / general wasteland items
Get-ChildItem -Path $source -Filter "*prop*" -File | ForEach-Object { Move-Item $_.FullName $destProps -Force }
Get-ChildItem -Path $source -Filter "*scrap*" -File | ForEach-Object { Move-Item $_.FullName $destProps -Force }
Get-ChildItem -Path $source -Filter "*rift*" -File | ForEach-Object { Move-Item $_.FullName $destProps -Force }

# Style refs (if any new masters)
Get-ChildItem -Path $source -Filter "*master_style*" -File | ForEach-Object { Move-Item $_.FullName $destStyle -Force }

Write-Host "Done. Review $dest* folders. Rename/move into subfolders (e.g. ash_wastes/) as desired."
Write-Host "Next: Import to Godot, build TileSets + SpriteFrames, test in scenes."