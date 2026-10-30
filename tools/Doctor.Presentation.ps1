# Private data-only helpers for the repository Doctor renderer; no product imports.
function Assert-PSWCDoctorData {
 param($Value,[int]$Depth=0)
 if($Depth -gt 18){throw 'Doctor data nesting exceeds the supported depth.'}
 if($null -eq $Value -or $Value -is [string] -or $Value -is [bool] -or $Value -is [ValueType]){return}
 if($Value -is [array]){foreach($item in $Value){Assert-PSWCDoctorData $item ($Depth+1)};return}
 if($Value.GetType() -eq [hashtable] -or $Value.GetType() -eq [System.Collections.Specialized.OrderedDictionary]){foreach($key in $Value.Keys){if($key -isnot [string]){throw 'Doctor data dictionary keys must be strings.'};Assert-PSWCDoctorData $Value[$key] ($Depth+1)};return}
 if($Value -isnot [pscustomobject] -or $Value.GetType() -ne [System.Management.Automation.PSCustomObject]){throw 'Doctor input must contain plain data objects, arrays and scalar values.'}
 foreach($p in $Value.PSObject.Properties){
  if($p.MemberType -ne 'NoteProperty'){throw 'Only data properties are supported.'}
  Assert-PSWCDoctorData $p.Value ($Depth+1)
 }
}
function Assert-PSWCDoctorReport {
 param($Report)
 Assert-PSWCDoctorData $Report
 if($null -eq $Report -or $Report -isnot [pscustomobject]){throw 'Doctor report must be a plain data object.'}
 foreach($name in @('SchemaVersion','Status','Healthy','Qualified','Checks')){
  if($null -eq $Report.PSObject.Properties[$name]){throw "Missing Doctor field: $name"}
 }
 if($Report.SchemaVersion -isnot [string] -or $Report.SchemaVersion -cne '1.0'){throw 'Supported Doctor SchemaVersion is 1.0.'}
 if($Report.Status -isnot [string] -or @('PASS','WARN','FAIL') -cnotcontains $Report.Status){throw 'Doctor Status must be PASS, WARN or FAIL.'}
 if($Report.Healthy -isnot [bool] -or $Report.Qualified -isnot [bool]){throw 'Doctor Healthy and Qualified must be Boolean values.'}
 if($Report.Checks -isnot [array]){throw 'Doctor Checks must be an array.'}
 $names=New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
 foreach($check in $Report.Checks){
  if($null -eq $check -or $check -isnot [pscustomobject]){throw 'Each Doctor check must be a plain data object.'}
  foreach($name in @('Name','Status','Expected','Actual','Message','Hint','Impact','RecommendedAction','VerificationCommand','DocumentationUrls')){if($null -eq $check.PSObject.Properties[$name]){throw "Missing Doctor check field: $name"}}
  if($check.Name -isnot [string] -or [string]::IsNullOrWhiteSpace($check.Name) -or -not $names.Add($check.Name)){throw 'Doctor check names must be nonempty unique strings.'}
  if($check.Status -isnot [string] -or @('PASS','WARN','FAIL') -cnotcontains $check.Status){throw 'Doctor check Status must be PASS, WARN or FAIL.'}
  foreach($name in @('Message','Hint','Impact','RecommendedAction','VerificationCommand')){if($check.$name -isnot [string]){throw "Doctor check $name must be a string."}}
  if($check.DocumentationUrls -isnot [array]){throw 'Doctor DocumentationUrls must be an array.'}
  foreach($url in $check.DocumentationUrls){if($url -isnot [string]){throw 'Doctor DocumentationUrls entries must be strings.'}}
 }
}
function ConvertTo-PSWCDoctorText {
 param($Value)
 if($null -eq $Value){return 'null'}
 if($Value -is [string]){return $Value}
 ConvertTo-Json -InputObject $Value -Depth 20 -Compress
}
function ConvertTo-PSWCDoctorCompactText {
 param($Value,[int]$Limit=120)
 $text=([string]$Value -replace '[\x00-\x1F\x7F]+',' ')
 if($text.Length -gt $Limit){$text=$text.Substring(0,$Limit-3)+'...'}
 $text
}
function Get-PSWCDoctorDecision {
 param($Report,[switch]$RequireQualification)
 $reason='AcceptedByHealthPolicy'
 if($Report.Status -ceq 'FAIL'){$reason='StatusFAIL'}
 elseif(-not $Report.Healthy){$reason='Unhealthy'}
 elseif($RequireQualification -and -not $Report.Qualified){$reason='QualificationRequired'}
 [pscustomobject][ordered]@{Policy=$(if($RequireQualification){'RequireQualification'}else{'Health'});Accepted=($reason -ceq 'AcceptedByHealthPolicy');Reason=$reason;Status=$Report.Status;Healthy=$Report.Healthy;Qualified=$Report.Qualified}
}
function Format-PSWCDoctorReport {
 param($Report,[string]$View,[string]$CheckName)
 $lines=New-Object 'System.Collections.Generic.List[string]'
 $lines.Add("CAPTURED REPORT; freshness is caller-owned | SchemaVersion=$($Report.SchemaVersion)")
 $lines.Add("[$($Report.Status)] Healthy=$($Report.Healthy); Qualified=$($Report.Qualified) (Status: severity; Healthy: health gate; Qualified: qualification gate)")
 if($View -eq 'Summary'){
  $lines.Add("Checks=$($Report.Checks.Count); PASS=$(@($Report.Checks | Where-Object Status -CEQ 'PASS').Count); WARN=$(@($Report.Checks | Where-Object Status -CEQ 'WARN').Count); FAIL=$(@($Report.Checks | Where-Object Status -CEQ 'FAIL').Count)")
  foreach($severity in @('FAIL','WARN')){foreach($check in $Report.Checks){if($check.Status -ceq $severity){
   $name=ConvertTo-PSWCDoctorCompactText $check.Name 80
   if($check.Name -ceq 'HapIdentity' -and $check.Expected.FullName -and $check.Actual.FullName){
    $expected=ConvertTo-PSWCDoctorCompactText (([string]$check.Expected.FullName -split 'Version=')[1] -split ',')[0] 40
    $actual=ConvertTo-PSWCDoctorCompactText (([string]$check.Actual.FullName -split 'Version=')[1] -split ',')[0] 40
    $lines.Add("[$severity] ${name}: expected=$expected; actual=$actual. Dependency-selected assembly; identity difference alone does not establish incompatibility.")
   }elseif($check.Name -ceq 'LegacyDisplayVersion'){
    $expected=ConvertTo-PSWCDoctorCompactText $check.Expected 40;$actual=ConvertTo-PSWCDoctorCompactText $check.Actual 40
    $lines.Add("[$severity] ${name}: expected=$expected; actual=$actual. Cosmetic display differs from loaded package version.")
   }else{$lines.Add("[$severity] ${name}: $(ConvertTo-PSWCDoctorCompactText $check.Message)")}
  }}}
  $lines.Add('PASS checks collapsed. Details: -View Detail -CheckName <identifier> (or omit -CheckName for all checks).')
 }else{
  foreach($p in $Report.PSObject.Properties){if($p.Name -cne 'Checks'){$lines.Add("$($p.Name): $(ConvertTo-PSWCDoctorText $p.Value)")}}
  $selected=@($Report.Checks | Where-Object {-not $CheckName -or $_.Name -ceq $CheckName})
  if($CheckName -and $selected.Count -eq 0){throw "Unknown check identifier: $CheckName"}
  $lines.Add('Checks:')
  foreach($check in $selected){$lines.Add("--- [$($check.Status)] $($check.Name) ---");foreach($p in $check.PSObject.Properties){$lines.Add("$($p.Name): $(ConvertTo-PSWCDoctorText $p.Value)")}}
 }
 $lines -join [Environment]::NewLine
}
