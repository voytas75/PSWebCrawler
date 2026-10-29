# S2 orchestration only: fresh native PS5.1/Pester 3.4 process, offline facts.
$ProgressPreference='SilentlyContinue'
$root=Split-Path $PSScriptRoot -Parent
Import-Module (Join-Path $root 'PSWebCrawler\PSWebCrawler.psd1') -ErrorAction Stop
InModuleScope PSWebCrawler {
    function Assert-SiteError {
        param([hashtable]$Arguments,[string]$Code='InvalidArgument')
        $output=New-Object Collections.ArrayList; $caught=$null
        try { Invoke-PSWebCrawler @Arguments | ForEach-Object {[void]$output.Add($_)} } catch {$caught=$_}
        $output.Count | Should Be 0; ($null -ne $caught) | Should Be $true
        $caught.FullyQualifiedErrorId | Should Match ('^'+$Code+'(,|$)')
        if($Code -eq 'InvalidArgument'){$caught.CategoryInfo.Category | Should Be 'InvalidArgument'}
    }
    function Get-SiteResult {
        param([hashtable]$Options=@{})
        $arguments=@{Url='https://site.test/';Mode='Site';Depth=0}
        foreach($key in $Options.Keys){$arguments[$key]=$Options[$key]}
        Invoke-PSWebCrawler @arguments
    }
    function Assert-SiteFields {
        param($Value,[string]$Fields)
        ($Value.PSObject.Properties.Name -join ',') | Should Be $Fields
    }
    function Assert-SiteArrays {
        param($Value)
        foreach($name in 'Pages','Links','Errors'){($Value.$name -is [array]) | Should Be $true}
        foreach($page in $Value.Pages){if($null -ne $page.Extraction){
            foreach($name in 'Metadata','ImageUrls','ContactCandidates'){($page.Extraction.$name -is [array]) | Should Be $true}
        }}
    }
    function Invoke-SiteChild {
        param([string]$Body)
        $path=[IO.Path]::ChangeExtension($ExecutionContext.SessionState.Module.Path,'psd1').Replace("'","''")
        $code="`$ProgressPreference='SilentlyContinue';`$ErrorActionPreference='Stop';Import-Module '$path' -ErrorAction Stop;"+$Body
        $info=New-Object Diagnostics.ProcessStartInfo
        $info.FileName=Join-Path $PSHOME 'powershell.exe'
        $info.Arguments='-NoProfile -NonInteractive -EncodedCommand '+[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))
        $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
        $process=New-Object Diagnostics.Process;$process.StartInfo=$info;$started=$false
        try {
            $started=$process.Start()
            $stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
            if(-not $process.WaitForExit(20000)){$process.Kill();[void]$process.WaitForExit(5000);throw 'Child deadline exceeded'}
            if(-not $stdout.Wait(5000) -or -not $stderr.Wait(5000)){throw 'Child readers did not finish'}
            [pscustomobject]@{Exit=$process.ExitCode;Out=$stdout.Result;Err=$stderr.Result;Gone=$process.HasExited}
        }
        finally {if($started -and -not $process.HasExited){$process.Kill();[void]$process.WaitForExit(5000)};$process.Dispose()}
    }
    Describe 'S2 exact 32-case Site contract' {
        BeforeEach {
            $script:siteFetches=0;$script:sitePolicies=0;$script:siteCapabilities=0;$script:siteEvents=@()
            $script:siteHtml='';$script:siteType='text/html';$script:siteStatus=200;$script:siteError=$null
            $script:siteFinal='https://site.test/';$script:siteStamp='2026-10-28T12:00:00.0000000Z'
            $script:sitePolicy=[pscustomobject]@{Allowed=$true;Code=$null}
            $script:siteAnalyzerFault=$null
            # Pester 3.4 keeps It mocks until Describe exits; unmatched filters invoke the original analyzer.
            Mock Get-PSWCPageAnalysis {throw $script:siteAnalyzerFault} -ParameterFilter {$null -ne $script:siteAnalyzerFault}
            Mock Get-PSWCFrameworkRelease {528040}
            Mock Test-PSWCCapability {$script:siteCapabilities++;$script:siteEvents+='Capability';$true}
            Mock Get-PSWCStartPolicy {$script:sitePolicies++;$script:siteEvents+='Policy';$script:sitePolicy}
            Mock Invoke-PSWCFetchPage {
                $script:siteFetches++;$script:siteEvents+='Fetch'
                if($Uri.AbsoluteUri -ne 'https://site.test/'){throw 'Unexpected link-target fetch'}
                [pscustomobject]@{RequestedUrl=$Uri.AbsoluteUri;FinalUrl=$script:siteFinal;HttpStatus=$script:siteStatus;ContentType=$script:siteType;Content=$script:siteHtml;FetchedAtUtc=$script:siteStamp;Error=$script:siteError}
            }
        }
        It '01 API export and legacy manifest compatibility' {
            $path=[IO.Path]::ChangeExtension($ExecutionContext.SessionState.Module.Path,'psd1');$data=Import-PowerShellDataFile $path
            $t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($ExecutionContext.SessionState.Module.Path,[ref]$t,[ref]$e)
            @($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Invoke-PSWebCrawler'},$false)).Count | Should Be 1
            ($data.FunctionsToExport -join ',') | Should Be 'Start-PSWebCrawler,Invoke-PSWebCrawler'
            $data.ModuleVersion | Should Be '0.2.0';$data.PowerShellVersion | Should Be '5.1'
            $data.DotNetFrameworkVersion | Should Be '4.5';$data.CompatiblePSEditions | Should Be 'Desktop'
            ($data.RequiredModules -join ',') | Should Be 'PSparseHTML'
            foreach($alias in 'PSWC','PSWebCrawler'){(Get-Alias $alias).Definition | Should Be 'Start-PSWebCrawler'}
            $command=Get-Command Invoke-PSWebCrawler -Module PSWebCrawler -ErrorAction Stop
            foreach($name in 'Url','Mode','Depth','MaxPages','MaxHosts','MaxRunSeconds','TimeoutSeconds','MaxResponseBytes','MinHostIntervalSeconds','MaxRedirects','MaxLinks') {
                $command.Parameters[$name].ParameterType | Should Be ([object]);$command.Parameters[$name].Aliases.Count | Should Be 0
                foreach($a in $command.Parameters[$name].Attributes){if($a -is [Management.Automation.ParameterAttribute]){
                    $a.Mandatory | Should Be $false;$a.Position | Should Be ([int]::MinValue)
                    $a.ValueFromPipeline | Should Be $false;$a.ValueFromPipelineByPropertyName | Should Be $false
                }}
            }
            foreach($name in 'Json','OutputPath','Transport','AllowIntranet'){$command.Parameters.ContainsKey($name) | Should Be $false}
        }
        It '02 fresh real import exposes commands and survives' {
            $c=Invoke-SiteChild "[pscustomobject]@{New=(Get-Command Invoke-PSWebCrawler -Module PSWebCrawler).Name;Legacy=(Get-Command Start-PSWebCrawler -Module PSWebCrawler).Name;Alias=(Get-Alias PSWC).Definition;Other=(Get-Alias PSWebCrawler).Definition;Release=(& (Get-Module PSWebCrawler) {Get-PSWCFrameworkRelease})}|ConvertTo-Json -Compress"
            $c.Exit | Should Be 0;$c.Gone | Should Be $true;$c.Err | Should Be '';$v=$c.Out | ConvertFrom-Json
            $v.New | Should Be 'Invoke-PSWebCrawler';$v.Legacy | Should Be 'Start-PSWebCrawler'
            $v.Alias | Should Be 'Start-PSWebCrawler';$v.Other | Should Be 'Start-PSWebCrawler'
            ($v.Release -is [int] -and $v.Release -ge 528040) | Should Be $true
        }
        It '03 missing Mode fails without prompts or results in a child' {
            $c=Invoke-SiteChild 'try {Invoke-PSWebCrawler -Url https://site.test/;exit 9} catch {[Console]::Out.Write($_.FullyQualifiedErrorId);exit 7}'
            $c.Exit | Should Be 7;$c.Gone | Should Be $true;$c.Err | Should Be '';$c.Out | Should Match '^InvalidArgument,Invoke-PSWebCrawler\s*$'
        }
        It '04 missing Url fails without prompts or results in a child' {
            $c=Invoke-SiteChild 'try {Invoke-PSWebCrawler -Mode Site;exit 9} catch {[Console]::Out.Write($_.FullyQualifiedErrorId);exit 7}'
            $c.Exit | Should Be 7;$c.Gone | Should Be $true;$c.Err | Should Be '';$c.Out | Should Match '^InvalidArgument,Invoke-PSWebCrawler\s*$'
        }
        It '05 Mode validates raw inputs and canonical casing' {
            foreach($v in @($null,'','Unknown',1,$true,@('Site'))){Assert-SiteError @{Url='https://site.test/';Mode=$v;Depth=0}}
            (Get-SiteResult @{Mode='sItE'}).Run.Mode | Should Be 'Site'
        }
        It '06 Url rejects invalid schemes userinfo controls and trimming' {
            foreach($v in @($null,'','/relative','ftp://site.test/','https://u:p@site.test/',"https://site.test/`n",("https://site.test/"+[char]0x85),' https://site.test/','https://site.test/ ',1,[uri]'https://site.test/',@('https://site.test/'))){Assert-SiteError @{Url=$v;Mode='Site';Depth=0}}
            $script:siteFetches | Should Be 0;$script:sitePolicies | Should Be 0
        }
        It '07 every integral limit validates ranges raw types and native binding' {
            foreach($name in 'Depth','MaxPages','MaxHosts','MaxRunSeconds','TimeoutSeconds','MaxResponseBytes','MinHostIntervalSeconds','MaxRedirects','MaxLinks') {
                $min=1;if($name -eq 'Depth'){$min=0}
                foreach($v in @($null,'1',1.0,[single]1,[decimal]1,$true,@(1),@(1,2),@(),-1,[long]2147483648,[uint64]::MaxValue)){
                    $a=@{Url='https://site.test/';Mode='Domains';Depth=0};$a[$name]=$v;Assert-SiteError $a
                }
                if($min -eq 1){$a=@{Url='https://site.test/';Mode='Domains';Depth=0};$a[$name]=0;Assert-SiteError $a}
                foreach($v in @([byte]$min,[sbyte]$min,[int16]$min,[uint16]$min,[int]$min,[sbyte]127,[byte]255,[int16]32767,[uint16]65535,[int]2147483647,[uint32]2147483647,[long]2147483647,[uint64]2147483647)){
                    $a=@{Url='https://site.test/';Mode='Domains';Depth=0};$a[$name]=$v;Assert-SiteError $a 'UnsupportedMode'
                }
            }
            Assert-SiteError @{Url='https://site.test/';Mode='Site';Depth=0;Bogus=1} 'NamedParameterNotFound'
            $caught=$null;try {Invoke-PSWebCrawler 'https://site.test/' Site} catch {$caught=$_}
            $caught.FullyQualifiedErrorId | Should Match '^PositionalParameterNotFound';$script:siteFetches | Should Be 0
        }
        It '08 explicit Site MaxHosts always rejected' {
            foreach($v in @($null,20,1)){Assert-SiteError @{Url='https://site.test/';Mode='Site';Depth=0;MaxHosts=$v}}
        }
        It '09 effective defaults and closed ordered Parameters' {
            $p=(Get-SiteResult).Run.Parameters
            Assert-SiteFields $p 'Url,Mode,Depth,MaxPages,MaxHosts,MaxRunSeconds,TimeoutSeconds,MaxResponseBytes,MinHostIntervalSeconds,MaxRedirects,MaxLinks'
            $p.Url | Should Be 'https://site.test/';$p.Mode | Should Be 'Site';$p.Depth | Should Be 0;$p.MaxPages | Should Be 50
            ($null -eq $p.MaxHosts) | Should Be $true;$p.MaxRunSeconds | Should Be 300;$p.TimeoutSeconds | Should Be 15
            $p.MaxResponseBytes | Should Be 5242880;$p.MinHostIntervalSeconds | Should Be 1;$p.MaxRedirects | Should Be 5;$p.MaxLinks | Should Be 10000
            foreach($name in 'Depth','MaxPages','MaxRunSeconds','TimeoutSeconds','MinHostIntervalSeconds','MaxRedirects','MaxLinks'){($p.$name -is [int]) | Should Be $true}
            ($p.MaxResponseBytes -is [long]) | Should Be $true
            $p=(Get-SiteResult @{MaxPages=[byte]1;MaxResponseBytes=[uint64]2147483647}).Run.Parameters
            $p.MaxPages | Should Be 1;$p.MaxResponseBytes | Should Be 2147483647
        }
        It '10 omitted and positive Depth remain unavailable with capability false' {
            Mock Test-PSWCCapability {$false}
            Assert-SiteError @{Url='https://site.test/';Mode='Site'} 'CapabilityUnavailable'
            foreach($d in 1,2,2147483647){Assert-SiteError @{Url='https://site.test/';Mode='Site';Depth=$d} 'CapabilityUnavailable'}
            Assert-MockCalled Test-PSWCCapability -Times 4 -Exactly -Scope It
            $script:sitePolicies | Should Be 0;$script:siteFetches | Should Be 0
        }
        It '11 valid Domains fails before runtime run policy and fetch' {
            Mock Get-PSWCFrameworkRelease {throw 'Runtime reader reached'}
            Assert-SiteError @{Url='https://site.test/';Mode='dOmAiNs';Depth=0} 'UnsupportedMode'
            Assert-MockCalled Get-PSWCFrameworkRelease -Times 0 -Exactly -Scope It
            $script:sitePolicies | Should Be 0;$script:siteFetches | Should Be 0
        }
        It '12 actual Framework reader is guarded independently of capability' {
            foreach($r in @($null,0,461814,528039,'528040')){
                $script:siteRelease=$r;Mock Get-PSWCFrameworkRelease {$script:siteRelease}
                Assert-SiteError @{Url='https://site.test/';Mode='Site';Depth=0} 'CapabilityUnavailable'
            }
            Mock Get-PSWCFrameworkRelease {throw 'registry path password'}
            Assert-SiteError @{Url='https://site.test/';Mode='Site';Depth=0} 'CapabilityUnavailable'
            Assert-MockCalled Test-PSWCCapability -Times 0 -Exactly -Scope It
            $script:sitePolicies | Should Be 0;$script:siteFetches | Should Be 0
        }
        It '13 unmocked HTTP and HTTPS fail closed before any run or transport' {
            foreach($scheme in 'http','https'){
                $body=@'
$m=Get-Module PSWebCrawler
& $m {
    function script:Get-PSWCFrameworkRelease {528040}
    function script:Get-PSWCStartPolicy {throw 'Policy reached'}
    function script:Invoke-PSWCFetchPage {throw 'Fetch reached'}
    function script:New-PSWCResult {throw 'Run reached'}
}
try {Invoke-PSWebCrawler -Mode Site -Depth 0 -Url 'SCHEME://site.test/';exit 9}
catch {[Console]::Out.Write($_.FullyQualifiedErrorId);exit 7}
'@
                $c=Invoke-SiteChild $body.Replace('SCHEME',$scheme)
                $c.Exit | Should Be 7;$c.Out | Should Match '^CapabilityUnavailable,Invoke-PSWebCrawler\s*$';$c.Gone | Should Be $true;$c.Err | Should Be ''
            }
        }
        It '14 policy precedes one admitted start fetch with catch-all target rejection' {
            $script:siteHtml='<a href="https://site.test/next">next</a><a href="https://other.test/">other</a>';$r=Get-SiteResult
            ($script:siteEvents -join ',') | Should Be 'Capability,Policy,Fetch';$r.Pages.Count | Should Be 1;$r.Pages[0].Depth | Should Be 0
            $script:siteCapabilities | Should Be 1;$script:sitePolicies | Should Be 1
            Assert-MockCalled Invoke-PSWCFetchPage -Times 1 -Exactly -Scope It -ParameterFilter {$Uri.AbsoluteUri -eq 'https://site.test/'}
        }
        It '15 distinct host relations remain at DepthLimit or OutsideScope' {
            $script:siteHtml='<a href="https://site.test/a#x">a</a><a href="https://site.test/a#y">repeat</a><a href="https://other.test/a">other</a><a href="https://sub.site.test/a">sub</a>'
            $r=Get-SiteResult;$r.Links.Count | Should Be 3;$r.Links[0].TargetUrl | Should Be 'https://site.test/a'
            $r.Links[0].Relation | Should Be 'SameHost';$r.Links[0].Admission | Should Be 'DepthLimit'
            foreach($link in $r.Links[1..2]){$link.Relation | Should Be 'ExternalHost';$link.Admission | Should Be 'OutsideScope'}
            $r.Links[2].TargetHost | Should Be 'sub.site.test';$script:siteFetches | Should Be 1
        }
        It '16 one result closed fields UTC identifiers status and nulls' {
            $script:siteHtml='<a href="https://site.test/a">a</a><meta name="n" content="v"><a href="mailto:a@x.test">mail</a>'
            $output=@(Get-SiteResult);$output.Count | Should Be 1;$r=$output[0]
            Assert-SiteFields $r 'Run,Pages,Links,Errors'
            Assert-SiteFields $r.Run 'SchemaVersion,RunId,Mode,StartUrl,StartedAtUtc,FinishedAtUtc,Parameters,Status,StopReason'
            Assert-SiteFields $r.Pages[0] 'RequestedUrl,FinalUrl,Depth,FetchedAtUtc,HttpStatus,ContentType,Status,Extraction'
            Assert-SiteFields $r.Links[0] 'SourceUrl,TargetUrl,TargetHost,Relation,Admission'
            Assert-SiteFields $r.Pages[0].Extraction 'Title,Metadata,ImageUrls,ContactCandidates'
            Assert-SiteFields $r.Pages[0].Extraction.Metadata[0] 'Name,Value,SourceUrl'
            Assert-SiteFields $r.Pages[0].Extraction.ContactCandidates[0] 'Kind,Value,SourceUrl'
            ([guid]$r.Run.RunId).ToString() | Should Be $r.Run.RunId
            foreach($s in $r.Run.StartedAtUtc,$r.Run.FinishedAtUtc,$r.Pages[0].FetchedAtUtc){$s | Should Match '^\d{4}-\d{2}-\d{2}T.*Z$'}
            $r.Run.SchemaVersion | Should Be '1.0';$r.Run.Status | Should Be 'Completed';($null -eq $r.Run.StopReason) | Should Be $true
            $r.Pages[0].Status | Should Be 'Fetched';($r.Pages[0].HttpStatus -is [int]) | Should Be $true;$r.Errors.Count | Should Be 0;Assert-SiteArrays $r
        }
        It '17 empty HTML succeeds with empty available extraction' {
            $r=Get-SiteResult;$r.Pages[0].Status | Should Be 'Fetched';($null -eq $r.Pages[0].Extraction.Title) | Should Be $true
            foreach($name in 'Metadata','ImageUrls','ContactCandidates'){$r.Pages[0].Extraction.$name.Count | Should Be 0}
        }
        It '18 first title decodes trims and empty first stays null' {
            $script:siteHtml='<title> A &amp; B </title><title>second</title>';(Get-SiteResult).Pages[0].Extraction.Title | Should Be 'A & B'
            $script:siteHtml='<title> </title><title>second</title>';($null -eq (Get-SiteResult).Pages[0].Extraction.Title) | Should Be $true
        }
        It '19 metadata duplicates order content presence selectors provenance' {
            $script:siteHtml='<meta name=" a&amp;b " content=" v&amp;x "><meta name="a&amp;b" content="v&amp;x"><meta name="empty" content=""><meta name="missing"><meta name=" " content="x"><meta property="og:title" content="x"><meta http-equiv="refresh" content="x"><meta charset="utf-8">'
            $m=(Get-SiteResult).Pages[0].Extraction.Metadata;$m.Count | Should Be 3;$m[0].Name | Should Be 'a&b';$m[0].Value | Should Be 'v&x'
            $m[1].Name | Should Be $m[0].Name;$m[1].Value | Should Be $m[0].Value;$m[2].Name | Should Be 'empty';$m[2].Value | Should Be ''
            foreach($v in $m){$v.SourceUrl | Should Be 'https://site.test/'}
        }
        It '20 images normalize dedup ordinally preserve queries and order' {
            $script:siteHtml='<img><img src=""><img src="data:a"><img src="https://site.test/a.png#x"><img src="https://site.test/a.png#y"><img src="https://site.test/a.png?q=1"><img src="https://site.test/A.png">'
            ((Get-SiteResult).Pages[0].Extraction.ImageUrls -join ',') | Should Be 'https://site.test/a.png,https://site.test/a.png?q=1,https://site.test/A.png'
        }
        It '21 contacts decode once preserve plus extension dedup provenance' {
            $script:siteHtml='<a href="mailto:a%2Bb%40x.test,c%40x.test?subject=x">mail</a><a href="mailto:a%2Bb%40x.test,,">dup</a><a href="tel:%2B48123;ext=4">tel</a><a href="tel:%2B48123;ext=4">dup</a><a href="mailto:">empty</a><a href="mailto:%252B@x.test">once</a><p>guess@x.test</p>'
            $c=(Get-SiteResult).Pages[0].Extraction.ContactCandidates;$c.Count | Should Be 4
            $c[0].Kind | Should Be 'Email';$c[0].Value | Should Be 'a+b@x.test';$c[1].Value | Should Be 'c@x.test'
            $c[2].Kind | Should Be 'Phone';$c[2].Value | Should Be '+48123;ext=4';$c[3].Value | Should Be '%2B@x.test'
            foreach($v in $c){$v.SourceUrl | Should Be 'https://site.test/'}
        }
        It '22 zero arrays and nulls survive real constructor JSON' {
            $r=New-PSWCResult -Run (Get-SiteResult).Run -Pages @() -Links @() -Errors @()
            Assert-SiteArrays $r;$j=$r | ConvertTo-Json -Depth 20 | ConvertFrom-Json;Assert-SiteArrays $j
            foreach($name in 'Pages','Links','Errors'){$j.$name.Count | Should Be 0}
            ($null -eq $j.Run.StopReason) | Should Be $true;($null -eq $j.Run.Parameters.MaxHosts) | Should Be $true
            $j=Get-SiteResult | ConvertTo-Json -Depth 20 | ConvertFrom-Json;Assert-SiteArrays $j;($null -eq $j.Pages[0].Extraction.Title) | Should Be $true
        }
        It '23 singleton nested arrays survive invocation JSON' {
            $script:siteHtml='<meta name="n" content="v"><img src="https://site.test/a.png"><a href="mailto:a@x.test">mail</a><a href="https://site.test/a">a</a>'
            $r=Get-SiteResult;$j=$r | ConvertTo-Json -Depth 20 | ConvertFrom-Json;Assert-SiteArrays $r;Assert-SiteArrays $j
            $j.Pages.Count | Should Be 1;$j.Links.Count | Should Be 1
            foreach($name in 'Metadata','ImageUrls','ContactCandidates'){$j.Pages[0].Extraction.$name.Count | Should Be 1}
            ($j | ConvertTo-Json -Depth 20 -Compress) | Should Be ($r | ConvertTo-Json -Depth 20 -Compress);$script:siteFetches | Should Be 1
            $script:siteError=[pscustomobject]@{Stage='Fetch';Code='Timeout'};$j=Get-SiteResult | ConvertTo-Json -Depth 20 | ConvertFrom-Json
            Assert-SiteArrays $j;$j.Errors.Count | Should Be 1
        }
        It '24 many arrays use real constructor without claiming traversal' {
            $script:siteHtml='<meta name="a" content="1"><meta name="b" content="2"><img src="https://site.test/a"><img src="https://site.test/b"><a href="mailto:a@x.test,b@x.test">mail</a><a href="https://site.test/a">a</a><a href="https://other.test/b">b</a>';$r=Get-SiteResult
            $errors=@((New-PSWCError -Stage Fetch -Url $r.Run.StartUrl -Code Timeout),(New-PSWCError -Stage Parse -Url $r.Run.StartUrl -Code ParseError))
            $many=New-PSWCResult -Run $r.Run -Pages @($r.Pages[0],$r.Pages[0]) -Links $r.Links -Errors $errors
            $j=$many | ConvertTo-Json -Depth 20 | ConvertFrom-Json;Assert-SiteArrays $j
            foreach($name in 'Pages','Links','Errors'){$j.$name.Count | Should Be 2}
            foreach($name in 'Metadata','ImageUrls','ContactCandidates'){$j.Pages[0].Extraction.$name.Count | Should Be 2}
            $script:siteFetches | Should Be 1
        }
        It '25 policy denial creates no page attempt' {
            foreach($code in 'NetworkTargetDenied','RobotsDenied','RobotsFetchFailed','RobotsInvalid'){
                $script:sitePolicy=[pscustomobject]@{Allowed=$false;Code=$code};$r=Get-SiteResult
                $r.Run.Status | Should Be 'Failed';$r.Run.StopReason | Should Be $code;$r.Pages.Count | Should Be 0;$r.Errors.Count | Should Be 1
                $r.Errors[0].Stage | Should Be 'Policy';$r.Errors[0].Code | Should Be $code;$r.Errors[0].Url | Should Be 'https://site.test/'
                Assert-SiteFields $r.Errors[0] 'Stage,Url,Code,Message'
            }
            $script:sitePolicy=[pscustomobject]@{Allowed=$false;Code='UnknownPrivateFault';Message='password'}
            $r=Get-SiteResult;$r.Run.StopReason | Should Be 'UnexpectedFailure';$r.Errors[0].Stage | Should Be 'Policy'
            Mock Get-PSWCStartPolicy {throw 'password raw policy'}
            $r=Get-SiteResult;$r.Run.StopReason | Should Be 'UnexpectedFailure';$r.Pages.Count | Should Be 0
            $script:siteFetches | Should Be 0
        }
        It '26 HttpError preserves known facts nulls and sanitized diagnostics' {
            $script:siteStatus=503;$script:siteHtml='password body';$script:siteType='text/plain; charset=utf-8';$r=Get-SiteResult
            $r.Run.Status | Should Be 'Failed';$r.Run.StopReason | Should Be 'HttpError';$r.Pages[0].HttpStatus | Should Be 503
            $r.Pages[0].FinalUrl | Should Be 'https://site.test/';$r.Pages[0].ContentType | Should Be 'text/plain';$r.Pages[0].FetchedAtUtc | Should Be $script:siteStamp
            ($null -eq $r.Pages[0].Extraction) | Should Be $true;$r.Pages[0].Status | Should Be 'Failed'
            $r.Errors[0].Message | Should Be 'The page request returned an unsuccessful HTTP status.'
            $script:siteFinal=$null;$script:siteType=$null;$script:siteStatus=$null;$script:siteStamp=$null
            $script:siteError=[pscustomobject]@{Stage='Fetch';Code='HttpError';Message='password C:\secret'};$r=Get-SiteResult
            foreach($name in 'FinalUrl','HttpStatus','ContentType','FetchedAtUtc','Extraction'){($null -eq $r.Pages[0].$name) | Should Be $true}
            $r.Pages[0].RequestedUrl | Should Be 'https://site.test/';$r.Pages[0].Depth | Should Be 0
            foreach($code in 'NetworkTargetDenied','DnsFailure','RobotsDenied','RobotsFetchFailed','RobotsInvalid','HttpError','Timeout','ResponseTooLarge','RedirectLimit','RedirectOutsideScope','ParseError','UnexpectedFailure','UnsupportedContentEncoding','HeaderLimitExceeded'){
                $e=New-PSWCError -Stage Fetch -Url 'https://site.test/?secret=x' -Code $code
                $e.Code | Should Be $code;($e.Message.Length -le 512) | Should Be $true;$e.Message | Should Not Match 'secret|password|C:\\';$e.Url | Should Be 'https://site.test/?secret=x'
            }
        }
        It '27 Timeout and private fetch exceptions reserve one attempt no retry' {
            $script:siteError=[pscustomobject]@{Stage='Fetch';Code='Timeout'};$r=Get-SiteResult
            $r.Run.Status | Should Be 'Failed';$r.Run.StopReason | Should Be 'Timeout';$r.Errors[0].Stage | Should Be 'Fetch'
            $r.Pages.Count | Should Be 1;$script:siteFetches | Should Be 1
            $script:siteError=[pscustomobject]@{Stage='Resolve';Code='DnsFailure'};(Get-SiteResult).Errors[0].Stage | Should Be 'Resolve'
            $script:siteError=[pscustomobject]@{Stage='Parse';Code='UnknownPrivateFault';Message='password'}
            $r=Get-SiteResult;$r.Run.StopReason | Should Be 'UnexpectedFailure';$r.Errors[0].Stage | Should Be 'Fetch'
            Mock Invoke-PSWCFetchPage {throw 'password C:\secret raw body'};$r=Get-SiteResult
            $r.Run.StopReason | Should Be 'UnexpectedFailure';$r.Errors[0].Stage | Should Be 'Fetch'
            $r.Errors[0].Message | Should Be 'The crawl could not continue.';($null -eq $r.Pages[0].FetchedAtUtc) | Should Be $true
        }
        It '28 media types and injected analyzer faults have Parse ownership' {
            foreach($type in 'TEXT/HTML; charset=UTF-8',' Application/XHTML+XML ; charset=utf-8'){$script:siteType=$type;(Get-SiteResult).Run.Status | Should Be 'Completed'}
            foreach($type in @($null,'','text/plain','broken token','application/json')){
                $script:siteType=$type;$r=Get-SiteResult;$r.Run.Status | Should Be 'Failed';$r.Run.StopReason | Should Be 'ParseError'
                $r.Errors[0].Stage | Should Be 'Parse';$r.Pages[0].HttpStatus | Should Be 200;$r.Pages[0].Status | Should Be 'Failed'
                ($null -eq $r.Pages[0].Extraction) | Should Be $true;$r.Errors[0].Message | Should Be 'The page content could not be analyzed.'
            }
            $script:siteType='text/html';$script:siteAnalyzerFault=New-Object FormatException 'secret parser data';$r=Get-SiteResult
            $r.Run.StopReason | Should Be 'ParseError';$r.Errors[0].Stage | Should Be 'Parse'
            Assert-MockCalled Get-PSWCPageAnalysis -Times 1 -Exactly -Scope It
            $script:siteAnalyzerFault='password C:\secret';$r=Get-SiteResult
            $r.Run.StopReason | Should Be 'UnexpectedFailure';$r.Errors[0].Stage | Should Be 'Parse';$r.Errors[0].Message | Should Be 'The crawl could not continue.'
            $script:siteAnalyzerFault=$null;(Get-SiteResult).Run.Status | Should Be 'Completed'
            Assert-MockCalled Get-PSWCPageAnalysis -Times 2 -Exactly -Scope It
        }
        It '29 runs have distinct identifiers arrays and relations' {
            $script:siteHtml='<a href="https://site.test/a">a</a>';$one=Get-SiteResult;$script:siteHtml='';$two=Get-SiteResult
            ($one.Run.RunId -ne $two.Run.RunId) | Should Be $true;$two.Links.Count | Should Be 0;$one.Links.Count | Should Be 1
            [object]::ReferenceEquals($one.Pages,$two.Pages) | Should Be $false
            [object]::ReferenceEquals($one.Errors,$two.Errors) | Should Be $false;$script:siteFetches | Should Be 2
        }
        It '30 exact page budget without eligible work is Completed' {
            $script:siteHtml='<a href="https://site.test/a">a</a>';$r=Get-SiteResult @{MaxPages=1}
            $r.Run.Status | Should Be 'Completed';($null -eq $r.Run.StopReason) | Should Be $true;$r.Pages.Count | Should Be 1;$script:siteFetches | Should Be 1
        }
        It '31 only remaining distinct relations exhaust MaxLinks' {
            $script:siteHtml='<title>kept</title><a href="https://site.test/a">a</a><a href="https://site.test/a#x">repeat</a>'
            $r=Get-SiteResult @{MaxLinks=1};$r.Run.Status | Should Be 'Completed';$script:siteHtml+='<a href="https://other.test/b">b</a>'
            $r=Get-SiteResult @{MaxLinks=1};$r.Run.Status | Should Be 'Partial';$r.Run.StopReason | Should Be 'LinkLimit'
            $r.Links.Count | Should Be 1;$r.Pages[0].Extraction.Title | Should Be 'kept';$r.Errors.Count | Should Be 0
        }
        It '32 fresh import boundary-only invocation emits entirely valid JSON' {
            $body=@'
$m=Get-Module PSWebCrawler
& $m {
    $script:childCapabilities=0;$script:childPolicies=0;$script:childFetches=0
    function script:Get-PSWCFrameworkRelease {528040}
    function script:Test-PSWCCapability {$script:childCapabilities++;$true}
    function script:Get-PSWCStartPolicy {param($Uri,$Parameters) $script:childPolicies++;[pscustomobject]@{Allowed=$true;Code=$null}}
    function script:Invoke-PSWCFetchPage {
        param($Uri,$Parameters)
        $script:childFetches++
        if($Uri.AbsoluteUri -ne 'https://site.test/'){throw 'Unexpected fetch'}
        [pscustomobject]@{RequestedUrl=$Uri.AbsoluteUri;FinalUrl=$Uri.AbsoluteUri;HttpStatus=200;ContentType='text/html';Content='<title>child</title>';FetchedAtUtc='2026-10-28T12:00:00.0000000Z';Error=$null}
    }
}
$output=@(Invoke-PSWebCrawler -Mode Site -Url https://site.test/ -Depth 0)
if($output.Count -ne 1){throw 'Expected one result'}
& $m {if($script:childCapabilities -ne 1 -or $script:childPolicies -ne 1 -or $script:childFetches -ne 1){throw 'Boundary counts failed'}}
$output[0] | ConvertTo-Json -Depth 20 -Compress
'@
            $c=Invoke-SiteChild $body;$c.Exit | Should Be 0;$c.Err | Should Be '';$c.Gone | Should Be $true
            $r=$c.Out | ConvertFrom-Json;$r.Run.Status | Should Be 'Completed';$r.Pages[0].Extraction.Title | Should Be 'child';Assert-SiteArrays $r
            $c.Out.Trim() | Should Be ($r | ConvertTo-Json -Depth 20 -Compress)
        }
    }
    Describe 'S3 exact 14-case URI extraction contract' {
        BeforeEach {
            $script:s3Fetches=0;$script:s3Expected=1;$script:s3Policies=0;$script:s3Capabilities=0
            $script:s3Start='https://site.test/';$script:s3Final=$script:s3Start;$script:s3Html=''
            $script:s3Status=200;$script:s3Type='text/html';$script:s3Error=$null;$script:s3RejectAnalysis=$false
            # Reset the conditional mock: Pester 3.4 retains blocks until Describe exits.
            Mock Get-PSWCPageAnalysis {throw 'Rejected final reached analysis'} -ParameterFilter {$script:s3RejectAnalysis}
            Mock Get-PSWCFrameworkRelease {528040}
            Mock Test-PSWCCapability {$script:s3Capabilities++;$true}
            Mock Get-PSWCStartPolicy {$script:s3Policies++;[pscustomobject]@{Allowed=$true;Code=$null}}
            Mock Invoke-PSWCFetchPage {
                $script:s3Fetches++
                if($Uri.AbsoluteUri -cne (Resolve-PSWCCanonicalUri -Url $script:s3Start).AbsoluteUri){throw 'Unexpected target fetch'}
                [pscustomobject]@{RequestedUrl=$Uri.AbsoluteUri;FinalUrl=$script:s3Final;HttpStatus=$script:s3Status;ContentType=$script:s3Type;Content=$script:s3Html;FetchedAtUtc='2026-10-28T12:00:00.0000000Z';Error=$script:s3Error}
            }
        }
        AfterEach {
            $script:s3Fetches | Should Be $script:s3Expected;$script:s3Policies | Should Be $script:s3Expected
            $script:s3Capabilities | Should Be $script:s3Expected
            Assert-MockCalled Invoke-PSWCFetchPage -Times $script:s3Expected -Exactly -Scope It
        }
        It 'S3-01 absolute root parent plain and protocol relative links and images' {
            $script:s3Final='https://site.test/dir/page'
            $script:s3Html='<a href="https://SITE.TEST/abs">a</a><a href="/root">r</a><a href="../up">u</a><a href="leaf">l</a><a href="//SITE.TEST/proto">p</a><img src="https://SITE.TEST/abs.png"><img src="/root.png"><img src="../up.png"><img src="leaf.png"><img src="//SITE.TEST/proto.png">'
            $r=Get-SiteResult;$r.Run.Status | Should Be 'Completed';$r.Errors.Count | Should Be 0
            ($r.Links.TargetUrl -join '|') | Should Be 'https://site.test/abs|https://site.test/root|https://site.test/up|https://site.test/dir/leaf|https://site.test/proto'
            ($r.Pages[0].Extraction.ImageUrls -join '|') | Should Be 'https://site.test/abs.png|https://site.test/root.png|https://site.test/up.png|https://site.test/dir/leaf.png|https://site.test/proto.png'
            foreach($l in $r.Links){$l.Relation | Should Be 'SameHost';$l.Admission | Should Be 'DepthLimit'}
        }
        It 'S3-02 changed final path resolves targets and owns provenance' {
            $script:s3Final='https://SITE.TEST/new/landing?q=1#discard'
            $script:s3Html='<title>final</title><meta name="n" content="v"><img src="pic"><a href="next">n</a><a href="mailto:a@x.test">m</a>'
            $r=Get-SiteResult;$p=$r.Pages[0];$p.RequestedUrl | Should Be 'https://site.test/'
            $p.FinalUrl | Should Be 'https://site.test/new/landing?q=1';$r.Run.StartUrl | Should Be 'https://site.test/'
            $r.Links[0].TargetUrl | Should Be 'https://site.test/new/next';$p.Extraction.ImageUrls[0] | Should Be 'https://site.test/new/pic'
            foreach($v in $r.Links[0],$p.Extraction.Metadata[0],$p.Extraction.ContactCandidates[0]){$v.SourceUrl | Should Be $p.FinalUrl}
            $r.Errors.Count | Should Be 0
        }
        It 'S3-03 first valid base wins and invalid-only bases fall back without Error' {
            $script:s3Expected=3;$script:s3Final='https://site.test/dir/page'
            $script:s3Html='<base href="javascript:no"><base href="/assets/"><base href="/later/"><a href="leaf">l</a><img src="pic">'
            $r=Get-SiteResult;$r.Links[0].TargetUrl | Should Be 'https://site.test/assets/leaf';$r.Pages[0].Extraction.ImageUrls[0] | Should Be 'https://site.test/assets/pic'
            $r.Errors.Count | Should Be 0;$r.Links[0].SourceUrl | Should Be $script:s3Final
            $script:s3Html='<base><base href=""><base href="ftp://other.test/"><base href="bad\path"><a href="leaf">l</a>'
            $r=Get-SiteResult;$r.Links[0].TargetUrl | Should Be 'https://site.test/dir/leaf';$r.Run.Status | Should Be 'Completed';$r.Errors.Count | Should Be 0
            $script:s3Html='<base href="../valid/"><base href="https://other.test/"><a href="leaf">l</a>'
            $r=Get-SiteResult;$r.Links[0].TargetUrl | Should Be 'https://site.test/valid/leaf';$r.Errors.Count | Should Be 0
        }
        It 'S3-04 foreign base cannot expand Start host scope and images are URLs only' {
            $script:s3Final='https://site.test/dir/page';$script:s3Html='<base href="https://other.test/assets/"><a href="leaf">o</a><a href="https://SITE.TEST/own">s</a><img src="pic">'
            $r=Get-SiteResult;$r.Links.Count | Should Be 2;$r.Links[0].TargetUrl | Should Be 'https://other.test/assets/leaf'
            $r.Links[0].Relation | Should Be 'ExternalHost';$r.Links[0].Admission | Should Be 'OutsideScope'
            $r.Links[1].Relation | Should Be 'SameHost';$r.Links[1].Admission | Should Be 'DepthLimit'
            $r.Pages[0].Extraction.ImageUrls[0] | Should Be 'https://other.test/assets/pic'
            foreach($l in $r.Links){$l.SourceUrl | Should Be $script:s3Final};$r.Run.Status | Should Be 'Completed'
        }
        It 'S3-05 fragment query references dedup and absent or empty attributes' {
            $script:s3Final='https://site.test/dir/page?old=1'
            $script:s3Html='<a>none</a><a href="">empty</a><a href="#one">f</a><a href="#two">f</a><a href="?q=1#one">q</a><a href="?q=1#two">q</a><a href="?q=2">q</a><img><img src=""><img src="#one"><img src="#two"><img src="?q=1">'
            $r=Get-SiteResult;($r.Links.TargetUrl -join '|') | Should Be 'https://site.test/dir/page?old=1|https://site.test/dir/page?q=1|https://site.test/dir/page?q=2'
            ($r.Pages[0].Extraction.ImageUrls -join '|') | Should Be 'https://site.test/dir/page?old=1|https://site.test/dir/page?q=1'
            $r.Errors.Count | Should Be 0
        }
        It 'S3-06 query order duplicates encoding and path case retain ordinal identity' {
            $paths=@('p?a=1&b=2','p?b=2&a=1','p?x=1&x=2','p?x=2&x=1','p?q=+','p?q=%20','p?q=%2B','p?q=%26','p?q=%3D','p?q=%252F','Case','case')
            $script:s3Html=($paths | ForEach-Object {$h=$_.Replace('&','&amp;');'<a href="/'+$h+'">x</a><img src="/'+$h+'">'}) -join ''
            $r=Get-SiteResult;$expected=($paths | ForEach-Object {'https://site.test/'+$_}) -join '|'
            $r.Links.Count | Should Be 12;$r.Pages[0].Extraction.ImageUrls.Count | Should Be 12
            (($r.Links.TargetUrl -join '|') -ceq $expected) | Should Be $true
            (($r.Pages[0].Extraction.ImageUrls -join '|') -ceq $expected) | Should Be $true;$r.Errors.Count | Should Be 0
        }
        It 'S3-07 malformed percent start rejects discovery skips base invalid and percent25 survives' {
            foreach($bad in '%','%2','%GG'){
                Assert-SiteError @{Url=('https://site.test/'+$bad);Mode='Site';Depth=0}
                Assert-SiteError @{Url=('https://site.test/?q='+$bad);Mode='Site';Depth=0}
            }
            $script:s3Capabilities | Should Be 0;$script:s3Policies | Should Be 0;$script:s3Fetches | Should Be 0
            $script:s3Html='<base href="/bad%/"><base href="/ok/"><a href="%">x</a><a href="%2">x</a><a href="%GG">x</a><a href="?q=%GG">x</a><a href="%25">v</a><img src="%"><img src="%2"><img src="%GG"><img src="%25">'
            $r=Get-SiteResult;$r.Links.Count | Should Be 1;$r.Links[0].TargetUrl | Should Be 'https://site.test/ok/%25'
            ($r.Pages[0].Extraction.ImageUrls -join '|') | Should Be 'https://site.test/ok/%25';$r.Errors.Count | Should Be 0
        }
        It 'S3-08 Unicode IDN punycode and host case canonicalize without DNS' {
            $hostName='b'+[char]0x00FC+'cher.test';$script:s3Start='https://'+$hostName+'/';$script:s3Final='https://XN--BCHER-KVA.TEST/dir/page'
            $script:s3Html='<base href="https://other.test/"><a href="https://'+$hostName+'/u">u</a><a href="https://XN--BCHER-KVA.TEST/u#f">d</a><a href="https://xn--bcher-kva.test/P">p</a><a href="leaf">o</a><img src="https://'+$hostName+'/i">'
            $r=Get-SiteResult @{Url=$script:s3Start};$r.Run.StartUrl | Should Be 'https://xn--bcher-kva.test/'
            $r.Pages[0].FinalUrl | Should Be 'https://xn--bcher-kva.test/dir/page';$r.Links.Count | Should Be 3
            ($r.Links.TargetUrl -join '|') | Should Be 'https://xn--bcher-kva.test/u|https://xn--bcher-kva.test/P|https://other.test/leaf'
            foreach($l in $r.Links[0..1]){$l.TargetHost | Should Be 'xn--bcher-kva.test';$l.Relation | Should Be 'SameHost';$l.Admission | Should Be 'DepthLimit'}
            $r.Links[2].Relation | Should Be 'ExternalHost';$r.Links[2].Admission | Should Be 'OutsideScope'
            $r.Pages[0].Extraction.ImageUrls[0] | Should Be 'https://xn--bcher-kva.test/i'
        }
        It 'S3-09 default ports dedup but nondefault ports distinguish URI on same host' {
            $script:s3Html='<a href="http://SITE.TEST:80/p">a</a><a href="http://site.test/p">d</a><a href="https://site.test:443/p">a</a><a href="https://site.test/p">d</a><a href="http://site.test:8080/p">n</a><a href="https://site.test:8443/p">n</a><img src="http://site.test:80/i"><img src="http://site.test/i"><img src="https://site.test:443/i"><img src="https://site.test/i"><img src="https://site.test:8443/i">'
            $r=Get-SiteResult;($r.Links.TargetUrl -join '|') | Should Be 'http://site.test/p|https://site.test/p|http://site.test:8080/p|https://site.test:8443/p'
            ($r.Pages[0].Extraction.ImageUrls -join '|') | Should Be 'http://site.test/i|https://site.test/i|https://site.test:8443/i'
            foreach($l in $r.Links){$l.Relation | Should Be 'SameHost';$l.Admission | Should Be 'DepthLimit'}
            $r.Errors.Count | Should Be 0
        }
        It 'S3-10 excluded schemes userinfo controls backslash leave empty extraction arrays' {
            $bad=@('ftp://site.test/p','file:///p','javascript:alert(1)','data:image/x','https://u:p@site.test/p','bad\path',('bad'+[char]1+'path'))
            foreach($url in $bad){($null -eq (Resolve-PSWCCanonicalUri -Url $url -BaseUri ([uri]'https://site.test/'))) | Should Be $true}
            $script:s3Html=($bad | ForEach-Object {'<a href="'+$_+'">x</a><img src="'+$_+'">'}) -join ''
            $r=Get-SiteResult;$r.Run.Status | Should Be 'Completed';$r.Errors.Count | Should Be 0;$r.Links.Count | Should Be 0
            ($null -eq $r.Pages[0].Extraction.Title) | Should Be $true
            foreach($n in 'Metadata','ImageUrls','ContactCandidates'){$r.Pages[0].Extraction.$n.Count | Should Be 0};Assert-SiteArrays $r
        }
        It 'S3-11 foreign final rejects before analysis preserves facts and fetch non2xx precedence' {
            $script:s3Expected=4;$script:s3RejectAnalysis=$true;$script:s3Final='https://OTHER.TEST/landing?q=1#f'
            $script:s3Html='<title>forbidden</title><a href="https://site.test/leak">l</a><img src="https://site.test/leak.png">'
            foreach($type in 'text/html','text/plain'){
                $before=$script:s3Fetches
                $script:s3Type=$type;$r=Get-SiteResult;$p=$r.Pages[0];$r.Run.Status | Should Be 'Failed';$r.Run.StopReason | Should Be 'RedirectOutsideScope'
                $script:s3Fetches | Should Be ($before+1)
                $r.Errors.Count | Should Be 1;$r.Errors[0].Stage | Should Be 'Policy';$r.Errors[0].Code | Should Be 'RedirectOutsideScope';$r.Errors[0].Url | Should Be 'https://site.test/'
                $r.Errors[0].Message | Should Be 'The page redirect left the admitted scope.';$p.Status | Should Be 'Failed';($null -eq $p.Extraction) | Should Be $true
                $r.Pages.Count | Should Be 1;$p.RequestedUrl | Should Be 'https://site.test/';$p.Depth | Should Be 0;$p.FinalUrl | Should Be 'https://other.test/landing?q=1'
                $p.HttpStatus | Should Be 200;$p.ContentType | Should Be $type;$p.FetchedAtUtc | Should Be '2026-10-28T12:00:00.0000000Z';$r.Links.Count | Should Be 0
            }
            $script:s3Error=[pscustomobject]@{Stage='Fetch';Code='Timeout'};$r=Get-SiteResult;$r.Run.StopReason | Should Be 'Timeout';$r.Errors[0].Stage | Should Be 'Fetch'
            ($null -eq $r.Pages[0].Extraction) | Should Be $true;$r.Links.Count | Should Be 0
            $script:s3Error=$null;$script:s3Status=503;$r=Get-SiteResult;$r.Run.StopReason | Should Be 'HttpError';$r.Errors[0].Stage | Should Be 'Fetch'
            $r.Pages[0].HttpStatus | Should Be 503;($null -eq $r.Pages[0].Extraction) | Should Be $true;$r.Links.Count | Should Be 0
            Assert-MockCalled Get-PSWCPageAnalysis -Times 0 -Exactly -Scope It
        }
        It 'S3-12 real HAP repairs unclosed HTML while preserving title and metadata semantics' {
            $script:s3Html='<title> A &amp; B </title><title>second</title><meta name=" n " content=" v&amp;x "><meta name="n" content="v&amp;x"><meta name="empty" content=""><meta name="missing"><meta property="og:title" content="excluded"><div><p>unclosed<b>text<a href="leaf">link<img src="pic">'
            $r=Get-SiteResult;$e=$r.Pages[0].Extraction;$r.Run.Status | Should Be 'Completed';$r.Errors.Count | Should Be 0;$e.Title | Should Be 'A & B'
            $e.Metadata.Count | Should Be 3;($e.Metadata.Name -join '|') | Should Be 'n|n|empty';($e.Metadata.Value -join '|') | Should Be 'v&x|v&x|'
            foreach($m in $e.Metadata){$m.SourceUrl | Should Be 'https://site.test/'}
            $r.Links[0].TargetUrl | Should Be 'https://site.test/leaf';$e.ImageUrls[0] | Should Be 'https://site.test/pic';Assert-SiteArrays $r
        }
        It 'S3-13 images and contacts use final provenance base resolution and decode once' {
            $script:s3Final='https://site.test/final/page';$script:s3Html='<base href="../assets/"><img src="p?q=+&amp;x=%252F#one"><img src="p?q=+&amp;x=%252F#two"><img src="p?q=%20&amp;x=%252F"><a href="MAILTO:a%2Bb%40x.test,c%40x.test?subject=ignored&amp;x=1">m</a><a href="mailto:a%2Bb%40x.test">d</a><a href="mailto:%252B@x.test">o</a><a href="tel:%2B48123;ext=4">t</a><a href="tel:%2B48123;ext=4">d</a><a href="mailto:">e</a><p>guess@x.test</p>'
            $r=Get-SiteResult;$e=$r.Pages[0].Extraction
            ($e.ImageUrls -join '|') | Should Be 'https://site.test/assets/p?q=+&x=%252F|https://site.test/assets/p?q=%20&x=%252F'
            $e.ContactCandidates.Count | Should Be 4;($e.ContactCandidates.Kind -join '|') | Should Be 'Email|Email|Email|Phone'
            ($e.ContactCandidates.Value -join '|') | Should Be 'a+b@x.test|c@x.test|%2B@x.test|+48123;ext=4'
            foreach($c in $e.ContactCandidates){$c.SourceUrl | Should Be $script:s3Final};$r.Links.Count | Should Be 0;$r.Errors.Count | Should Be 0
        }
        It 'S3-14 ordered repeat runs isolate data and preserve JSON arrays and nulls' {
            $script:s3Expected=3;$script:s3Final='https://site.test/d/page';$script:s3Html='<base href="../a/"><meta name="n" content="v"><meta name="n" content="v"><img src="i"><img src="I"><a href="x">x</a><a href="https://other.test/y">y</a><a href="mailto:a@x.test">m</a>'
            $one=Get-SiteResult;$two=Get-SiteResult
            ($one.Pages | ConvertTo-Json -Depth 20 -Compress) | Should Be ($two.Pages | ConvertTo-Json -Depth 20 -Compress)
            ($one.Links | ConvertTo-Json -Depth 20 -Compress) | Should Be ($two.Links | ConvertTo-Json -Depth 20 -Compress)
            ($one.Run.RunId -ne $two.Run.RunId) | Should Be $true
            [object]::ReferenceEquals($one.Pages,$two.Pages) | Should Be $false;[object]::ReferenceEquals($one.Pages[0].Extraction.Metadata,$two.Pages[0].Extraction.Metadata) | Should Be $false
            $two.Pages[0].Extraction.Metadata[0].Value='mutated';$one.Pages[0].Extraction.Metadata[0].Value | Should Be 'v'
            $j=$one | ConvertTo-Json -Depth 20 | ConvertFrom-Json;Assert-SiteArrays $one;Assert-SiteArrays $j
            $j.Pages.Count | Should Be 1;$j.Links.Count | Should Be 2;$j.Errors.Count | Should Be 0
            $j.Pages[0].Extraction.Metadata.Count | Should Be 2;$j.Pages[0].Extraction.ImageUrls.Count | Should Be 2;$j.Pages[0].Extraction.ContactCandidates.Count | Should Be 1
            ($null -eq $j.Pages[0].Extraction.Title) | Should Be $true;($null -eq $j.Run.StopReason) | Should Be $true;($null -eq $j.Run.Parameters.MaxHosts) | Should Be $true
            ($j | ConvertTo-Json -Depth 20 -Compress) | Should Be ($one | ConvertTo-Json -Depth 20 -Compress)
            $script:s3Html='';$empty=Get-SiteResult | ConvertTo-Json -Depth 20 | ConvertFrom-Json;Assert-SiteArrays $empty
            $empty.Links.Count | Should Be 0;foreach($n in 'Metadata','ImageUrls','ContactCandidates'){$empty.Pages[0].Extraction.$n.Count | Should Be 0}
            ($null -eq $empty.Pages[0].Extraction.Title) | Should Be $true;$one.Links.Count | Should Be 2
        }
    }
}
