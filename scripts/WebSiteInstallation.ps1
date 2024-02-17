param (
    [string]$webSiteSourceFiles = "",
    [string]$webSiteName = "",
    [string]$webSitePath = "",
    [string]$rootWebSitePath = ""
	
)

if( $webSiteSourceFiles -eq $null -or $webSiteSourceFiles -eq "")
{
	Write-Host "webSiteSourceFiles param cannot be null or empty."
	Exit(1)
}

if( $webSiteName -eq $null -or $webSiteName -eq "")
{
	Write-Host "webSiteName param cannot be null or empty."
	Exit(1)
}

if( $webSitePath -eq $null -or $webSitePath -eq "")
{
	Write-Host "webSitePath param cannot be null or empty."
	Exit(1)
}

Add-Type -assembly "system.io.compression.filesystem"
Import-Module WebAdministration

$path = [string]::Format("{0}\{1}", $rootWebSitePath ,$webSitePath)
$webSite = (Get-WebsiteState -Name $webSiteName).Value

Write-Host "WebSite $webSite"

if($webSite -eq $null)
{
    Write-Host "ERROR : WebSite $webSiteName does not exist"
	Exit(1)
}
else
{
    Write-Host "WebSite exist"
	
	$webSiteStatus = (Get-WebsiteState -Name $webSiteName).Value
	
	Write-Host "WebSite status : " $webSiteStatus
	
	Stop-WebSite -Name $webSiteName
	
	$webSiteStatus = (Get-WebsiteState -Name $webSiteName).Value
	
	Write-Host "WebSite status : " $webSiteStatus
	
	if($webSiteStatus -ne "Stopped")
	{
		$maxRepeat = 20 	
		#wait for website to be stopped
		do 
		{		
			$webSiteStatus = (Get-WebsiteState -Name $webSiteName).Value
			Write-Host "wait for website to be stopped"
			$maxRepeat--
			sleep -Milliseconds 600
		} until ($webSiteStatus -eq "Stopped" -or $maxRepeat -eq 0)	
		
		if($webSiteStatus -ne "Stopped")
		{
			Write-Host "Error during stopping process."
			Exit(1)
		}
	}
	
	$oldZip = [string]::Format("{0}\old.zip", $path)
	if (Test-Path $oldZip)
	{
		Write-Host "Remove old zip"
		Write-Host "oldZip = " $oldZip
		Remove-Item $oldZip
	}
    Write-Host "Create old zip"
	
	$copyPath = [string]::Format("{0}\old$webSiteName", $rootWebSitePath)
	$destinationPath = [string]::Format("{0}\old.zip", $path)
	Copy-Item -Path $path -Destination $copyPath -Recurse -Force
	[io.compression.zipfile]::CreateFromDirectory($copyPath, $destinationPath)
	Remove-Item -Path $copyPath -Recurse -Force
}

$copyPath = [string]::Format("{0}\new$webSiteName", $rootWebSitePath)
New-Item -ItemType Directory -Force -Path $copyPath
[io.compression.zipfile]::ExtractToDirectory($webSiteSourceFiles, $copyPath)
Copy-Item -Path "$copyPath\*" -Destination $path -Recurse -Force
Remove-Item -Path $copyPath -Recurse -Force

Write-Host "Start website " $webSiteName
Start-WebSite -Name $webSiteName
$webSiteStatus = (Get-WebsiteState -Name $webSiteName).Value
Write-Host "WebSite status : " $webSiteStatus

if($webSiteStatus -ne "Started")
{
	$maxRepeat = 20 
	do 
	{
		$webSiteStatus = (Get-WebsiteState -Name $webSiteName).Value
		Write-Host "wait for service to be started"
		$maxRepeat--
		sleep -Milliseconds 600
	} until ($webSiteStatus-eq "Started" -or $maxRepeat -eq 0)

	if($webSiteStatus -eq "Stopped")
	{
		Write-Host "Error during process. Roolback to old version"

		$copyPath = [string]::Format("{0}\old$webSiteName", $rootWebSitePath)
		$sourcePath = [string]::Format("{0}\old.zip", $path)
		[io.compression.zipfile]::ExtractToDirectory($sourcePath, $copyPath)
		Remove-Item -Path "$path\*" -Recurse -Force
		Copy-Item -Path "$copyPath\*" -Destination $path -Recurse -Force
		Remove-Item -Path $copyPath -Recurse -Force
		
		Start-WebSite -Name $webSiteName
		$webSiteStatus = (Get-WebsiteState -Name $webSiteName).Value	
		
		if($webSiteStatus -ne "Started")
		{
			$maxRepeat = 20 
			do 
			{
				$webSiteStatus = (Get-WebsiteState -Name $webSiteName).Value
				Write-Host "wait for service to be started"
				$maxRepeat--
				sleep -Milliseconds 600
			} until ($webSiteStatus -eq "Started" -or $maxRepeat -eq 0)

			if($webSiteStatus -eq "Stopped")
			{
				Write-Host "Error during process. Roolback to old version failed."
				Exit(1)
			}
		}
	}
}

Exit(0)
