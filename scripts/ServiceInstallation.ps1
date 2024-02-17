param (
    [string]$serviceSourceFiles = "",
    [string]$serviceName = "",
    [string]$serviceEXEName = "",
    [string]$servicePath = "",
    [string]$rootServicePath = "",
    [string]$startupType = "Automatic"
	
)

$StartupTypes = @("Automatic (Deleyed Start)","Automatic","Manual","Disabled")  

if( $serviceSourceFiles -eq $null -or $serviceSourceFiles -eq "")
{
	Write-Host "serviceSourceFiles param cannot be null or empty."
	Exit(1)
}

if( $serviceName -eq $null -or $serviceName -eq "")
{
	Write-Host "serviceName param cannot be null or empty."
	Exit(1)
}

if( $serviceEXEName -eq $null -or $serviceEXEName -eq "")
{
	Write-Host "serviceEXEName param cannot be null or empty."
	Exit(1)
}

if( $servicePath -eq $null -or $servicePath -eq "")
{
	Write-Host "servicePath param cannot be null or empty."
	Exit(1)
}

if( $startupType -NOTIN $StartupTypes)
{
	Write-Host [string]::Format("startupType param = {0} not an allowed type. 'Automatic (Deleyed Start)', 'Automatic', 'Manual' or 'Disabled' ",$startupType)
	Exit(1)
}

Add-Type -assembly "system.io.compression.filesystem"

$path = [string]::Format("{0}\{1}", $rootServicePath ,$servicePath)
$binaryPathName = [string]::Format("{0}\{1}", $path ,$serviceEXEName)
$service = Get-Service | Where-Object {$_.displayname -eq $serviceName}

if($service -ne $null)
{
    Write-Host "Service exist"
	Write-Host "Service status : " $service.status
	Stop-Service $service
	Write-Host "Service status : " $service.status
	
	if($service.status -ne "Stopped")
	{
		$maxRepeat = 20 	
		#wait for service to be stopped
		do 
		{
			Write-Host "wait for service to be stopped"
			$maxRepeat--
			sleep -Milliseconds 600
		} until ($service.status -eq "Stopped" -or $maxRepeat -eq 0)	
		
		if($service.status -ne "Stopped")
		{
			Write-Host "Error during stopping process."
			Exit(1)
		}
	}
	
    Write-Host "Delete service : " $serviceName
	sc.exe delete $serviceName
	
	$oldZip = [string]::Format("{0}\old.zip", $path)
	if (Test-Path $oldZip)
	{
		Write-Host "Remove old zip"
		Write-Host "oldZip = " $oldZip
		Remove-Item $oldZip
	}
    Write-Host "Create old zip"
	
	$copyPath = [string]::Format("{0}\old$serviceName", $rootServicePath)
	$destinationPath = [string]::Format("{0}\old.zip", $path)
	Copy-Item -Path $path -Destination $copyPath -Recurse -Force
	[io.compression.zipfile]::CreateFromDirectory($copyPath, $destinationPath)
	Remove-Item -Path $copyPath -Recurse -Force
}
	
$copyPath = [string]::Format("{0}\new$serviceName", $rootServicePath)
New-Item -ItemType Directory -Force -Path $copyPath
[io.compression.zipfile]::ExtractToDirectory($serviceSourceFiles, $copyPath)
Copy-Item -Path "$copyPath\*" -Destination $path -Recurse -Force
Remove-Item -Path $copyPath -Recurse -Force

Write-Host "Recreate service : " $serviceName
New-Service -Name $serviceName -DisplayName $serviceName -BinaryPathName $binaryPathName -StartupType $startupType
$service = Get-Service | Where-Object {$_.displayname -eq $serviceName}

Write-Host "Start service " $service.Name
Start-Service $service
Write-Host "Service status : " $service.status

if($service.status -ne "Running")
{
	$maxRepeat = 20 
	do 
	{
		Write-Host "wait for service to be started"
		$maxRepeat--
		sleep -Milliseconds 600
	} until ($service.status -eq "Running" -or $maxRepeat -eq 0)

	if($service.status -eq "Stopped")
	{
		Write-Host "Error during process. Roolback to old version"

		$copyPath = [string]::Format("{0}\old$serviceName", $rootServicePath)
		$sourcePath = [string]::Format("{0}\old.zip", $path)
		[io.compression.zipfile]::ExtractToDirectory($sourcePath, $copyPath)
		Remove-Item -Path "$path\*" -Recurse -Force
		Copy-Item -Path "$copyPath\*" -Destination $path -Recurse -Force
		Remove-Item -Path $copyPath -Recurse -Force

		Start-Service $service
		
		if($service.status -ne "Running")
		{
			$maxRepeat = 20 
			do 
			{
				Write-Host "wait for service to be started"
				$maxRepeat--
				sleep -Milliseconds 600
			} until ($service.status -eq "Running" -or $maxRepeat -eq 0)

			if($service.status -eq "Stopped")
			{
				Write-Host "Error during process. Roolback to old version failed."
				Exit(1)
			}
		}
	}
}

Exit(0)
