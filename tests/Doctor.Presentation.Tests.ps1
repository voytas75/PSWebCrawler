param([Parameter(Mandatory=$true)][string]$SnapshotPath)
$root=Split-Path $PSScriptRoot -Parent
$renderer=Join-Path $root 'tools\Show-PSWCDoctor.ps1'
$historical=[IO.File]::ReadAllText($SnapshotPath) | ConvertFrom-Json
function Copy-Report { ConvertTo-Json -InputObject $historical -Depth 20 -Compress | ConvertFrom-Json }
function Json-Report($Value) {ConvertTo-Json -InputObject $Value -Depth 20 -Compress}
Describe 'External Doctor presentation (historical snapshot fixtures)' {
 It 'P01 renders compact English summary from explicit object and pipeline' {
  $s=& $renderer -Report $historical
  $s | Should Be ($historical | & $renderer)
  ($s -split "`r?`n").Count | Should BeLessThan 8
  $s.Length | Should BeLessThan 1101
  $s | Should Match 'Checks=10; PASS=8; WARN=2; FAIL=0'
  $s | Should Not Match 'RecommendedAction:|https://|Get-Module'
 }
 It 'P02 gives explicit object and saved JSON parity in all views' {
  foreach($view in @('Summary','Detail','Machine')) {
   & $renderer -Report $historical -View $view | Should Be (& $renderer -JsonPath $SnapshotPath -View $view)
  }
 }
 It 'P03 preserves every top-level and check field and does not mutate input' {
  $before=Json-Report $historical
  $d=& $renderer -Report $historical -View Detail
  foreach($p in $historical.PSObject.Properties){if($p.Name -ne 'Checks'){$d.Contains($p.Name+': ') | Should Be $true}}
  foreach($c in $historical.Checks){foreach($p in $c.PSObject.Properties){$value=if($null -eq $p.Value){'null'}elseif($p.Value -is [string]){$p.Value}else{Json-Report $p.Value};$d.Contains($p.Name+': '+$value) | Should Be $true}}
  & $renderer -Report $historical -View Machine | Out-Null
  & $renderer -Report $historical | Out-Null
  Json-Report $historical | Should Be $before
 }
 It 'P04 rejects missing named check and invalid parameter combinations' {
  {& $renderer -Report $historical -View Detail -CheckName MissingIdentifier} | Should Throw 'Unknown check identifier: MissingIdentifier'
  {& $renderer -Report $historical -CheckName HapIdentity} | Should Throw
  {& $renderer -Report $historical -RequireQualification} | Should Throw
  {& $renderer -Report $historical -JsonPath $SnapshotPath} | Should Throw
 }
 It 'P05 preserves raw machine JSON, policy precedence and caller continuation' {
  foreach($status in @('PASS','WARN','FAIL')){foreach($healthy in @($true,$false)){foreach($qualified in @($true,$false)){foreach($require in @($true,$false)){
   $r=Copy-Report;$r.Status=$status;$r.Healthy=$healthy;$r.Qualified=$qualified
   $raw=@(& $renderer -Report $r -View Machine -RequireQualification:$require)
   $raw.Count | Should Be 1
   $m=$raw[0] | ConvertFrom-Json
   $expected=if($status -ceq 'FAIL'){'StatusFAIL'}elseif(-not $healthy){'Unhealthy'}elseif($require -and -not $qualified){'QualificationRequired'}else{'AcceptedByHealthPolicy'}
   $m.Decision.Reason | Should Be $expected
   $m.Decision.Accepted | Should Be ($expected -ceq 'AcceptedByHealthPolicy')
   Json-Report $m.Report | Should Be (Json-Report $r)
  }}}}
  $true | Should Be $true
 }
 It 'P06 roundtrips zero one many arrays and preserves long advice and safe characters' {
  foreach($count in @(0,1,3)){foreach($urls in @(0,1,3)){
   $r=Copy-Report;$r.Checks=@()
   for($i=0;$i -lt $count;$i++){$c=(Copy-Report).Checks[0];$c.Name='Synthetic'+$i;$c.Status=@('PASS','WARN','FAIL')[$i];$c.DocumentationUrls=@(for($j=0;$j -lt $urls;$j++){'https://example.invalid/'+$j});$c.RecommendedAction='Safe <>&" apostrophe '' '+([char]0x017C)+('long advice '*100)+'END';$r.Checks+= $c}
   $before=Json-Report $r
   $m=(& $renderer -Report $r -View Machine) | ConvertFrom-Json
   $m.Report.Checks -is [array] | Should Be $true
   $m.Report.Checks.Count | Should Be $count
   Json-Report $m.Report | Should Be $before
   $d=& $renderer -Report $r -View Detail
   foreach($c in $m.Report.Checks){$c.DocumentationUrls -is [array] | Should Be $true;$c.DocumentationUrls.Count | Should Be $urls;$d.Contains($c.RecommendedAction) | Should Be $true}
   $s=& $renderer -Report $r
   if($count -eq 3){($s.IndexOf('[FAIL] Synthetic2') -lt $s.IndexOf('[WARN] Synthetic1')) | Should Be $true}
   Json-Report $r | Should Be $before
  }}
 }
 It 'P07 rejects malformed schema and types without manufacturing decisions' {
  foreach($field in @('SchemaVersion','Status','Healthy','Qualified','Checks')){
   $r=Copy-Report;$r.PSObject.Properties.Remove($field)
   {& $renderer -Report $r -View Machine} | Should Throw
  }
  foreach($case in @(@('SchemaVersion','2.0'),@('Status','warn'),@('Healthy','false'),@('Qualified',1),@('Checks','foreign'))){$r=Copy-Report;$r.($case[0])=$case[1];{& $renderer -Report $r -View Machine} | Should Throw}
  $r=Copy-Report;$r.Checks[0].Status='BROKEN';{& $renderer -Report $r} | Should Throw
  {& $renderer -Report ([datetime]::Now)} | Should Throw
  {& $renderer -Report @{SchemaVersion='1.0'}} | Should Throw
 }
 It 'P09 rejects invalid JSON and incomplete check data' {
  $bad=Join-Path $TestDrive 'malformed.json';[IO.File]::WriteAllText($bad,'{not JSON')
  {& $renderer -JsonPath $bad -View Machine} | Should Throw 'Cannot read Doctor JSON'
  {& $renderer -JsonPath (Join-Path $TestDrive 'missing.json')} | Should Throw 'Cannot read Doctor JSON'
  foreach($field in @('Name','Status','Expected','Actual','Message','Hint','Impact','RecommendedAction','VerificationCommand','DocumentationUrls')){$r=Copy-Report;$r.Checks[0].PSObject.Properties.Remove($field);{& $renderer -Report $r} | Should Throw}
  foreach($case in @(@('Name',''),@('Message',1),@('DocumentationUrls','url'))){$r=Copy-Report;$r.Checks[0].($case[0])=$case[1];{& $renderer -Report $r} | Should Throw}
  $r=Copy-Report;$r.Checks[1].Name=$r.Checks[0].Name;{& $renderer -Report $r} | Should Throw
 }
 It 'P10 retains future data fields and normalizes summary control characters only' {
  $r=Copy-Report;$r | Add-Member NoteProperty Future @('one','two');$r.Checks[0] | Add-Member NoteProperty Extra ([pscustomobject]@{Values=@(1,2,3)})
  $r.Checks[0].Status='FAIL';$r.Checks[0].Name="Synthetic`nName";$r.Checks[0].Message="Safe`nmessage`rtext`tvalue"
  $d=& $renderer -Report $r -View Detail;$d.Contains('Future: ["one","two"]') | Should Be $true;$d.Contains('Extra: {"Values":[1,2,3]}') | Should Be $true
  $s=& $renderer -Report $r;$s | Should Match '\[FAIL\] Synthetic Name: Safe message text value'
  $m=(& $renderer -Report $r -View Machine) | ConvertFrom-Json;Json-Report $m.Report | Should Be (Json-Report $r)
 }
 It 'P11 supports native Doctor nested dictionaries without changing JSON' {
  $r=Copy-Report;$r.Checks[0].Expected=@{Names=@('one','two')};$r.Checks[0].Actual=[ordered]@{Count=2;Names=@('one','two')}
  $before=Json-Report $r;$m=(& $renderer -Report $r -View Machine) | ConvertFrom-Json
  Json-Report $m.Report | Should Be $before
  & $renderer -Report $r -View Detail | Should Match 'Expected:'
 }
 It 'P08 rejects executable script properties before reading them' {
  $r=Copy-Report;$r | Add-Member ScriptProperty Evil {throw 'Executed foreign getter'}
  {& $renderer -Report $r} | Should Throw 'Only data properties are supported'
 }
}
