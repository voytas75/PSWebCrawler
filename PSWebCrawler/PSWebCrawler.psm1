function Get-PSWCBanner {
    param ()
    $banner = get-content -Path "${PSScriptRoot}\images\PSWCbanner.txt"
    Write-Output $banner
    return
}

function Get-PSWCAllElements {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$url,
        [string]$Node = "//a",
        [int]$timeoutSec = 10,
        [switch]$onlyDomains,
        [ValidateSet("Href", "noHref", "onlyDomains", "All")]
        [string]$Type = "All",
        [string]$userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36 Edg/117.0.2045.43"
    )
    begin {
        Write-verbose "Parameters and Default Values:" -Verbose
        foreach ($param in $MyInvocation.MyCommand.Parameters.keys) {
            $value = Get-Variable -Name $param -ValueOnly -ErrorAction SilentlyContinue
            if (-not $null -eq [string]$value) {
                Write-Verbose "${param}: [${value}]" -Verbose
            }
        }
        $domains = @()
        $hrefElements = @()
        $nonhrefElements = @()
    }
    process {
        #write-verbose "Get-PSWCAllElements" -Verbose
        if ($onlyDomains.IsPresent) {
            $url = Get-PSWCSchemeAndDomain -Url $url
        }
        # Send an HTTP GET request to the URL
        $response = Get-PSWCHttpResponse -url $url -userAgent $userAgent -timeout $timeoutSec
        Write-Log "Got response from [$url]"
        #Write-Log ($response | out-string)
        if ($response.IsSuccessStatusCode) {
            Write-Log "Response [$($response.StatusCode)] succeded from [$url] "
            #write-verbose "`$response.IsSuccessStatusCode for '$url': $($response.IsSuccessStatusCode)"
            $htmlContent = $response.Content.ReadAsStringAsync().Result
            #$responseHeaders = $response.Headers | ConvertTo-Json  # Capture response headers
            # Extract all anchor elements from the HTML document
            $anchorElements = Get-PSWCDocumentElements -htmlContent $htmlContent -Node $Node
            if ($anchorElements.count -gt 0) {
            
                # wykryte domeny w linkach
                foreach ($anchorElement in $anchorElements) {
                    $href = $anchorElement.GetAttributeValue("href", "")
                    # Remove mailto: links
                    $href = $href -replace "mailto:", ""
                    # Filter out non-HTTP links
                    if ($href -match "^https?://") {
                        $hrefElements += $href
                        $hrefDomain = Get-PSWCSchemeAndDomain -url $href
                        $linkedDomain = [System.Uri]::new($href).Host
                        if ($linkedDomain -ne $currentDomain) {
                            $domains += $hrefDomain
                        }
                    }
                    else {
                        $nonhrefelements += $href
                    }
                }
    
            } 
            else {
                Write-Host "No elemets in [$url]"    
                Write-Log "No elemets in [$url]"    
            }
        }
        else {
            Write-Host "HTTP request failed for URL: $url. Status code: $($response.StatusCode)"
        }
    }
    end {
        $domainsunique = $domains | Select-Object -Unique | Sort-Object
        $hrefsUnique = $hrefelements | Select-Object -Unique | Sort-Object
        $nonhrefsUnique = $nonhrefelements | Select-Object -Unique | Sort-Object
        switch ($Type) {
            "href" {
                Write-Host "Href elements, unique:"  
                $hrefelements | Select-Object -Unique | sort-object
            }
            "nohref" {
                Write-Host "no Href elements, unique:"  
                $nonhrefelements | Where-Object { $_ -notin ("", "/", "#") } | Select-Object -Unique | sort-object
            }
            "onlyDomains" {
                Write-Host "only Domains elements, unique:"  
                $domains | Select-Object -Unique | sort-object
            }
            "All" {
                Write-Host "All elements"
                Write-Host "only Domains elements, unique:"  
                $domains | Select-Object -Unique | sort-object
                Write-Host "Href elements, unique:"  
                $hrefelements | Select-Object -Unique | sort-object
                Write-Host "no Href elements, unique:"  
                $nonhrefelements | Where-Object { $_ -notin ("", "/", "#") } | Select-Object -Unique | sort-object
            }
            Default {}
        }
        Write-Log "Hrefs (w/o domains) count: [$($hrefelements.count)], unique: $(($hrefsUnique).count)"
        Write-Log "no-Hrefs (w/o domains) count: [$($nonhrefelements.count)], unique: $(($nonhrefsUnique).count)"
        Write-Log "Domain count: [$($domains.count)], unique: $(($domainsUnique).count)"
        
    }
}

# Function to crawl a URL
function Start-PSWCCrawl {
    [CmdletBinding()]
    param (
        [string]$url,
        [int]$depth,
        [int]$timeoutSec = 10,
        [string]$outputFolder,
        [switch]$statusCodeVerbose,
        [switch]$noCrawlExternalLinks,
        [switch]$onlyDomains,
        [string]$userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36 Edg/117.0.2045.43"
    )

    #$ArrayData | ft

    <#     Write-Verbose "Parameters and Default Values:"
    foreach ($param in $MyInvocation.MyCommand.Parameters.keys) {
        $value = Get-Variable -Name $param -ValueOnly -ErrorAction SilentlyContinue
        if (-not $null -eq [string]$value) {
            Write-Verbose "${param}: [${value}]"
        }
    }
 #>
    # Initialize the visitedUrls variable if it doesn't exist
    #$outputFolder = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "webcrawler"
    #if (-not (Test-Path -Path $outputFolder)) {
    #    [void](New-Item -Path $outputFolder -ItemType Directory)
    #}
    $outputFile = ""
    if ($outputFolder) { 
        $outputFile = join-path $outputFolder -ChildPath (Set-PSWCCleanWebsiteURL -url $url) 
    }
    
    if (-not $script:visitedUrls) {
        $script:visitedUrls = @{}
        Write-Log "Hashtable [visitedUrls] was initialized"
        #write-verbose 'create $script:visitedUrls'
    }

    if (-not $script:historyDomains) {
        $script:historyDomains = @()
        Write-Log "Array [historyDomains] was initialized"
        #write-verbose 'create $script:historyDomains'
    }
    #$script:historyDomains

    if ($onlyDomains.IsPresent) {
        $url = Get-PSWCSchemeAndDomain -url $url
        #write-verbose "create `$url as Get-PSWCSchemeAndDomain -url '$url'"
    }

    # If the URL has not already been visited, add it to the list of visited URLs and crawl it
    # sprawdzamy takze ddwiedzone domeny, zadziala nawet jak bedziemy uzywac url z query path
    #write-verbose "(-not `$visitedUrls.ContainsKey($url) -and -not ((Get-PSWCSchemeAndDomain -url $url) -in `$script:historydomains)): ($(-not $visitedUrls.ContainsKey($url) -and -not ((Get-PSWCSchemeAndDomain -url $url) -in $script:historydomains)))"
    #if (-not $visitedUrls.ContainsKey($url) -and -not ((Get-PSWCSchemeAndDomain -url $url) -in $script:historydomains)) {
    #    write-verbose "(-not `$visitedUrls.ContainsKey($url))): ($(-not $visitedUrls.ContainsKey($url))"
    #    if (-not $visitedUrls.ContainsKey($url)) {
    #write-verbose "(-not (`$url -in `$script:historydomains)): $(-not ($url -in $script:historydomains))"
    #if (-not ($url -in $script:historydomains)) {
    #write-verbose "`$script:ArrayData.url.Contains($url): $($script:ArrayData.url.Contains($url))"

    if ($script:ArrayData.url.Contains($url)) {
        #if (-not $visitedUrls.ContainsKey($url) -and -not ((Get-PSWCSchemeAndDomain -url $url) -in $script:historydomains)) {
        #$visitedUrls[$url] = $true
        Write-Log "[Arraydata] url contains [$url] "
        try {
            # Send an HTTP GET request to the URL
            $response = Get-PSWCHttpResponse -url $url -userAgent $userAgent -timeout $timeoutSec
            Write-Log "Got response from [$url] "
            #$response | ConvertTo-Json

            # Check if the request was successful
            if ($response.IsSuccessStatusCode) {
                Write-Log "Response succeded from [$url] "
                #write-verbose "`$response.IsSuccessStatusCode for '$url': $($response.IsSuccessStatusCode)"
                $htmlContent = $response.Content.ReadAsStringAsync().Result
                $responseHeaders = $response.Headers | ConvertTo-Json  # Capture response headers

                # Save the headers to a file if specified
                if ($outputFolder -ne "") {
                    #$headersFile = (Join-Path -Path $outputFolder -ChildPath $(Set-PSWCCleanWebsiteURL -Url $url)) + ".headers.json"
                    Set-Content -Path ([string]::Concat($outputFile, ".headers.json")) -Value $responseHeaders
                    Write-Log "Header for [$url] saved in [${outputFile}.headers.json]"
                    #write-verbose "Save the headers to a file for '$url' to '$headersFile'"
                }

                #write-verbose "Add '$url' to `$script:historyDomains"
                $script:historyDomains += $url
                Write-Log "Added [$url] to [historyDomains]"

                # Extract all anchor elements from the HTML document
                $anchorElements = Get-PSWCDocumentElements -htmlContent $htmlContent -Node "//a"
                Write-Log "Got all [a] anhors from [$url]"

                <# $anchorElements:
Attributes           : {href, class}
ChildNodes           : {#text}
Closed               : True
ClosingAttributes    : {}
EndNode              : HtmlAgilityPack.HtmlNode
FirstChild           : HtmlAgilityPack.HtmlTextNode
HasAttributes        : True
HasChildNodes        : True
HasClosingAttributes : False
Id                   :
InnerHtml            : Przejdź do menu głównego
InnerText            : Przejdź do menu głównego
LastChild            : HtmlAgilityPack.HtmlTextNode
Line                 : 105
LinePosition         : 8
InnerStartIndex      : 20567
OuterStartIndex      : 20491
InnerLength          : 24
OuterLength          : 104
Name                 : a
NextSibling          : HtmlAgilityPack.HtmlTextNode
NodeType             : Element
OriginalName         : a
OuterHtml            : <a href="#block-menu-menu-gunb" class="element-invisible element-focusable">Przejdź do menu głównego</a>
OwnerDocument        : HtmlAgilityPack.HtmlDocument
ParentNode           : HtmlAgilityPack.HtmlNode
PreviousSibling      : HtmlAgilityPack.HtmlTextNode
StreamPosition       : 20491
XPath                : /html[1]/body[1]/div[1]/a[1]
Depth                : 0
                #>
                # Get the domain of the current URL
                $currentDomain = [System.Uri]::new($url).Host
                Write-Log "Current domain is [$currentDomain]"
                #Write-Verbose "`$currentDomain: '$currentDomain', Domains: $domains"

                # wykryte domeny w linkach
                $domains = @()
                Write-Log "Created empty array [domains]"

                if (-not $onlyDomains.IsPresent) {
                    Write-Verbose "processing hreflinks..."
                    
                    # Iterate over the anchor elements and extract the href attributes
                    foreach ($anchorElement in $anchorElements) {
                        $href = $anchorElement.GetAttributeValue("href", "")
                        
                        # Remove mailto: links
                        $href = $href -replace "mailto:", ""
    
                        # Filter out non-HTTP links
                        if ($href -match "^https?://") {
                            <#                             if ($depth -eq 0) {
                                # immediately returns the program flow to the top of a program loop
                                continue
                            }
 #>                            # Add the link to the output file, if specified
                            if ($outputFolder -ne "") {
                                #$hrefFile = (Join-Path -Path $outputFolder -ChildPath (Set-PSWCCleanWebsiteURL -Url $url)) + ".hrefs.txt"
                                Add-Content -Path ([string]::Concat($outputFile, ".hrefs.txt")) -Value $href
                            }
                            
                            # Get the domain of the linked URL
                            $linkedDomain = [System.Uri]::new($href).Host
    
                            # Check if the linked domain is different from the current domain
                            if ($linkedDomain -ne $currentDomain -and -not $noCrawlExternalLinks) {
                                # Decrease the depth when moving to a different site
                                $newDepth = $depth - 1
                            }
                            else {
                                $newDepth = $depth
                            }
    
                            # Add the link to the list of links to crawl
                            Write-Verbose "Found link: $href (Depth: $newDepth)"
                            
                            # Recursively crawl with the adjusted depth
                            Crawl-Url -url $href -depth $newDepth -timeoutSec $timeoutSec -outputFile $outputFile -verbose:$verbose -statusCodeVerbose:$statusCodeVerbose -noCrawlExternalLinks:$noCrawlExternalLinks -userAgent $userAgent -onlyDomains:$onlyDomains
                        }
                        else {
                            # Add the link to the output file, if specified
                            if ($outputFolder -ne "") {
                                #$hrefFile = (Join-Path -Path $outputFolder -ChildPath $(Set-PSWCCleanWebsiteURL -Url $url)) + ".hrefs.anchorElement.txt"
                                Add-Content -Path (j[string]::Concat($outputFile, ".hrefs.anchorElement.txt")) -Value $href
                            }
                        }
                    }
                }
                else {

                    #Write-Verbose "processing onlydomains..."
                    # Iterate over the anchor elements and extract the href attributes - only domains
                    foreach ($anchorElement in $anchorElements) {
                        $href = $anchorElement.GetAttributeValue("href", "")
                        #Write-Verbose " processing '$href'..."
                        #Write-Log "analyze element [$href]"
                        # Remove mailto: links
                        $href = $href -replace "mailto:", ""
    
                        # Filter out non-HTTP links
                        if ($href -match "^https?://") {
                            #Write-Verbose "  processing '$href'..."
                            $hrefDomain = Get-PSWCSchemeAndDomain -url $href
                            Write-Log "Processing element [$hrefdomain]"

                            <#                             if ($depth -eq 0) {
                                # immediately returns the program flow to the top of a program loop
                                #Write-Verbose "  Killing ... reached depth 0"
                                continue
                            }
 #>    
                            # Add the link to the output file, if specified
                            if ($outputFolder -ne "") {
                                #$hrefFile = (Join-Path -Path $outputFolder -ChildPath $(Set-PSWCCleanWebsiteURL -Url $url)) + ".hrefs.txt"
                                Add-Content -Path ([string]::Concat($outputFile, ".hrefs.txt")) -Value $href
                                Write-Log "add content [$href] to file [${outputFile}.hrefs.txt]"
                                #Write-Verbose "  processing '$href'...saving to '$hrefFile'"
                            }
                            
                            # Get the domain of the linked URL
                            $linkedDomain = [System.Uri]::new($href).Host
                            Write-Log "[LinkedDomain] is for [$linkedDomain]"
                            #Write-Verbose "  domain '$linkedDomain'"
                            #if ($script:ArrayData.domain.contains($hrefdomain)){
                            #    continue
                            #}
                            
                            #Write-Verbose "  [$depth] ['$url' - '$hrefdomain']"

                            #Write-Verbose "  ('$linkedDomain' -ne '$currentDomain' -and -not `$noCrawlExternalLinks): $($linkedDomain -ne $currentDomain -and -not $noCrawlExternalLinks)"
                            # Check if the linked domain is different from the current domain
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
                                    $server = $response.Headers.Server -join "; "
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


                            #if ($domains) {
                            #Write-Verbose "[ ] Domain count in '$currentDomain' in depth ${depth}: $(($domains | Measure-Object).count)"
                            #Write-Verbose ($domains | out-string)
    
                            #$uniqDomains = $domains | Select-Object -Unique
                            #Write-Verbose "[ ] Uniqual domain count in '$currentDomain' in depth ${depth}: $(($uniqDomains | Measure-Object).count)"
                            #Write-Verbose ($uniqDomains -join ", ")
    
                            #foreach ($currentuniqdomain in $uniqDomains) {  
                            #Write-Verbose "Processing domain '$hrefDomain'"                          
                            # Recursively crawl with the adjusted depth - unique domains
                            #                        Write-Verbose " (-not ('$currentuniqdomain' -in `$script:historyDomains)): $(-not ($currentuniqdomain -in $script:historyDomains))"                          
                            #                        if (-not ($currentuniqdomain -in $script:historyDomains)) {
                            #                       }
                            #}
                            #$script:historyDomains += $uniqDomains

                        }
                        else {
                            # Add the link to the output file, if specified
                            if ($outputFolder -ne "") {
                                $hrefFile = (Join-Path -Path $outputFolder -ChildPath (Set-PSWCCleanWebsiteURL -Url $url)) + ".hrefs.anchorElement.txt"
                                Add-Content -Path $hrefFile -Value $href
                                Write-Log "Added [$href] to file [$hreffile]"

                                #Write-Verbose "  processing '$href'...saving to '$hrefFile'"
                            }
                        }
                    }

                }            
            }
            else {
                # Handle non-successful HTTP responses here, e.g., log the error or take appropriate action
                Write-Log "Response from [$url] wan not successful"
                Write-Host "HTTP request failed for URL: $url. Status code: $($response.StatusCode)"
                if ($statusCodeVerbose.IsPresent) {
                    switch ($response.StatusCode) {
                        "308" { 
                            Write-Host "HTTP status code 308 is a 'Permanent Redirect' status code. It indicates that the requested resource has been permanently moved to a different URL, and the client should use the new URL for all future requests. This status code is similar to 301 (Moved Permanently), but it specifies that the request method (GET, POST, etc.) must not be changed when redirecting. Here's a brief description of HTTP status code 308: 308 Permanent Redirect: The request is redirected to a new URL, and the client should use the new URL for all subsequent requests. The HTTP method (GET, POST, etc.) should not change when following the redirect. This status code is useful when the server wants to indicate that the resource has been permanently moved and the client should update its bookmarks or links accordingly. In summary, a response with status code 308 indicates a permanent redirect to a new URL, and the client should update its request to use the new URL for future interactions with the resource."
                        }
                        "BadRequest" {
                            Write-Host "HTTP status code 400, often referred to as 'Bad Request' indicates that the server could not understand the client's request due to malformed syntax, missing parameters, or other client-side errors. It means that the request sent by the client is incorrect or invalid in some way.
When handling a 400 Bad Request response in your code, you typically want to do the following:
Check for a 400 Status Code: First, check the HTTP status code in the response to ensure it is indeed a Bad Request.
Parse the Response: Depending on the API or service you're interacting with, the response may contain more details about what went wrong. You can usually parse the response body to extract error messages or additional information.
Handle Errors Gracefully: Implement error handling logic to handle the Bad Request appropriately. You might want to log the error, display a user-friendly error message, or take other actions depending on your application's requirements.
                        "
                        }
                        "NotFound" {
                            Write-Host "not found"
                        }
                        "Forbidden" {
                            Write-Host "forbidden"
                        }
                        "MethodNotAllowed" {
                            Write-Host "description MethodNotAllowed"
                        }
                        "449" {
                            Write-Host "description 449; https://en.wikipedia.org/wiki/List_of_HTTP_status_codes"
                        }
                        Default {
                            write-host "no description"
                            $response | ConvertTo-Json
                        }
                    }
                }
            }
        }
        catch {
            
            $errorMessage = $_.Exception.Message
            $scriptData = @{
                Url        = $url
                Depth      = $depth
                TimeoutSec = $timeoutSec
                OutputFile = $outputFile
                UserAgent  = $userAgent
            }
            
            # Get the script line where the error occurred
            $errorLine = $MyInvocation.ScriptLineNumber
            Write-Log "Error message: [$_.Exception.Message] for [$(-join $($scriptData.Values))] in line [$errorline]"
            Write-Host "Error occurred at line $errorLine while crawling URL: $url"
            Write-Host "Error crawling URL: $url"
            Write-Host "Error Details: $errorMessage"
            Write-Host "Script Data:"
            $scriptData | Format-List
        
            # You can log the error, script data, and the error line to a log file or perform other actions as needed
            # Example: Add-Content -Path "error.log" -Value "Error occurred at line $errorLine while crawling URL: $url. Details: $errorMessage. Script Data: $($scriptData | Out-String)"
        }
    }
    else {
        Write-Verbose "Already processed domain: '$url'"
        Write-Log "url [$url] was skipped"
        continue
    }

}

function Get-PSWCHttpResponse {
    param (
        [string]$url,
        [string]$userAgent,
        [int]$timeout
    )

    # Create an HttpClient with a custom User-Agent header
    $httpClient = New-Object System.Net.Http.HttpClient
    $httpClient.DefaultRequestHeaders.Add("User-Agent", $userAgent)

    # Set the timeout for the HttpClient
    $httpClient.Timeout = [System.TimeSpan]::FromSeconds($timeoutSec)

    # Send an HTTP GET request to the URL
    return $httpClient.GetAsync($url).Result
}

function Get-PSWCDocumentElements {
    param(
        [string]$htmlContent,
        [string]$Node
    )
    # Load the HTML content into the HTML Agility Pack
    $htmlDocument = [HtmlAgilityPack.HtmlDocument]::new()
    $htmlDocument.LoadHtml($htmlContent)
    
    # Get the root HTML node
    $rootXmlNode = $htmlDocument.DocumentNode

    # Extract all anchor elements from the HTML document
    return $rootXmlNode.SelectNodes($Node)
}

function Set-PSWCCleanWebsiteURL {
    <#
.SYNOPSIS
    Cleans an array of website URLs by removing "http://" or "https://://" and replacing non-letter and non-digit characters with underscores.

.DESCRIPTION
    The Set-PSWCCleanWebsiteURL function takes an array of website URLs as input, removes "http://" or "https://://" from each URL, and replaces all characters that are not digits or letters with underscores. It then returns an array of cleaned URLs.

.PARAMETER Urls
    Specifies an array of website URLs to be cleaned.

.EXAMPLE
    $websiteUrls = @("https://www.example.com?param=value", "http://another-example.com")
    $cleanedUrls = fuction clean -Urls $websiteUrls
    $cleanedUrls | ForEach-Object {
        Write-Host "Cleaned URL: $_"
    }
    
    This example cleans the provided array of website URLs and displays the cleaned URLs.

.NOTES
    Author         : Wojciech Napierała (@scriptsavvyninja)
    Prerequisite   : PowerShell v3
    
#>
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url
    )
    try {
        # Create a Uri object to parse the URL
        $uri = [System.Uri]$url

        # Get the host part of the URL
        $uriHost = $uri.Host

        # Replace non-letter and non-digit characters with underscores
        $cleaneduriScheme = $uri.Scheme -replace "[^a-zA-Z0-9]", "_"
        $cleanedHost = $uriHost -replace "[^a-zA-Z0-9]", "_"
        $cleanedPathandQuery = $uri.PathAndQuery -replace "[^a-zA-Z0-9]", "_"

        # Build the cleaned URL
        $cleanedUrl = "$($cleaneduriScheme)_$($cleanedHost)_$($cleanedPathandQuery)"
        #$cleanedUrl = "$cleanedHost$($uri.PathAndQuery)"
        #$cleanedUrl = "$cleanedHost"

        # Add the cleaned URL to the array
        #$cleanedUrls += $cleanedUrl
    }
    catch [System.UriFormatException] {
        Write-Error "Invalid URL format: $url"
    }
    catch {
        Write-Error "An error occurred while cleaning the URL: $($_.Exception.Message)"
    }

    # Output the array of cleaned URLs
    return $cleanedUrl
}

function Get-PSWCSchemeAndDomain {
    # Example usage:
    #$url = "https://www.example.com/path/to/page"
    #$schemeAndDomain = Get-PSWCSchemeAndDomain -url $url
    #Write-Host "Scheme and Domain: $schemeAndDomain"
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$url
    )

    # Create a Uri object and get the scheme and Host properties
    $uri = New-Object System.Uri($url)
    $schemeAndDomain = $uri.Scheme + "://" + $uri.Host

    # Return the extracted scheme and domain
    return $schemeAndDomain
}

function New-PSWCCacheFolder {
    param (
        [string]$FolderName
    )
    $tempfolder = [System.IO.Path]::GetTempPath()
    $tempfolderFullName = Join-Path $tempfolder $FolderName

    if (-not (Test-Path -Path $tempfolderFullName)) {
        try {
            [void](New-Item -Path $tempfolderFullName -ItemType Directory)
            Write-Verbose "Temp '$tempfolderFullName' folder was created successfully."
            Write-Log "Temp '$tempfolderFullName' folder was created successfully."
            return $true
        }
        catch {
            Write-Error "Error creating cache folder. [$($_.error.message)]"
            return $false
        }
    }
    return $true
}

function Get-PSWCCacheFolder {
    param ()

    $tempfolder = [System.IO.Path]::GetTempPath()
    $tempfolderFullName = Join-Path $tempfolder $script:ModuleName

    return $tempfolderFullName

}

function Open-PSWCExplorerCache {
    param (
        [string]$FolderName
    )
    $tempfolder = [System.IO.Path]::GetTempPath()
    $tempfolderFullName = Join-Path $tempfolder $FolderName
    $tempfolderFullName
    if (test-path $tempfolderFullName) {
        try {
            Start-Process explorer.exe -ArgumentList $tempfolderFullName
            Write-Log "Process Temp [explorer.exe] was started with arguments [$tempfolderFullName]"

        }
        catch {
            Write-Error "An error starting process: $_"
            Write-Log "Process Temp [explorer.exe] was not started with arguments [$tempfolderFullName]"
        }
    }
    else {
        New-PSWCCacheFolder -FolderName $FolderName
        Open-PSWCExplorerCache -FolderName $FolderName
        #Write-Information -InformationAction Continue -MessageData "Cache folder does not exist."
    }
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$logstring,
        [string]$logFile = (Join-Path $env:TEMP "$($script:ModuleName).log")

    )
    #Write-Debug -Message "Append [$logstring] to log file: [$logfile]"
    $strToLog = "[$(get-date)]: $logstring"
    $strToLog | Out-File $Logfile -Append -Encoding utf8
}


function Start-PSWebCrawler {
    <#
.SYNOPSIS
    Performs various operations related to web crawler.

.DESCRIPTION
    The 'WebCrawler' function allows you to process and web crawl.

.PARAMETER SavePath
    Specifies the path to save the feed data. This parameter is mandatory when 'AddFeed' is used.

.PARAMETER Timeout
    Specifies the timeout value for URL accessibility testing. This parameter is optional and only applicable when 'AddFeed' is used.
#>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param (
        [Parameter(ParameterSetName = 'WebCrawl', Mandatory = $true)]
        [Parameter(ParameterSetName = 'ShowAllElements', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^https?://.*')]
        [string]$Url,

        [Parameter(ParameterSetName = 'ShowAllElements')]
        [switch]$ShowAllElements,

        [Parameter(ParameterSetName = 'ShowAllElements')]
        [ValidateSet("Href", "noHref", "onlyDomains", "All")]
        [string]$Type = "All",
        
        [Parameter(ParameterSetName = 'WebCrawl')]
        [int]$Depth = 2,

        [Parameter(ParameterSetName = 'ShowAllElements')]
        [Parameter(ParameterSetName = 'WebCrawl')]
        [switch]$onlyDomains,

        [Parameter(ParameterSetName = 'WebCrawl')]
        [string]$outputFolder = (Get-PSWCCacheFolder),

        [Parameter(ParameterSetName = 'ShowCacheFolder', Mandatory = $true)]
        [switch]$ShowCacheFolder
       
        
    )
    Get-PSWCBanner
    Write-Verbose "ParameterSetName: [$($PSCmdlet.ParameterSetName)]" -Verbose
    switch ($PSCmdlet.ParameterSetName) {
        'WebCrawl' {
            $script:ArrayData = @()
            Write-Log "Initializing array [ArrayData]"
            $script:ArrayData += [PSCustomObject] @{
                Depth     = $depth
                Url       = $url
                Domain    = ""
                Href      = ""
                UrlServer = ""
                Date      = (get-date)
            }
            Write-Log "insert to [ArrayData] depth: [$depth], url: [$url]"
            if (-not $outputFolder) {
                #    $outputFile = join-path $outputFolder -ChildPath $(Set-PSWCCleanWebsiteURL -url $url)
                $outputfoldertext = "not set"
                
            }
            else {
                $outputfoldertext = $outputFolder
                Write-Log "[outputfoldertext] is set to [$outputfolder]"
            }
            # Start crawling the start URL
            Write-Host "Url: [$Url]"
            Write-Host "Depth: $depth"
            write-host "onlyDomains: $onlydomains"
            write-host "outputFolder: [$outputfoldertext]"
            #$script:historydomains += (Get-PSWCSchemeAndDomain -url $url)
            Write-Log "Start iteration for [$url] with depth: [$depth]"
            Start-PSWCCrawl -url $Url -depth $depth -onlyDomains:$onlyDomains -outputFolder $outputFolder
            
            Write-Host "liczba sprawdzonych domen: " -NoNewline
            ($script:historyDomains | Select-Object -Unique | Measure-Object).count
            
            Write-Host "sprawdzone domeny (po url):"
            $script:historyDomains | Select-Object -Unique  | Sort-Object
            #$ArrayData | Where-Object { $_.Domain } | Select-Object depth, url, domain | Sort-Object url, domain
            $ArrayData | Where-Object { $_.Domain } | Sort-Object url, domain | Select-Object url, server -Unique | Format-Table url, server

            Write-Host "sprawdzone domeny (po domain):"
            $script:historyDomains | Select-Object -Unique  | Sort-Object
            #$ArrayData | Where-Object { $_.Domain } | Select-Object depth, url, domain | Sort-Object url, domain
            $ArrayData | Where-Object { $_.Domain } | Sort-Object domain, domain | Select-Object domain, server -Unique | Format-Table domain, server

            $ArrayData | Out-GridView

            break
        }
        'ShowCacheFolder' {
            #New-PSWCCacheFolder -FolderName $script:WCtoolfolderFullName
            Open-PSWCExplorerCache -FolderName $script:ModuleName
            break
        }
        'ShowAllElements' {
            #Write-Verbose "ShowAllElements" -Verbose
            Get-PSWCAllElements -url $url -onlyDomains:$onlyDomains -Type $type
            break
        }
        default {
            $helpinfo = @'
How to use, examples:
[1] PSWC -Url "http://allafrica.com/tools/headlines/rdf/latest/headlines.rdf" -Depth 1
[2] PSWC -Url "http://allafrica.com/tools/headlines/rdf/latest/headlines.rdf" -Depth 2 -onlyDomains
[3] PSWC -Url "http://allafrica.com/tools/headlines/rdf/latest/headlines.rdf" -ShowAllElements -Type
[4] 
[5] 
[6] 
[7] 
[8] 
[9] 
[10] 
[11] 
[11] PSWC -ShowCacheFolder  



'@
            Write-Output $helpinfo
            break
        }
    }
}

Clear-Host

# Import the necessary .NET libraries
#Add-Type -Path "D:\dane\voytas\Dokumenty\visual_studio_code\github\htmlagilitypack.1.11.52\lib\netstandard2.0\HtmlAgilityPack.dll"
Add-Type -Path "D:\dane\voytas\Dokumenty\visual_studio_code\github\htmlagilitypack.1.11.54\lib\netstandard2.0\HtmlAgilityPack.dll"

# Switch to using TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
# Get the name of the current module
$script:ModuleName = "PSWebCrawler"

# Get the installed version of the module
$ModuleVersion = [version]"0.0.2"

# Find the latest version of the module in the PSGallery repository
$LatestModule = Find-Module -Name $ModuleName -Repository PSGallery

try {
    if ($ModuleVersion -lt $LatestModule.Version) {
        Write-Host "An update is available for $($ModuleName). Installed version: $($ModuleVersion). Latest version: $($LatestModule.Version)." -ForegroundColor Red
    } 
}
catch {
    Write-Error "An error occurred while checking for updates: $_"
}

Set-Alias -Name "PSWC" -Value Start-PSWebCrawler
Set-Alias -Name "PSWebCrawler" -Value Start-PSWebCrawler

Write-Host "Welcome to PSWebCrawler!" -ForegroundColor DarkYellow
Write-Host "Thank you for using PSWC ($($moduleVersion))." -ForegroundColor Yellow
#Write-Host "Some important changes and informations that may be of interest to you:" -ForegroundColor Yellow
#Write-Host "- You can filter the built-in snippets (category: 'Example') by setting 'ShowExampleSnippets' to '`$false' in config. Use: 'Save-PAFConfiguration -settingName ""ShowExampleSnippets"" -settingValue `$false'" -ForegroundColor Yellow

New-PSWCCacheFolder -FolderName $script:ModuleName

<# 
# Set the URL to start crawling from
$startUrl = $url

# Create a list to store the visited URLs
$visitedUrls = @()

# Set the timeout for the web requests
$Timeout = 10

# Get the temporary folder path
$tempFolder = [System.IO.Path]::GetTempPath()

# Replace any invalid characters in the URL with underscores
$validFileName = Clean-WebsiteURL $url
#$validFileName = $url -replace '[^\w\d-]', $null

#check for files
$xmlfiles = Get-childItem -Path $tempFolder -Filter "*.xml"
$xmlfiles.fullname

# Create a file path to store the output XML file
$outputContentFilePath = Join-Path -Path $tempFolder -ChildPath "$validFileName.xml"

# Try to download and save the feed data
try {
    # Invoke-WebRequest -Uri $Url -TimeoutSec $Timeout -OutFile $outputContentFilePath
    # | Out-Null

    # Save the feed data to a temporary XML file
    #Invoke-WebRequest -Uri $Url -TimeoutSec $Timeout | Export-Clixml $outputContentFilePath

    # If the file was saved successfully, return $true
    if (Test-Path -Path $outputContentFilePath -PathType Leaf) {
        Write-Verbose "Web downloaded and saved to '$outputContentFilePath'."

        # Import the feed data from the temporary XML file
        $webdata = Import-Clixml $outputContentFilePath

        # Display the feed data
        if ($showwebdata.IsPresent) { 
            $webdata
        }
        #return $true
    }
    else {
        # If the file was not saved successfully, write a warning message and return $false
        Write-Warning "Failed to save feed data to file: $outputContentFilePath"
        #return $false
    }
}
catch {
    # If the download or save failed, write a warning message and return $false
    Write-Warning "Failed to download feed data: $($_.Exception.Message)"
    #return $false
}

 #>


