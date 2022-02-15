Function Get-OceanStorInterfaceModule {
  [CmdletBinding(DefaultParameterSetName="Default")]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's FQDN or IP address",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][String]$OceanStor,
    [PARAMETER(Mandatory=$False,Position=1,HelpMessage = "Port",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][int]$Port=8088,	
    [PARAMETER(Mandatory=$True, Position=2,HelpMessage = "Username",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][String]$Username,
    [PARAMETER(Mandatory=$True, Position=3,HelpMessage = "Password",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][String]$Password,
    [PARAMETER(Mandatory=$False,Position=4,HelpMessage = "Scope (0 - internal users, 1 - LDAP users)",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][int]$Scope=0,
    [PARAMETER(Mandatory=$False,Position=5,HelpMessage = "Silent - if set then function will not show error messages",ParameterSetName='Default')][PARAMETER(ParameterSetName='ID')][bool]$Silent=$true,
	[PARAMETER(Mandatory=$True, Position=6,HelpMessage = "InterfaceModule ID",ParameterSetName='ID')][int[]]$ID = $null
  )
  $RetVal = $null
 
  Fix-OceanStorConnection
 
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

    switch ( $PSCmdlet.ParameterSetName )
    {
      'ID' {
	    if ( $ID.Count -eq 1 ) {
	      $URI = $RESTURI  + "intf_module/" + $ID
	    }
	    else {
          $URI = $RESTURI  + "intf_module"
	    }
	  }
	  default { 
	    $URI = $RESTURI  + "intf_module" 
	  }
    }

    $result = Invoke-RestMethod -Method "Get" $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
    if ($result -and ($result.error.code -eq 0)) {
      switch ( $PSCmdlet.ParameterSetName )
      {
        'ID' {
	       if ( $ID.Count -eq 1 ) { 
	         $RetVal = $result.data		
	       }
	       else { # several objects specified - need to select some of them
	         $RetVal = $result.data | where { $ID -contains $_.ID }		     
			 if ($RetVal) {
			   if ($RetVal.Count -lt $ID.Count) {
			     if (-not $Silent) {
				   $NotFoundEncIDs = ($ID | where {$RetVal.ID -notcontains $_}) -join ','
		           write-host "WARNING (Get-OceanStorInterfaceModule): InterfaceModule(s) with ID(s) $($NotFoundEncIDs) not found" -foreground "Yellow"
		         }
			   }
			 }
			 else {
		       if (-not $Silent) {
		         write-host "ERROR (Get-OceanStorInterfaceModule): InterfaceModule(s) with ID(s) $($ID -join ',') not found" -foreground "Red"
		       }
             }
	       }		  
		}		  
	    default { 
	      $RetVal = $result.data 
	    }
      }	
    }
    else {
      $RetVal = $null
	  if (-not $Silent) {
	    write-host "ERROR (Get-OceanStorInterfaceModule): $($result.error.code); $($result.error.description)" -foreground "Red"
	  }
    }
  }
  
  $URI = $RESTURI  + "sessions"
  $SessionCloseResult = Invoke-RestMethod -Method Delete $URI -Headers $header -ContentType "application/json" -Credential $UserCredentials -WebSession $WebSession
  
  $RawRetVal = $RetVal
  $RetVal=@()
  foreach ($CurrentVal in $RawRetVal) {
	switch ($CurrentVal.Model) {
      '6'      { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2x10GE Optical Interface Module' }
      '12'     { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4xGE Electrical Interface Module' }
      '13'     { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4x8G FC Optical Interface Module' }
      '21'     { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4x10G FCoE Optical Interface Module' }
      '24'     { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue 'Management Board'}
	  '26'     { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue 'PCIe Interface Module' }
      '29'     { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2x16G FC Optical Interface Module' }
      '30'     { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4x12G SAS QSFP Interface Module' }
      '31'     { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4x10GE Electrical Interface Module' }
      '33'     { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2-port 4x14G IB I/O Module' }
      '35'     { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue 'Smart ACC Module' }
      '36'     { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4x10GE Electrical Interface Module' }
      '37'     { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4-port SmartIO I/O Module' }
      '38'     { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '8x8G FC Optical Interface Module' }
      '40'     { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4x16G FC Optical Interface Module' }
      '41'     { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '12-port 4x12G SAS Back-End Interconnect I/O Module' }
      '44'     { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2-port PCIe 3.0 Interface Module' }
      '516'    { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 1 Gbit/s ETH I/O module' }
      '518'    { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports BE 12 Gbit/s SAS I/O module' }
      '529'    { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue 'AI Accelerator Card' }
      '535'    { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue 'AI Accelerator Card' }
      '537'    { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 1 Gbit/s ETH I/O module' }
      '538'    { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports BE 12 Gbit/s SAS I/O module' }
      '580'    { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 1 Gbit/s ETH I/O module' }
      '583'    { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports BE 12 Gbit/s SAS V2 I/O module' }
      '601'    { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 1 Gbit/s ETH I/O module' }
      '2304'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 8 Gbit/s Fibre Channel I/O module' }
      '2305'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 16 Gbit/s Fibre Channel I/O module' }
      '2306'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 32 Gbit/s Fibre Channel I/O module' }
      '2307'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 10 Gbit/s ETH I/O module' }
      '2308'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 25 Gbit/s ETH I/O module' }
      '2309'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports SO 25 Gbit/s RDMA I/O module' }
      '2310'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 8 Gbit/s Fibre Channel I/O module' }
      '2311'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 16 Gbit/s Fibre Channel I/O module' }
      '2312'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 32 Gbit/s Fibre Channel I/O module' }
      '2313'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 10 Gbit/s ETH I/O module' }
	  '2314'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 25 Gbit/s ETH I/O module' }
      '2315'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports FE 40 Gbit/s ETH I/O module' }
      '2316'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports FE 100 Gbit/s ETH I/O module' }
      '2317'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports BE 100 Gbit/s RDMA I/O module' }
      '2318'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports SO 100 Gbit/s RDMA I/O module' }
      '2319'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports FE 40 Gbit/s ETH I/O module' }
      '2320'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports FE 100 Gbit/s ETH I/O module' }
      '2321'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports BE 100 Gbit/s RDMA I/O module' }
      '2322'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports SO 100 Gbit/s RDMA I/O module' }
      '2323'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 10 Gbit/s ROCE I/O module' }
      '2324'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 25 Gbit/s ROCE I/O module' }
      '2325'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 10 Gbit/s ROCE I/O module' }
      '2326'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 25 Gbit/s ROCE I/O module' }
      '2327'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports FE 40 Gbit/s ROCE I/O module' }
      '2328'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports FE 100 Gbit/s ROCE I/O module' }
      '2329'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports FE 40 Gbit/s ROCE I/O module' }
      '2330'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports FE 100 Gbit/s ROCE I/O module' }
      '2331'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 10 Gbit/s ETH I/O module' }
      '2332'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 10 Gbit/s ETH I/O module' }
      '2333'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 8 Gbit/s Fibre Channel I/O module' }
      '2334'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 16 Gbit/s Fibre Channel I/O module' }
      '2335'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 32 Gbit/s Fibre Channel I/O module' }
      '2336'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 10 Gbit/s ETH I/O module' }
      '2337'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 25 Gbit/s ETH I/O module' }
      '2338'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports SO 25 Gbit/s RDMA I/O module' }
      '2339'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 10 Gbit/s ROCE I/O module' }
      '2340'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 25 Gbit/s ROCE I/O module' }
      '2341'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 8 Gbit/s Fibre Channel I/O module' }
      '2342'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 16 Gbit/s Fibre Channel I/O module' }
      '2343'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 32 Gbit/s Fibre Channel I/O module' }
      '2344'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 10 Gbit/s ETH I/O module' }
      '2345'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 25 Gbit/s ETH I/O module' }
      '2346'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 10 Gbit/s ROCE I/O module' }
      '2347'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 25 Gbit/s ROCE I/O module' }
      '2348'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports FE 40 Gbit/s ETH I/O module' }
      '2349'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports FE 100 Gbit/s ETH I/O module' }
      '2350'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports BE 100 Gbit/s RDMA I/O module' }
      '2351'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports SO 100 Gbit/s RDMA I/O module' }
      '2352'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports FE 40 Gbit/s ROCE I/O module' }
      '2353'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports FE 100 Gbit/s ROCE I/O module' }
      '2354'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports FE 40 Gbit/s ETH I/O module' }
      '2355'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports FE 100 Gbit/s ETH I/O module' }
      '2356'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports BE 100 Gbit/s RDMA I/O module' }
      '2357'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports SO 100 Gbit/s RDMA I/O module' }
      '2358'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports FE 40 Gbit/s ROCE I/O module' }
      '2359'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports FE 100 Gbit/s ROCE I/O module' }
      '2360'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports FE 10 Gbit/s ETH I/O module' }
      '2361'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '4 ports SO 25 Gbit/s RDMA I/O module' }
      '2362'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports SO 100 Gbit/s RDMA I/O module' }
      '2363'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue '2 ports SO 100 Gbit/s RDMA I/O module' }
      '4133'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue 'System Management Module' }
      '4134'   { $CurrentVal | Add-Member -NotePropertyName 'ModelNameEx' -NotePropertyValue 'System Management Module' }
    }
	[array]$RetVal += $CurrentVal
  }
   
  Return($RetVal)
}

