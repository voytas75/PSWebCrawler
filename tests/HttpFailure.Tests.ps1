$root=Split-Path $PSScriptRoot -Parent
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'PSWebCrawler\PSWebCrawler.psm1'),[ref]$tokens,[ref]$errors)
$fn=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-PSWCHttpResponse'},$true)
Add-Type -AssemblyName System.Net.Http
Invoke-Expression $fn.Extent.Text
Describe 'HTTP request failure classification (actual helper, offline client seam)' {
 BeforeEach {
  $script:calls=0;$script:failure=$null
  $script:client=New-Object PSObject -Property @{DefaultRequestHeaders=(New-Object Net.Http.HttpRequestMessage).Headers;Timeout=[TimeSpan]::Zero}
  $script:client|Add-Member ScriptMethod GetAsync {param($url) $script:calls++;if($script:failure){throw $script:failure};$r=New-Object Net.Http.HttpResponseMessage($script:status);[pscustomobject]@{Result=$r}}
  $script:status=[Net.HttpStatusCode]::OK
  Mock New-Object {$script:client} -ParameterFilter {$TypeName -eq 'System.Net.Http.HttpClient'}
 }
 It 'H01 normal response makes one request and preserves response shape' {$r=Get-PSWCHttpResponse -url 'https://fixture.test/';$script:calls|Should Be 1;$r.Count|Should Be 2;$r[1].IsSuccessStatusCode|Should Be $true}
 It 'H02 connection exception is not retried and preserves cause' {$script:failure=New-Object Net.Http.HttpRequestException('OFFLINE synthetic connection failure');{Get-PSWCHttpResponse -url 'https://fixture.test/'}|Should Throw 'OFFLINE synthetic connection failure';$script:calls|Should Be 1}
 It 'H03 timeout exception is not retried' {$script:failure=New-Object Threading.Tasks.TaskCanceledException('OFFLINE timeout');{Get-PSWCHttpResponse -url 'https://fixture.test/'}|Should Throw 'OFFLINE timeout';$script:calls|Should Be 1}
 It 'H04 invalid User-Agent format falls back before one request' {$r=Get-PSWCHttpResponse -url 'https://fixture.test/' -userAgent 'Mozilla/4.0 (compatible; MSIE 6.0; Windows CE; IEMobile 7.11) Sprint:PPC6800';$script:calls|Should Be 1;$r[1].IsSuccessStatusCode|Should Be $true;$script:client.DefaultRequestHeaders.Contains('User-Agent')|Should Be $false}
 It 'H05 HTTP 404 stays a status response without retry' {$script:status=[Net.HttpStatusCode]::NotFound;$r=Get-PSWCHttpResponse -url 'https://fixture.test/';$script:calls|Should Be 1;$r[1].StatusCode|Should Be ([Net.HttpStatusCode]::NotFound)}
 It 'H06 HTTP 500 stays a status response without retry' {$script:status=[Net.HttpStatusCode]::InternalServerError;$r=Get-PSWCHttpResponse -url 'https://fixture.test/';$script:calls|Should Be 1;$r[1].StatusCode|Should Be ([Net.HttpStatusCode]::InternalServerError)}
 It 'H07 client construction failure makes no request' {Mock New-Object {throw 'OFFLINE setup failure'} -ParameterFilter {$TypeName -eq 'System.Net.Http.HttpClient'};{Get-PSWCHttpResponse -url 'https://fixture.test/'}|Should Throw 'OFFLINE setup failure';$script:calls|Should Be 0}
}
