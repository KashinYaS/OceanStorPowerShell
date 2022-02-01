Function Get-OceanStorCapacityInfo {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='Default')][String[]]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='Default')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='Default')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='Default')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='Default')][int]$Scope=0,
	[PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Storage Pool Threshold for oversubscription calculation. Defaults to 0.85",ParameterSetName='Default')][float]$PoolThreshold=0.85,
    [PARAMETER(Mandatory=$False,Position=6,HelpMessage = "TB fraction digits. Two digits by default",ParameterSetName='Default')][int]$TBDigits=2,
    [PARAMETER(Mandatory=$False,Position=7,HelpMessage = "Percent fraction digits. No fraction digits by default.",ParameterSetName='Default')][int]$PctDigits=0,
    [PARAMETER(Mandatory=$False,Position=8,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='Default')][bool]$Silent=$true
  )
  $RetVal = $null
  $OceanStorPropName = 'OceanStor'
  $TBConversion = 2147483648
    
  Fix-OceanStorConnection
  
  $CombinedInfoArray = @()
  $ProcessedOceanStors = 0 

  foreach ($CurrentOceanStor in $OceanStor) {
    if (-not $Silent) {
	  $PercentCompletedOceanStors= [math]::Floor($ProcessedOceanStors / $OceanStor.Count * 100)
      Write-Progress  -Activity "Processing OceanStor" -CurrentOperation $($CurrentOceanStor) -PercentComplete ($PercentCompletedOceanStors) -Id 1 
 	}  
	
	$DeviceInfo = Get-OceanStorDeviceInfo -OceanStor $CurrentOceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $Silent
	if (-not $DeviceInfo) {
	  write-host "ERROR (Get-OceanStorCapacityInfo): Cannot retrieve Device Info from OceanStor $($CurrentOceanStor)" -foreground 'red'
	}
	else {

	  $CombinedInfo = $DeviceInfo | Select Name,@{N='RAW_CAPACITY_TB';E={[math]::round($_.TOTALCAPACITY/$TBConversion,$TBDigits)}},`
	    @{N='POOL_CAPACITY_TB';E={[math]::round($_.STORAGEPOOLCAPACITY/$TBConversion,$TBDigits)}},`
		@{N='POOL_USED_TB';E={[math]::round($_.STORAGEPOOLUSEDCAPACITY/$TBConversion,$TBDigits)}},`
		@{N='POOL_USED_PCT';E={[math]::round($_.STORAGEPOOLUSEDCAPACITY/$_.STORAGEPOOLCAPACITY*100,$PctDigits)}},`
		@{N='POOL_FREE_PCT';E={[math]::round($_.STORAGEPOOLFREECAPACITY/$_.STORAGEPOOLCAPACITY*100,$PctDigits)}},`
		@{N='EXPORTED_TB';E={[math]::round($_.mappedLunsCountCapacity/$TBConversion,$TBDigits)}},`
		#@{N='POOL_OK_TB';E={[math]::round([float]$_.STORAGEPOOLCAPACITY * $PoolThreshold / $TBConversion,$TBDigits)}},`
		@{N='OVER_TB';E={[math]::round(($_.mappedLunsCountCapacity - ([float]$_.STORAGEPOOLCAPACITY * $PoolThreshold))/$TBConversion,$TBDigits)}}

	  [array]$CombinedInfoArray += $CombinedInfo
	}
	
	$ProcessedOceanStors += 1
  }
 
  $RetVal = $CombinedInfoArray
  
  Return($RetVal)
}
