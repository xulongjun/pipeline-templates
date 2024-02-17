param (
    [string]$appSourceFiles = "",
    [string]$appPath = "",
    [string]$rootAppPath = "
	
)

if( $appSourceFiles -eq $null -or $appSourceFiles -eq "")
{
	Write-Host "appSourceFiles param cannot be null or empty."
	Exit(1)
}

if( $appPath -eq $null -or $appPath -eq "")
{
	Write-Host "appPath param cannot be null or empty."
	Exit(1)
}
if( $rootAppPath -eq $null -or $rootAppPath -eq "")
{
	Write-Host "rootAppPath param is at default : ''."
}

Add-Type -assembly "system.io.compression.filesystem"

$path = [string]::Format("{0}\{1}", $rootAppPath ,$appPath)

$oldZip = [string]::Format("{0}\old.zip", $path)

if (Test-Path $oldZip)
{
	Write-Host "Remove old zip"
	Write-Host "oldZip = " $oldZip
	Remove-Item $oldZip
}

Write-Host "Create old zip"

$copyPath = [string]::Format("{0}\old$appPath", $rootAppPath)
$destinationPath = [string]::Format("{0}\old.zip", $path)
Copy-Item -Path $path -Destination $copyPath -Recurse -Force
[io.compression.zipfile]::CreateFromDirectory($copyPath, $destinationPath)
Remove-Item -Path $copyPath -Recurse -Force

Write-Host "Extract new binary"

$copyPath = [string]::Format("{0}\new$appPath", $rootAppPath)
New-Item -ItemType Directory -Force -Path $copyPath
[io.compression.zipfile]::ExtractToDirectory($appSourceFiles, $copyPath)
Copy-Item -Path "$copyPath\*" -Destination $path -Recurse -Force
Remove-Item -Path $copyPath -Recurse -Force

Exit(0)
