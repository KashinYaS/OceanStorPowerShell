Function Get-OceanStorDiskReport {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position= 0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='Default')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position= 1,HelpMessage = "Port",ParameterSetName='Default')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position= 2,HelpMessage = "Username",ParameterSetName='Default')][String]$Username,
    [PARAMETER(Mandatory=$True, Position= 3,HelpMessage = "Password",ParameterSetName='Default')][String]$Password,
    [PARAMETER(Mandatory=$False,Position= 4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='Default')][int]$Scope=0,
	[PARAMETER(Mandatory=$False,Position= 5,HelpMessage = "StartDiskID - Include Disks with ID greater or equal to StartDiskID",ParameterSetName='Default')][int]$StartDiskID=0,
	[PARAMETER(Mandatory=$False,Position= 6,HelpMessage = "Markdown - return markdown instead of PS object array",ParameterSetName='Default')][switch]$Markdown,
	[PARAMETER(Mandatory=$False,Position= 7,HelpMessage = "SkipHTML - Do not launch browser with HTML report",ParameterSetName='Default')][switch]$SkipHTML,
    [PARAMETER(Mandatory=$False,Position= 8,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='Default')][bool]$Silent=$true	
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
  
  $Disks = Get-OceanStorDisk -OceanStor "$OceanStor" -Port "$Port" -Username "$Username" -Password "$Password" -Scope $Scope -Silent $true | where {[int]$_.ID -ge $StartDiskID} | sort [int]ID | select *,@{N='LocShelf';E={($_.Location -split '\.')[0]}},@{N='LocPos';E={($_.Location -split '\.')[1]}}
  if (-not $Disks) {
    if (-not $Silent) {
	  write-host "Get-OceanStorDiskReport: No Disk(s) found" -foreground "Red"
	}
  }`
  else {
    
    $Report = $Disks | Sort LocShelf,{[int]$_.LocPos}  |% {$counter = -1} {$counter++; $_ | Add-Member -Name ReportID -Value $counter -MemberType NoteProperty -PassThru -Force} | select @{N='ID';E={$_.ReportId}},Location,Model,Barcode	
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
	      write-host "Get-OceanStorDiskReport: Cannot create temporary file" -foreground "Red"
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

