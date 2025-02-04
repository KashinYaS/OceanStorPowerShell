Function Get-OceanStorLUNReport {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position= 0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='Default')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position= 1,HelpMessage = "Port",ParameterSetName='Default')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position= 2,HelpMessage = "Username",ParameterSetName='Default')][String]$Username,
    [PARAMETER(Mandatory=$True, Position= 3,HelpMessage = "Password",ParameterSetName='Default')][String]$Password,
    [PARAMETER(Mandatory=$False,Position= 4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='Default')][int]$Scope=0,
	[PARAMETER(Mandatory=$False,Position= 5,HelpMessage = "StartLunID - Include LUNs with ID greater or equal to StartLunID",ParameterSetName='Default')][int]$StartLunID=0,
	[PARAMETER(Mandatory=$False,Position= 6,HelpMessage = "Markdown - return markdown instead of PS object array",ParameterSetName='Default')][switch]$Markdown,
	[PARAMETER(Mandatory=$False,Position= 7,HelpMessage = "SkipTotals - Do not include total capacity bottom line in report",ParameterSetName='Default')][switch]$SkipTotals,
	[PARAMETER(Mandatory=$False,Position= 8,HelpMessage = "SkipStoragePool - Do not include Pool ID column in report",ParameterSetName='Default')][switch]$SkipStoragePool,
	[PARAMETER(Mandatory=$False,Position= 9,HelpMessage = "SkipHTML - Do not launch browser with HTML report",ParameterSetName='Default')][switch]$SkipHTML,
    [PARAMETER(Mandatory=$False,Position=10,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='Default')][bool]$Silent=$true	
  )

  # Storage Size output formatting
  # GiB for storage lesser than one TiB
  # TiB - for greater ones
  function Get-StorageSize {
    param (
      $SizeGB,
	  $Digits=3
    )
    if ($SizeGB -lt 1024) {
      $Result = "$([math]::round($SizeGB, $Digits)) GiB"
    }`
    else {
      $Result = "$([math]::round($SizeGB / 1024, $Digits)) TiB"
    }
    return($Result)
  }
  
  # Markdown formatting by iRon (https://stackoverflow.com/users/1701026/iron)
  # https://stackoverflow.com/questions/68937316/how-to-convert-a-powershell-output-to-a-md-markdown-file 
  function ConvertTo-MarkDownTable {
    [CmdletBinding()] param(
        [Parameter(Position = 0, ValueFromPipeLine = $True)] $InputObject
    )
    Begin { $Index = 0 }
    Process {
        if ( !$Index++ ) {
            '|' + ($_.PSObject.Properties.Name -Join '|') + '|'
            '|' + ($_.PSObject.Properties.ForEach({ '---' }) -Join '|') + '|'
        }
        '|' + ($_.PSObject.Properties.Value -Join '|') + '|'
    }
  }
  # end stackoverflow copy-paste
  
  $RetVal = @()

  Fix-OceanStorConnection
  
  $LUNs = Get-OceanStorLUN -OceanStor "$OceanStor" -Port "$Port" -Username "$Username" -Password "$Password" -Scope $Scope -AddCustomProps -Silent $true | where {[int]$_.ID -ge $StartLunID} | sort [int]ID
  if (-not $LUNs) {
    if (-not $Silent) {
	  write-host "Get-OceanStorLUNReport: No LUN(s) found" -foreground "Red"
	}
  }`
  else {
    $Hosts = Get-OceanStorHost -OceanStor "$OceanStor" -Port "$Port" -Username "$Username" -Password "$Password"  -Scope $Scope -Silent $true | sort [int]ID
    if ((-not $Hosts) -and (-not $Silent)) {
	  write-host "Get-OceanStorLUNReport: No Host(s) found" -foreground "Yellow"
	}
    
    $TmpReport = @()
    $ProcessedLUN = 0
    foreach ($LUN in $LUNs) {
      $CurrentName = $LUN.Name
      $PercentCompletedLUN = [math]::Floor($ProcessedLUN / $LUNs.Count * 100)
      Write-Progress -Activity "Processing LUN" -CurrentOperation "$($CurrentName)" -PercentComplete $PercentCompletedLUN

      $CurrentMappings = Get-OceanStorMappingAssociation -OceanStor "$OceanStor" -Username "$Username" -Password "$Password" -Scope $Scope -LunId "$($LUN.ID)"
  
      $CurrentHostNames = @()
      foreach ($CurrentMapping in $CurrentMappings) {
        if ($CurrentMapping.hostName) {
          $CurrentHostNames += $CurrentMapping.hostName
        }
        if ($CurrentMapping.hostGroupName) {
    	  $CurrentHostNames += "G:" + $CurrentMapping.hostGroupName
        }
      }
      
      $CurrentLUN = $LUN
      $CurrentLUN  | Add-Member -MemberType NoteProperty -Name MappedHostsList -Value $(($CurrentHostNames | Sort | Get-Unique) -join ',')

      $TmpReport += $CurrentLUN 
      $ProcessedLUN += 1
    }
    # end $TmpReport creation

    if ($SkipStoragePool) {
	  $Report = $TmpReport | Select ID,Name,@{N='Subscribed Capacity';E={Get-StorageSize($_.CapacityGB)}},@{N='Health';E={$_.HealthStatusHR}},@{N='Status';E={$_.RunningStatusHR}},@{N='Running Status Type';E={$_.AllocTypeHR}},WWN,@{N='Mapped';E={$_.MappedHostsList}},IsClone,@{N='Used Capacity';E={Get-StorageSize($_.AllocCapacityGB)}} | sort [int]ID
	}`
	else {
	  $Report = $TmpReport | Select ID,Name,@{N='Pool ID';E={$_.PARENTID}},@{N='Subscribed Capacity';E={Get-StorageSize($_.CapacityGB)}},@{N='Health';E={$_.HealthStatusHR}},@{N='Status';E={$_.RunningStatusHR}},@{N='Running Status Type';E={$_.AllocTypeHR}},WWN,@{N='Mapped';E={$_.MappedHostsList}},IsClone,@{N='Used Capacity';E={Get-StorageSize($_.AllocCapacityGB)}} | sort [int]ID
    }

    if (-not $SkipTotals) {
      $TotalSubscribed = ($LUNs | Measure-Object -Sum -Property "CapacityGB").Sum
      $TotalUsed       = ($LUNs | Measure-Object -Sum -Property "AllocCapacityGB").Sum

      $LUNTotal = New-Object PSObject -Property @{
          "ID" = ''
          "Name" = 'Total' 
          "Subscribed Capacity" = Get-StorageSize($TotalSubscribed)
          "Health" = ''
          "Status" = ''
          "Running Status Type" = ''
          "WWN" = ''
          "Mapped" = ''
          "ISCLONE" = ''
          "Used Capacity"       = Get-StorageSize($TotalUsed) 
      }
      if (-not $SkipStoragePool) {
        $LUNTotal | Add-Member -MemberType NoteProperty -Name 'Pool ID' -Value ''
        $Report += $LUNTotal | Select ID,Name,'Pool ID','Subscribed Capacity',Health,Status,'Running Status Type',WWN,Mapped,IsClone,'Used Capacity'    
	  }`
	  else {
        $Report += $LUNTotal | Select ID,Name,'Subscribed Capacity',Health,Status,'Running Status Type',WWN,Mapped,IsClone,'Used Capacity'    	    
	  }
	  
	  
	} #if (-not $SkipTotals) 
      
    if ($Markdown) {
	  $RetVal = $Report | ConvertTo-MarkDownTable
	}`
	else {
	  $RetVal = $Report
	}

	if (-not $SkipHTML) {
	  # HTML Export
      $Header = @" 
<style> 
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;} 
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; text-align: center;} 
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black; text-align: left;} 
TR:nth-child(even) {background-color: #D6EEEE;}
td:nth-child(1) {border-width: 1px; padding: 3px; border-style: solid; border-color: black; text-align: right;} 
td:nth-child(4) {border-width: 1px; padding: 3px; border-style: solid; border-color: black; text-align: right;} 
td:nth-child(11) {border-width: 1px; padding: 3px; border-style: solid; border-color: black; text-align: right;} 
td:nth-child(8) {border-width: 1px; padding: 3px; border-style: solid; border-color: black; font-family: monospace, monospace;} 
</style> 
"@

      $TempFile = [IO.Path]::GetTempFileName() | Rename-Item -NewName { $_ -replace 'tmp$', 'html' }   -PassThru 
      if (-not $TempFile) {
        if (-not $Silent) {
	      write-host "Get-OceanStorLUNReport: Cannot create temporary file" -foreground "Red"
	    }  
	  }`
	  else {
	    $TempFileName = Join-Path -Path $TempFile.Directory -ChildPath $TempFile.Name
		$Report | ConvertTo-Html -head $Header | out-file $TempFileName 
        Invoke-Expression "$TempFileName"
      }
	  
	} #if (-not $SkipHTML)
  }

  Return($RetVal)
}

