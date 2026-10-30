# Repository-only renderer. Capture Doctor separately; advice is never executed.
[CmdletBinding(DefaultParameterSetName='Object')]
param(
 [Parameter(Mandatory=$true,ValueFromPipeline=$true,ParameterSetName='Object')][object]$Report,
 [Parameter(Mandatory=$true,ParameterSetName='Json')][ValidateNotNullOrEmpty()][string]$JsonPath,
 [ValidateSet('Summary','Detail','Machine')][string]$View='Summary',
 [string]$CheckName,
 [switch]$RequireQualification
)
begin {
 . (Join-Path $PSScriptRoot 'Doctor.Presentation.ps1')
 if($PSBoundParameters.ContainsKey('CheckName') -and ($View -ne 'Detail' -or [string]::IsNullOrWhiteSpace($CheckName))){throw 'CheckName requires View Detail and a nonempty identifier.'}
 if($PSBoundParameters.ContainsKey('RequireQualification') -and $View -ne 'Machine'){throw 'RequireQualification is supported only with View Machine.'}
}
process {
 $data=$Report
 if($PSCmdlet.ParameterSetName -eq 'Json'){
  try {$data=ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($JsonPath))) -ErrorAction Stop}
  catch {throw "Cannot read Doctor JSON: $($_.Exception.Message)"}
 }
 Assert-PSWCDoctorReport $data
 if($View -eq 'Machine'){
  $decision=Get-PSWCDoctorDecision $data -RequireQualification:$RequireQualification
  ConvertTo-Json -InputObject ([pscustomobject][ordered]@{Decision=$decision;Report=$data}) -Depth 20 -Compress
 }else{Format-PSWCDoctorReport $data $View $CheckName}
}
