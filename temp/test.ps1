if ($linkedDomain -ne $currentDomain -and -not $noCrawlExternalLinks) {
    Write-Log "[$currentDomain] is different then [$linkedDomain] and not [noCrawlExternalLinks]"
    #Write-Verbose "  processing '$hrefdomain'..."
    #$script:ArrayData.url.contains($hrefdomain)
    if (-not ($script:ArrayData.url.contains($hrefdomain))) {
        Write-Host "  [$depth] ['$url' - '$hrefdomain']"
        $thisobject = [PSCustomObject] @{
            Depth     = $depth
            Url       = $hrefDomain
            Domain    = ""
            Href      = ""
            UrlServer = ""
            Date      = (get-date)
        }
        $script:ArrayData += $thisobject
        Write-Log "Depth:[$depth] and url:[$hrefdomain] added to ArrayData"
    }

    # Decrease the depth when moving to a different site
    $newDepth = $depth - 1
    Write-Log "Newdepth is [$newDepth]"
    #Write-Verbose "  set new depth to $newDepth"
    
    # Add the link to the list of links to crawl
    $domains += $hrefDomain
    Write-Log "[$hrefDomain] added to [domains] list"
    #Write-Verbose "  add '$hrefDomain' to `$domains"
    #Write-Verbose " [recursive] Processing domain: $hrefDomain (Depth: $depth => $newDepth)"

    if (-not ($script:ArrayData.domain.contains($hrefdomain))) {
        $server = $response[1].Headers.Server -join "; "
        if ($server -eq "") {
            $server = "no data"
        }
        #$server_ = $server.count
        #write-host "[${server}]"
        $thisobject = [PSCustomObject] @{
            Depth     = $depth
            Url       = $url
            Domain    = $hrefDomain
            Href      = $href
            UrlServer = $server
            Date      = (get-date)
        }
        $script:ArrayData += $thisobject
        Write-Log "Depth:[$depth], url:[$url], domain:[$hrefDomain], href:[$href], server:[$server] added to ArrayData"
    }

    Write-Log "start new iteration for [$hrefDomain]"
    if ($depth -eq 0) {
        # immediately returns the program flow to the top of a program loop
        Write-Log "Depth is 0; skipping [$hrefDomain]"
        continue
    }

    Start-PSWCCrawl -url $hrefDomain -depth $newDepth -timeoutSec $timeoutSec -outputFolder $outputFolder -statusCodeVerbose:$statusCodeVerbose -noCrawlExternalLinks:$noCrawlExternalLinks -userAgent $userAgent -onlyDomains:$onlyDomains -verbose:$verbose -debug:$debug

}
else {
    $newDepth = $depth
    Write-Log "Newdepth is [$newDepth]"

    #Write-Verbose "  no change to depth - $newDepth"
}
