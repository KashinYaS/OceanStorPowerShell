Function Convert-OceanStorRPRunningStatus {
  [CmdletBinding(DefaultParameterSetName='default')]
  PARAM (
    [PARAMETER(Mandatory=$True, Position=0,HelpMessage = "OceanStor's Replication Status as integer",ParameterSetName='default')][int]$Status
	)
  $RetVal = $null
  switch ($Status) {
     1  {  $RetVal = 'Normal'}
    23  {  $RetVal = 'Synchronizing'}
    33  {  $RetVal = 'To be recovered'}
    34  {  $RetVal = 'Interrupted'}
    26  {  $RetVal = 'Split'}
    35  {  $RetVal = 'Invalid'}
    110 {  $RetVal = 'Standby'}
	default {$RetVal = 'Non-Documented status '}
  }
  return $RetVal
}

