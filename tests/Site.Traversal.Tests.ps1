# S4 offline orchestration; fakes return page facts, never public results.
$ProgressPreference='SilentlyContinue'
Import-Module (Join-Path (Split-Path $PSScriptRoot -Parent) 'PSWebCrawler\PSWebCrawler.psd1') -ErrorAction Stop
InModuleScope PSWebCrawler {
    function Add-TraversalPage {
        param([string]$Path,[string]$Html='',[string]$Final='',[int]$Status=200,[string]$Type='text/html',$Error=$null)
        $url='https://site.test'+$Path;if(-not $Final){$Final=$url}
        $script:fixtures[$url]=[pscustomobject]@{RequestedUrl=$url;FinalUrl=$Final;HttpStatus=$Status;ContentType=$Type;Content=$Html;FetchedAtUtc='2026-10-29T12:00:00.0000000Z';Error=$Error}
    }
    function Get-Traversal {
        param([hashtable]$Options=@{})
        $a=@{Url='https://site.test/';Mode='Site';Depth=2}
        foreach($k in $Options.Keys){$a[$k]=$Options[$k]}
        Invoke-PSWebCrawler @a
    }
    function Assert-Trace {
        param([string]$Paths)
        (($script:fetchTrace | ForEach-Object {([uri]$_).PathAndQuery}) -join ',') | Should Be $Paths
        ($script:policyTrace -join ',') | Should Be ($script:expectedPolicies -join ',')
    }
    function Assert-Arrays {
        param($r)
        foreach($k in 'Pages','Links','Errors'){($r.$k -is [array]) | Should Be $true}
        foreach($p in $r.Pages){if($p.Extraction){foreach($k in 'Metadata','ImageUrls','ContactCandidates'){($p.Extraction.$k -is [array]) | Should Be $true}}}
    }
    Describe 'S4 exact 16-case Site traversal contract' {
        BeforeEach {
            $script:fixtures=@{};$script:denials=@{};$script:fetchTrace=@();$script:policyTrace=@();$script:events=@()
            $script:expectedPolicies=@();$script:clock=0.0;$script:policyAdvance=0.0;$script:fetchAdvance=0.0;$script:parseFault=$null
            Mock Get-PSWCFrameworkRelease {528040}
            Mock Test-PSWCCapability {$true}
            if(Get-Command Get-PSWCMonotonicSeconds -ErrorAction SilentlyContinue){Mock Get-PSWCMonotonicSeconds {$script:clock}}
            Mock Get-PSWCStartPolicy {
                $u=$Uri.AbsoluteUri;$script:policyTrace+=$u;$script:events+='P:'+ $u;$script:clock+=$script:policyAdvance
                if(-not $script:fixtures.ContainsKey($u) -and -not $script:denials.ContainsKey($u)){throw 'Unexpected policy target'}
                if($script:denials.ContainsKey($u)){return [pscustomobject]@{Allowed=$false;Code=$script:denials[$u]}}
                [pscustomobject]@{Allowed=$true;Code=$null}
            }
            Mock Invoke-PSWCFetchPage {
                $u=$Uri.AbsoluteUri;$script:fetchTrace+=$u;$script:events+='F:'+ $u;$script:clock+=$script:fetchAdvance
                if(-not $script:fixtures.ContainsKey($u)){throw 'Unexpected fetch target'}
                $script:fixtures[$u]
            }
            Mock Get-PSWCPageAnalysis {throw [FormatException]::new('fixture')} -ParameterFilter {$FinalUri.AbsolutePath -eq $script:parseFault}
            Add-TraversalPage '/' '<a href="/a">a</a><a href="/b">b</a>'
            Add-TraversalPage '/a' '<a href="/c">c</a>'
            Add-TraversalPage '/b' '<a href="/d">d</a>'
            Add-TraversalPage '/c';Add-TraversalPage '/d'
        }
        It 'S4-01 Depth0 start only' {
            $r=Get-Traversal @{Depth=0};$script:expectedPolicies=@('https://site.test/');Assert-Trace '/'
            $r.Pages.Count | Should Be 1;($r.Links.Admission -join ',') | Should Be 'DepthLimit,DepthLimit';$r.Run.Status | Should Be 'Completed'
        }
        It 'S4-02 Depth1 direct neighbors' {
            $r=Get-Traversal @{Depth=1};$script:expectedPolicies=@('https://site.test/','https://site.test/a','https://site.test/b');Assert-Trace '/,/a,/b'
            ($r.Pages.Depth -join ',') | Should Be '0,1,1';($r.Links.Admission -join ',') | Should Be 'Eligible,Eligible,DepthLimit,DepthLimit'
            ($script:events -join ',') | Should Be 'P:https://site.test/,F:https://site.test/,P:https://site.test/a,F:https://site.test/a,P:https://site.test/b,F:https://site.test/b'
        }
        It 'S4-03 Depth2 FIFO level order' {
            $r=Get-Traversal;$script:expectedPolicies=@('https://site.test/','https://site.test/a','https://site.test/b','https://site.test/c','https://site.test/d');Assert-Trace '/,/a,/b,/c,/d'
            ($r.Pages.Depth -join ',') | Should Be '0,1,1,2,2';$r.Run.Status | Should Be 'Completed';$r.Errors.Count | Should Be 0
        }
        It 'S4-04 foreign and subdomain excluded' {
            Add-TraversalPage '/' '<a href="https://other.test/x">x</a><a href="https://sub.site.test/x">s</a><a href="/a">a</a>'
            $r=Get-Traversal @{Depth=1};($script:fetchTrace -join ',') | Should Be 'https://site.test/,https://site.test/a'
            ($r.Links.Admission -join ',') | Should Be 'OutsideScope,OutsideScope,Eligible,DepthLimit';$r.Run.Status | Should Be 'Completed'
        }
        It 'S4-05 cycles and repeated anchors' {
            Add-TraversalPage '/' '<a href="/a">a</a><a href="/a#x">again</a>'
            Add-TraversalPage '/a' '<a href="/">home</a><a href="/a">self</a>'
            $r=Get-Traversal;$script:fetchTrace.Count | Should Be 2;$r.Links.Count | Should Be 3;$r.Run.Status | Should Be 'Completed'
        }
        It 'S4-06 query fragment path-case identity' {
            Add-TraversalPage '/' '<a href="/a?q=1#x">1</a><a href="/a?q=1#y">again</a><a href="/a?q=2">2</a><a href="/A">case</a>'
            Add-TraversalPage '/a?q=1';Add-TraversalPage '/a?q=2';Add-TraversalPage '/A'
            $r=Get-Traversal;$script:fetchTrace.Count | Should Be 4;($r.Pages.RequestedUrl -join ',') | Should Be 'https://site.test/,https://site.test/a?q=1,https://site.test/a?q=2,https://site.test/A'
        }
        It 'S4-07 multiple sources retain relations without refetch' {
            Add-TraversalPage '/b' '<a href="/c">c</a>'
            $r=Get-Traversal;$script:fetchTrace.Count | Should Be 4
            @($r.Links | Where-Object TargetUrl -eq 'https://site.test/c').Count | Should Be 2
            ($r.Links.SourceUrl -join ',') | Should Be 'https://site.test/,https://site.test/,https://site.test/a,https://site.test/b'
        }
        It 'S4-08 same host final and base provenance' {
            Add-TraversalPage '/' '<base href="/base/"><a href="child">c</a>' 'https://site.test/final/'
            Add-TraversalPage '/base/child'
            $r=Get-Traversal;$r.Pages[0].RequestedUrl | Should Be 'https://site.test/';$r.Pages[0].FinalUrl | Should Be 'https://site.test/final/'
            $r.Links[0].SourceUrl | Should Be 'https://site.test/final/';$script:fetchTrace[1] | Should Be 'https://site.test/base/child'
        }
        It 'S4-09 foreign final blocks analyzer expansion' {
            Add-TraversalPage '/a' '<a href="/forbidden">x</a>' 'https://other.test/final'
            $r=Get-Traversal @{Depth=1};$r.Run.Status | Should Be 'Partial';$r.Run.StopReason | Should Be 'Incomplete'
            $r.Pages[1].FinalUrl | Should Be 'https://other.test/final';($null -eq $r.Pages[1].Extraction) | Should Be $true
            $r.Errors[0].Code | Should Be 'RedirectOutsideScope';$script:fetchTrace.Count | Should Be 3;$r.Links.Count | Should Be 3
        }
        It 'S4-10 consecutive runs and mutation isolation' {
            $one=Get-Traversal @{Depth=1};$one.Pages[0].Extraction.Title='mutated';$one.Links[0].Admission='Blocked'
            $two=Get-Traversal @{Depth=1};($one.Run.RunId -ne $two.Run.RunId) | Should Be $true
            ($null -eq $two.Pages[0].Extraction.Title) | Should Be $true;$two.Links[0].Admission | Should Be 'Eligible';$two.Pages.Count | Should Be 3;$script:fetchTrace.Count | Should Be 6
        }
        It 'S4-11 MaxPages attempted exact versus omitted work' {
            $r=Get-Traversal @{Depth=1;MaxPages=3};$r.Run.Status | Should Be 'Completed'
            $script:fixtures['https://site.test/a'].Error=[pscustomobject]@{Stage='Fetch';Code='Timeout'}
            $r=Get-Traversal @{MaxPages=2};$r.Pages.Count | Should Be 2;$r.Pages[1].Status | Should Be 'Failed';$r.Run.Status | Should Be 'Partial';$r.Run.StopReason | Should Be 'PageLimit'
            $script:denials['https://site.test/a']='RobotsDenied';$r=Get-Traversal @{Depth=1;MaxPages=2};$r.Pages.Count | Should Be 2;$r.Run.Status | Should Be 'Completed'
        }
        It 'S4-12 global MaxLinks exact and cross-page overflow' {
            Add-TraversalPage '/a';Add-TraversalPage '/b'
            $r=Get-Traversal @{MaxLinks=2};$r.Links.Count | Should Be 2;$r.Run.Status | Should Be 'Completed'
            Add-TraversalPage '/a' '<a href="/c">c</a>'
            $r=Get-Traversal @{MaxLinks=2};$r.Links.Count | Should Be 2;$r.Run.Status | Should Be 'Partial';$r.Run.StopReason | Should Be 'LinkLimit'
            ($script:fetchTrace -contains 'https://site.test/c') | Should Be $false
        }
        It 'S4-13 monotonic deadline and stop precedence' {
            $script:fetchAdvance=1.0;$r=Get-Traversal @{MaxRunSeconds=1;MaxPages=1;MaxLinks=1}
            $r.Run.Status | Should Be 'Partial';$r.Run.StopReason | Should Be 'TimeLimit';$script:fetchTrace.Count | Should Be 1
            $script:clock=0;$script:fetchAdvance=0;$script:policyAdvance=1.0;$script:fetchTrace=@()
            $r=Get-Traversal @{MaxRunSeconds=1};$r.Run.Status | Should Be 'Failed';$r.Run.StopReason | Should Be 'TimeLimit';$script:fetchTrace.Count | Should Be 0
            $script:clock=0;$script:policyAdvance=0
            $r=Get-Traversal @{MaxPages=1;MaxLinks=1};$r.Run.StopReason | Should Be 'PageLimit'
            $r=Get-Traversal @{MaxLinks=1};$r.Run.StopReason | Should Be 'LinkLimit'
        }
        It 'S4-14 start versus later fetch and parse failures' {
            $script:fixtures['https://site.test/'].Error=[pscustomobject]@{Stage='Fetch';Code='Timeout'}
            $r=Get-Traversal;$r.Run.Status | Should Be 'Failed';$r.Run.StopReason | Should Be 'Timeout';$r.Pages.Count | Should Be 1
            $script:fixtures['https://site.test/'].Error=$null;$script:fixtures['https://site.test/a'].Error=[pscustomobject]@{Stage='Fetch';Code='Timeout'};$script:parseFault='/b'
            $r=Get-Traversal;$r.Run.Status | Should Be 'Partial';$r.Run.StopReason | Should Be 'Incomplete';($r.Errors.Code -join ',') | Should Be 'Timeout,ParseError'
            $r.Pages[1].HttpStatus | Should Be 200;$r.Pages[1].FetchedAtUtc | Should Be '2026-10-29T12:00:00.0000000Z';($null -eq $r.Pages[1].Extraction) | Should Be $true;$r.Pages.Count | Should Be 3
            $script:parseFault='/';$r=Get-Traversal;$r.Run.Status | Should Be 'Failed';$r.Run.StopReason | Should Be 'ParseError'
        }
        It 'S4-15 policy start later denial and robots omission' {
            $script:denials['https://site.test/']='RobotsDenied';$r=Get-Traversal;$r.Run.Status | Should Be 'Failed';$r.Pages.Count | Should Be 0;$script:fetchTrace.Count | Should Be 0
            $script:denials.Remove('https://site.test/');$script:denials['https://site.test/a']='NetworkTargetDenied'
            $r=Get-Traversal @{Depth=1};$r.Run.Status | Should Be 'Completed';$r.Links[0].Admission | Should Be 'Blocked';$r.Pages.Count | Should Be 2
            $script:denials['https://site.test/a']='RobotsFetchFailed';$r=Get-Traversal @{Depth=1};$r.Run.Status | Should Be 'Partial';$r.Run.StopReason | Should Be 'Incomplete';$r.Errors[0].Code | Should Be 'RobotsFetchFailed'
            $script:denials['https://site.test/a']='RobotsInvalid';$r=Get-Traversal @{Depth=1};$r.Run.Status | Should Be 'Partial'
        }
        It 'S4-16 one ordered result JSON arrays defaults and real fail closed' {
            foreach($d in 0,1,2){$o=@(Get-Traversal @{Depth=$d});$o.Count | Should Be 1;$r=$o[0];Assert-Arrays $r;Assert-Arrays ($r | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
                ($r.PSObject.Properties.Name -join ',') | Should Be 'Run,Pages,Links,Errors'
                ($r.Run.PSObject.Properties.Name -join ',') | Should Be 'SchemaVersion,RunId,Mode,StartUrl,StartedAtUtc,FinishedAtUtc,Parameters,Status,StopReason'
            }
            $r=Invoke-PSWebCrawler -Url https://site.test/ -Mode Site;$r.Run.Parameters.Depth | Should Be 1;$r.Pages.Count | Should Be 3
            $path=[IO.Path]::ChangeExtension($ExecutionContext.SessionState.Module.Path,'psd1').Replace("'","''")
            $code="`$ProgressPreference='SilentlyContinue';Import-Module '$path';try {Invoke-PSWebCrawler -Url https://site.test/ -Mode Site;exit 9} catch {[Console]::Out.Write(`$_.FullyQualifiedErrorId);exit 7}"
            $i=New-Object Diagnostics.ProcessStartInfo;$i.FileName=Join-Path $PSHOME 'powershell.exe';$i.Arguments='-NoProfile -NonInteractive -EncodedCommand '+[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code));$i.UseShellExecute=$false;$i.RedirectStandardOutput=$true;$i.RedirectStandardError=$true
            $p=New-Object Diagnostics.Process;$p.StartInfo=$i
            try {[void]$p.Start();$out=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync();if(-not $p.WaitForExit(20000)){$p.Kill();throw 'Child deadline'}
                $out.Wait(5000) | Should Be $true;$err.Wait(5000) | Should Be $true;$p.ExitCode | Should Be 7;$err.Result | Should Be '';$out.Result | Should Match '^CapabilityUnavailable,Invoke-PSWebCrawler';$p.HasExited | Should Be $true
            } finally {if(-not $p.HasExited){$p.Kill();[void]$p.WaitForExit(5000)};$p.Dispose()}
        }
    }
}
