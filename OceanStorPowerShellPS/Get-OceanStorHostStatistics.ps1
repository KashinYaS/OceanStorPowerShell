Function Get-OceanStorHostStatistics {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][PARAMETER(ParameterSetName='Hostname')][bool]$Silent=$true,
    [PARAMETER(Mandatory=$True,Position=6,HelpMessage = "Host name",ParameterSetName='Hostname')][String]$Name = $null,
    [PARAMETER(Mandatory=$True,Position=6,HelpMessage = "Host ID",ParameterSetName='ID')][int]$ID = $null
  )
  $RetVal = $null
  
  class Indicator {
    [int]$Id
    [string]$Name
    [string]$Units
	[int]$Value;
  }
 
  $Indicators = @(
    [Indicator]@{Id=19;Name='Queue Length';    Units='cmd' ; Value=-1},
    [Indicator]@{Id=21;Name='Block Bandwidth'; Units='MBps'; Value=-1},
    [Indicator]@{Id=22;Name='IOPS';            Units='ops' ; Value=-1},
    [Indicator]@{Id=23;Name='Read Bandwidth';  Units='MBps'; Value=-1},
    [Indicator]@{Id=25;Name='Read IOPS';       Units='ops' ; Value=-1},
    [Indicator]@{Id=26;Name='Write Bandwidth'; Units='MBps'; Value=-1},
    [Indicator]@{Id=28;Name='Write IOPS';      Units='ops' ; Value=-1}
    )
	
  Fix-OceanStorConnection

  if ($PSCmdlet.ParameterSetName -eq 'Hostname') {
      $ID = (Get-OceanStorHost  -OceanStor $OceanStor -Port $Port -Username $Username -Password $Password -Scope $Scope -Silent $True -Name $Name).ID
  }
	
  $body = @{username = "$($Username)";password = "$($Password)";scope = $Scope}
  
  $BaseRESTURI = "https://" + $OceanStor + ":" + $Port +"/deviceManager/rest/"
  $SessionURI = $BaseRESTURI  + "xxxxx/sessions"

  $logonsession = Invoke-RestMethod -Method "Post" -Uri $SessionURI -Body (ConvertTo-Json $body) -SessionVariable WebSession
  
  if ($logonsession -and ($logonsession.error.code -eq 0)) {
    $sessionid = $logonsession.data.deviceid
    $iBaseToken = $logonsession.data.iBaseToken
    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $($Username),'''$($Password''')))
    $header = @{Authorization = "Basic $base64AuthInfo";iBaseToken = $iBaseToken}
    $RESTURI = $BaseRESTURI  + $sessionid +"/"

    $UserCredentials = New-Object System.Management.Automation.PsCredential("$($Username)",$(ConvertTo-SecureString -String "$($Password)" -AsPlainText -force))

	$URI = $RESTURI  + "performance_statistic/cur_statistic_data?CMO_STATISTIC_UUID=21:"+$ID+"&CMO_STATISTIC_DATA_ID_LIST=" + ($Indicators.id -join ',')

    $result = Invoke-RestMethod -Method "Get" $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    if ($result -and ($result.error.code -eq 0)) {
      $RetVal = @()
	  $Values = $result.data.CMO_STATISTIC_DATA_LIST -split ','
	  $IDs    = $result.data.CMO_STATISTIC_DATA_ID_LIST -split ','
	  foreach ($ResultIndex in (0..($Values.Count-1))) {
	    $CurrentId    = $IDs[$ResultIndex]
		$CurrentValue = $Values[$ResultIndex]
		$CurrentIndicator = $Indicators | where {$_.Id -eq $CurrentId}
		$CurrentIndicator.Value = $CurrentValue
        $RetVal += $CurrentIndicator | select Id,Name,Value,Units
	  }
    }
    else {
      $RetVal = $null
	  if (-not $Silent) {
	    write-host "ERROR (Get-OceanStorHostStatistics): $($result.error.code); $($result.error.description)" -foreground "Red"
	  }
    }
  }
  
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
  
  Return($RetVal)
}

