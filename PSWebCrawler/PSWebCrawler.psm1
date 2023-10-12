function Get-PSWCBanner {
    param (
        
    )
   
    $banner = get-content -Path "${PSScriptRoot}\images\PSWCbanner.txt"
    Write-Output $banner
    return
}

# Function to crawl a URL
function Start-Crawl {
    [CmdletBinding()]
    param (
        [string]$url,
        [int]$depth,
        [int]$timeoutSec = 10,
        [string]$outputFile,
        [switch]$statusCodeVerbose,
        [switch]$noCrawlExternalLinks,
        [switch]$onlyDomains,
        [string]$userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36 Edg/117.0.2045.43"
    )

    #$ArrayData | ft

    # Initialize the visitedUrls variable if it doesn't exist
    $outputFolder = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath "webcrawler"
    if (-not (Test-Path -Path $outputFolder)) {
        [void](New-Item -Path $outputFolder -ItemType Directory)
    }
    $outputFile = join-path $outputFolder -ChildPath (Clean-WebsiteURL -url $url)
    
    if (-not $script:visitedUrls) {
        $script:visitedUrls = @{}
        #write-verbose 'create $script:visitedUrls'
    }

    if (-not $script:historyDomains) {
        $script:historyDomains = @()
        #write-verbose 'create $script:historyDomains'
    }
    #$script:historyDomains

    if ($onlyDomains.IsPresent) {
        $url = Get-SchemeAndDomain -url $url
        #write-verbose "create `$url as Get-SchemeAndDomain -url '$url'"
    }

    # If the URL has not already been visited, add it to the list of visited URLs and crawl it
    # sprawdzamy takze ddwiedzone domeny, zadziala nawet jak bedziemy uzywac url z query path
    #write-verbose "(-not `$visitedUrls.ContainsKey($url) -and -not ((Get-SchemeAndDomain -url $url) -in `$script:historydomains)): ($(-not $visitedUrls.ContainsKey($url) -and -not ((Get-SchemeAndDomain -url $url) -in $script:historydomains)))"
    #if (-not $visitedUrls.ContainsKey($url) -and -not ((Get-SchemeAndDomain -url $url) -in $script:historydomains)) {
    #    write-verbose "(-not `$visitedUrls.ContainsKey($url))): ($(-not $visitedUrls.ContainsKey($url))"
    #    if (-not $visitedUrls.ContainsKey($url)) {
    #write-verbose "(-not (`$url -in `$script:historydomains)): $(-not ($url -in $script:historydomains))"
    #if (-not ($url -in $script:historydomains)) {
   #write-verbose "`$script:ArrayData.url.Contains($url): $($script:ArrayData.url.Contains($url))"

    if ($script:ArrayData.url.Contains($url)) {
        #if (-not $visitedUrls.ContainsKey($url) -and -not ((Get-SchemeAndDomain -url $url) -in $script:historydomains)) {
        #$visitedUrls[$url] = $true

        try {
            # Send an HTTP GET request to the URL
            $response = Get-HttpResponse -url $url -userAgent $userAgent -timeout $timeoutSec
            #$response | ConvertTo-Json

            # Check if the request was successful
            if ($response.IsSuccessStatusCode) {
                
                #write-verbose "`$response.IsSuccessStatusCode for '$url': $($response.IsSuccessStatusCode)"
                $htmlContent = $response.Content.ReadAsStringAsync().Result
                $responseHeaders = $response.Headers | ConvertTo-Json  # Capture response headers

                # Save the headers to a file if specified
                if ($outputFile -ne "") {
                    $headersFile = (Join-Path -Path $outputFolder -ChildPath $(Clean-WebsiteURL($url))) + ".headers.json"
                    Set-Content -Path $headersFile -Value $responseHeaders
                    #write-verbose "Save the headers to a file for '$url' to '$headersFile'"
                }

                #write-verbose "Add '$url' to `$script:historyDomains"
                $script:historyDomains += $url

                # Extract all anchor elements from the HTML document
                $anchorElements = Get-DocumentElements -htmlContent $htmlContent -Node "//a"
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
                #Write-Verbose "`$currentDomain: '$currentDomain', Domains: $domains"

                # wykryte domeny w linkach
                $domains = @()

                if (-not $onlyDomains.IsPresent) {
                    Write-Verbose "processing hreflinks..."
                    # Iterate over the anchor elements and extract the href attributes
                    foreach ($anchorElement in $anchorElements) {
                        $href = $anchorElement.GetAttributeValue("href", "")
                        
                        # Remove mailto: links
                        $href = $href -replace "mailto:", ""
    
                        # Filter out non-HTTP links
                        if ($href -match "^https?://") {
                            if ($depth -eq 0) {
                                # immediately returns the program flow to the top of a program loop
                                continue
                            }
    
                            # Add the link to the output file, if specified
                            if ($outputFile -ne "") {
                                $hrefFile = (Join-Path -Path $outputFolder -ChildPath (Clean-WebsiteURL($url))) + ".hrefs.txt"
                                Add-Content -Path $hrefFile -Value $href
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
                            if ($outputFile -ne "") {
                                $hrefFile = (Join-Path -Path $outputFolder -ChildPath $(Clean-WebsiteURL($url))) + ".hrefs.anchorElement.txt"
                                Add-Content -Path $hrefFile -Value $href
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
                        
                        # Remove mailto: links
                        $href = $href -replace "mailto:", ""
    
                        # Filter out non-HTTP links
                        if ($href -match "^https?://") {
                            #Write-Verbose "  processing '$href'..."
                            $hrefDomain = Get-SchemeAndDomain -url $href


                            if ($depth -eq 0) {
                                # immediately returns the program flow to the top of a program loop
                                #Write-Verbose "  Killing ... reached depth 0"
                                continue
                            }
    
                            # Add the link to the output file, if specified
                            if ($outputFile -ne "") {
                                $hrefFile = (Join-Path -Path $outputFolder -ChildPath $(Clean-WebsiteURL($url))) + ".hrefs.txt"
                                Add-Content -Path $hrefFile -Value $href
                                #Write-Verbose "  processing '$href'...saving to '$hrefFile'"
                            }
                            
                            # Get the domain of the linked URL
                            $linkedDomain = [System.Uri]::new($href).Host
                            #Write-Verbose "  domain '$linkedDomain'"
                            #if ($script:ArrayData.domain.contains($hrefdomain)){
                            #    continue
                            #}
                            Write-Verbose "  [$depth] ['$url' - '$hrefdomain']"

                            #Write-Verbose "  ('$linkedDomain' -ne '$currentDomain' -and -not `$noCrawlExternalLinks): $($linkedDomain -ne $currentDomain -and -not $noCrawlExternalLinks)"
                            # Check if the linked domain is different from the current domain
                            if ($linkedDomain -ne $currentDomain -and -not $noCrawlExternalLinks) {
                                #Write-Verbose "  processing '$hrefdomain'..."
                                #$script:ArrayData.url.contains($hrefdomain)
                                if (-not ($script:ArrayData.url.contains($hrefdomain))) {
                                    $thisobject = [PSCustomObject] @{
                                        Depth  = $depth
                                        Url    = $hrefDomain
                                        Domain = ""
                                        Href   = ""
                                    }
                                    $script:ArrayData += $thisobject
                                }
    
                                # Decrease the depth when moving to a different site
                                $newDepth = $depth - 1
                                #Write-Verbose "  set new depth to $newDepth"
                                
                                # Add the link to the list of links to crawl
                                $domains += $hrefDomain
                                #Write-Verbose "  add '$hrefDomain' to `$domains"
                                #Write-Verbose " [recursive] Processing domain: $hrefDomain (Depth: $depth => $newDepth)"

                                if (-not ($script:ArrayData.domain.contains($hrefdomain))) {
                                    $thisobject = [PSCustomObject] @{
                                        Depth  = $depth
                                        Url    = $url
                                        Domain = $hrefDomain
                                        Href   = $href
                                    }
                                    $script:ArrayData += $thisobject
                                }
                                Start-Crawl -url $hrefDomain -depth $newDepth -timeoutSec $timeoutSec -outputFile $outputFile -statusCodeVerbose:$statusCodeVerbose -noCrawlExternalLinks:$noCrawlExternalLinks -userAgent $userAgent -onlyDomains:$onlyDomains -verbose:$verbose -debug:$debug
    
                            }
                            else {
                                $newDepth = $depth
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
                            if ($outputFile -ne "") {
                                $hrefFile = (Join-Path -Path $outputFolder -ChildPath (Clean-WebsiteURL($url))) + ".hrefs.anchorElement.txt"
                                Add-Content -Path $hrefFile -Value $href
                                #Write-Verbose "  processing '$href'...saving to '$hrefFile'"
                            }
                        }
                    }

                }            
            }
            else {
                # Handle non-successful HTTP responses here, e.g., log the error or take appropriate action
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
        continue
    }

}

function Get-HttpResponse {
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

function Get-DocumentElements {
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

function Clean-WebsiteURL {
    <#
.SYNOPSIS
    Cleans an array of website URLs by removing "http://" or "https://://" and replacing non-letter and non-digit characters with underscores.

.DESCRIPTION
    The Clean-WebsiteURL function takes an array of website URLs as input, removes "http://" or "https://://" from each URL, and replaces all characters that are not digits or letters with underscores. It then returns an array of cleaned URLs.

.PARAMETER Urls
    Specifies an array of website URLs to be cleaned.

.EXAMPLE
    $websiteUrls = @("https://www.example.com?param=value", "http://another-example.com")
    $cleanedUrls = Clean-WebsiteURL -Urls $websiteUrls
    $cleanedUrls | ForEach-Object {
        Write-Host "Cleaned URL: $_"
    }
    
    This example cleans the provided array of website URLs and displays the cleaned URLs.

.NOTES
    File Name      : Clean-WebsiteURL.ps1
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


function Get-SchemeAndDomain {
    # Example usage:
    #$url = "https://www.example.com/path/to/page"
    #$schemeAndDomain = Get-SchemeAndDomain -url $url
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

function New-PSWCTempFeedFolder {
    param (
        [string]$FolderName
    )
    try {
        $tempfolder = [System.IO.Path]::GetTempPath()
        $tempfolderFullName = Join-Path $tempfolder $FolderName
        if (-not (Test-Path -Path $tempfolderFullName)) {
            [void](New-Item -Path $tempfolderFullName -ItemType Directory)
            Write-Verbose "Feed temp '$tempfolderFullName' folder was created successfully."
        }
        return $tempfolderFullName
    }
    catch {
        Write-Error "An error creating '$tempfolderFullName': $_"
    }
}

function Open-PSWCExplorer {
    param (
        [string]$PathToOpen
    )
    if (test-path $PathToOpen) {
        try {
            Start-Process explorer.exe -ArgumentList $PathToOpen
        }
        catch {
            Write-Error "An error starting process: $_"
        }
    }
    else {
        Write-Information -InformationAction Continue -MessageData "Cache folder does not exist."
    }
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
        [Parameter(ParameterSetName = 'ValidateFeedListFromFilename', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ValidateFeedListFilename,

        [Parameter(ParameterSetName = 'ValidateFeedListFromFilename')]
        [switch]$SaveToTempFeedFolder,

        [Parameter(ParameterSetName = 'TestFeedFromUrl', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^https?://.*')]
        [string]$TestFeedUrl,

        [Parameter(ParameterSetName = 'TestFeedFromUrl', Mandatory = $false)]
        [int]$LastDaysElements = 0,

        [Parameter(ParameterSetName = 'RemoveDuplicateCSVRows', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$InputPath,
        [Parameter(ParameterSetName = 'RemoveDuplicateCSVRows', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter(ParameterSetName = 'TestUrlFormat', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^https?://.*')]
        [string]$TestUrlFormat,

        [Parameter(ParameterSetName = 'ShowNews', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^https?://.*')]
        [string]$ShowNewsUrlFeed,
        [Parameter(ParameterSetName = 'ShowNews', Mandatory = $false)]
        [Parameter(ParameterSetName = 'ShowNewsfromFeed', Mandatory = $false)]
        [int]$LastNewsCount = 10,

        [Parameter(ParameterSetName = 'ShowNewsfromFeed', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ShowNewsfromFeed,

        [Parameter(ParameterSetName = 'ShowNewsfromFeedfileRandom', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [switch]$ShowNewsfromFeedfileRandom,

        [Parameter(ParameterSetName = 'AddFeed', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^https?://.*')]
        [string]$FeedUrl,
        [Parameter(ParameterSetName = 'AddFeed', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$SavePath,
        [Parameter(ParameterSetName = 'AddFeed', Mandatory = $false)]
        [int]$Timeout = 5,

        [Parameter(ParameterSetName = 'SaveFeed', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidatePattern('^https?://.*')]
        [string]$SaveFeedUrl,
        [Parameter(ParameterSetName = 'SaveFeed', Mandatory = $false)]
        [int]$SaveFeedTimeout = 5,

        [Parameter(ParameterSetName = 'GetSavedFeed', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$GetSavedFeedFileFullName,

        [Parameter(ParameterSetName = 'ShowCacheFolder')]
        [switch]$ShowCacheFolder,

        [Parameter(ParameterSetName = 'GetSavedFeeds', Mandatory)]
        [ValidateNotNullOrEmpty()]
        [switch]$GetSavedFeeds
        
    )
    Get-PSWCBanner
    switch ($PSCmdlet.ParameterSetName) {
        'ValidateFeedListFromFilename' {
            # Process data from a file
            Write-Verbose "Processing data from file: ${ValidateFeedListFilename}"
            $newsDirectory = $PSScriptRoot

            #$repositoryListPath = "${newsDirectory}\${ValidateFeedListFilename}"
            $repositoryListPath = ${ValidateFeedListFilename}

            $cryptoRssRepos = Find-PSFHCryptoRssRepositories -ListPath $repositoryListPath

            foreach ($repo in $cryptoRssRepos) {

                $feedData = @{}

                # Prompt the user for an RSS URL
                $rssUrl = $repo

                # Validate the URL format
                if (Test-PSFHUrlFormat $rssUrl) {
                    # Fetch the RSS feed
                    [Microsoft.PowerShell.Commands.HtmlWebResponseObject]$responseFeed = Get-PSFHFeed $rssUrl
                    #$rssFeed.rss
                    if ($responseFeed) {
                        # Determine the type of feed and its version
                        #Get-FeedTypeAndVersion $responseFeed

                        $feedData = Get-PSFHFeedInfo $rssUrl

                        # Check the URL accessibility
                        #$feedData | Add-Member -TypeName noteproperty - Test-PSFHUrlAccessibility $rssUrl -timeout 2
                        $feedData | Add-Member -MemberType NoteProperty -Name "UrlAccessibility" -Value (Test-PSFHUrlAccessibility $rssUrl -timeout 2)
                        #$feedData += Test-PSFHRssFeedValidity $rssUrl
                        $feedData | Add-Member -MemberType NoteProperty -Name "RssFeedValidity" -Value (Test-PSFHRssFeedValidity $rssUrl)
                        # Analyze the feed
                        #$feedData += Invoke-PSFHFeedAnalysis $responseFeed
                        $feedData | Add-Member -MemberType NoteProperty -Name "FeedAnalysis" -Value (Invoke-PSFHFeedAnalysis $responseFee)
                        if ($SaveToTempFeedFolder.IsPresent) {
                            try {
                                #Start-FeedNewsTool -SaveFeedUrl $rssUrl -SaveFeedTimeout 10
                                Save-PSFHFeed -Url $rssUrl -Timeout 10
                            }
                            catch {
                                $feedData
                                continue
                            }
                        }
                        $feedData
                    } 
                }
                else {
                    Write-Host "Test '$rssUrl' failed" -ForegroundColor DarkRed
                }
            }
            break
        }
        'TestFeedFromUrl' {
            # Process data from a URL
            Write-Verbose "Processing data from URL: ${TestFeedUrl}"
            if ((Test-PSFHUrlFormat -Url $TestFeedUrl) -and (Test-PSFHUrlAccessibility -Url $TestFeedUrl -Timeout 5)) {
                Write-Verbose "Test URL: OK"
                $objectfeed = Get-PSFHFeedInfo $TestFeedUrl
                [void](Save-PSFHFeed -Url $TestFeedUrl)
                #$objectfeed | Format-List *
                $objectfeed
            }
            else {
                Write-Verbose "Test URL: Failed"
                break
            }

            break
        }
        'TestUrlFormat' {
            Test-PSFHUrlFormat -Url $TestUrlFormat
            break
        }
        'RemoveDuplicateCSVRows' {
            # Process data in file - remove duplicates
            Write-Verbose "Processing data from file: ${InputPath} to file: ${OutputPath}"
            Remove-PSFHDuplicateCSVRows -InputPath $InputPath -OutputPath $OutputPath
            break
        }
        'ShowNews' {
            Get-PSFHFeedNews -RSSUrl $ShowNewsUrlFeed -LastItems $LastNewsCount

            break
        }
        'ShowNewsfromFeed' {
            $feedfromfile = Get-PSFHFeedDataFromFile -FeedFileFullName $ShowNewsfromFeed
            Get-PSFHFeedNews -Feed $feedfromfile -LastItems $LastNewsCount
            break
        }
        'ShowNewsfromFeedfileRandom' {
            #$tempfolder = [System.IO.Path]::GetTempPath()
            $feednewstoolfolder = $FolderName
            #$feednewstoolfolderFullName = Join-Path $tempfolder $feednewstoolfolder
            $tempFeedFolder = New-PSFHTempFeedFolder -FolderName $feednewstoolfolder
            write-host "News feed folder: ""$tempFeedFolder""" -ForegroundColor DarkYellow
            $RandomFeedFileFullName = Get-PSFHRandomFile -FolderPath $tempFeedFolder -Count 1
            if ($RandomFeedFileFullName.count -gt 0) {
                $feedfromfile = Get-PSFHFeedDataFromFile -FeedFileFullName $RandomFeedFileFullName
                Get-PSFHFeedNews -Feed $feedfromfile -LastItems $LastNewsCount
            }
            break
        }
        'AddFeed' {
            Write-Verbose "Adding feed: ${FeedUrl}"
            if ((Test-PSFHUrlFormat -Url $FeedUrl) -and (Test-PSFHUrlAccessibility -Url $FeedUrl -Timeout $Timeout)) {
                $feedData = Get-PSFHFeedInfo -Url $FeedUrl

                if ($feedData) {
                    Write-Verbose "Exporting feed data to CSV"
                    Export-PSFHFeedCSV -FeedData $feedData -OutPath $SavePath
                }
            }
            break
        }
        'SaveFeed' {
            Write-Verbose "Saving feed: ${SaveFeedUrl}"
            $savefeedout = Save-PSFHFeed -Url $SaveFeedUrl -Timeout $SaveFeedTimeout
            Write-Verbose "Save feed output: ${savefeedout}"
            break
        }
        'GetSavedFeed' {
            Get-PSFHFeedDataFromFile -FeedFileFullName $GetSavedFeedFileFullName
            break
        }
        'GetSavedFeeds' {
            # lists all files form cache folder
            if ((Test-Path -Path $feednewstoolfolderFullName)) {
                foreach ($currentItemName in (Get-ChildItem -Path $feednewstoolfolderFullName)) {
                    Write-Host $currentItemName.FullName
                }
            } else {
                Write-Host "No save feeds."
            }
            break
        }
        'ShowCacheFolder' {
            Open-PSFHExplorer -PathToOpen $feednewstoolfolderFullName
        }
        default {
            $helpinfo = @'
How to use, examples:
[1] PSFeedHandler -TestFeedUrl "http://allafrica.com/tools/headlines/rdf/latest/headlines.rdf"
[2] PSFeedHandler -InputPath .\News\feed_info2.csv -OutputPath .\News\feed_info3.csv
[3] PSFeedHandler -TestUrlFormat "http://gigaom.com/feed/"
[4] PSFeedHandler -ShowNewsUrlFeed "http://allafrica.com/tools/headlines/rdf/latest/headlines.rdf" -LastNewsCount 5
[5] PSFeedHandler -ShowNewsfromFeed 'C:\Users\voytas\AppData\Local\Temp\FeedNewsTool\allafrica_com_tools_headlines_rdf_latest_headlines_rdf.feed.tmp'
[6] PSFeedHandler -ShowNewsfromFeedfileRandom
[7] PSFeedHandler -FeedUrl "http://allafrica.com/tools/headlines/rdf/latest/headlines.rdf" -SavePath .\News\test.txt -Timeout 10
[8] PSFeedHandler -SaveFeedUrl "http://allafrica.com/tools/headlines/rdf/latest/headlines.rdf" -SaveFeedTimeout 10
[9] PSFeedHandler -GetSavedFeedFileFullName 'C:\Users\voytas\AppData\Local\Temp\FeedNewsTool\allafrica_com_tools_headlines_rdf_latest_headlines_rdf.feed.tmp'
[10] PSFeedHandler -GetSavedFeeds
[11] PSFeedHandler -ValidateFeedListFilename "repository_list.txt" -SaveToTempFeedFolder
[11] PSFeedHandler -ShowCacheFolder  



'@
            Write-Output $helpinfo
            break
        }
    }
}








Clear-Host

$FolderName = "WebCrawlerTool"
$tempfolder = [System.IO.Path]::GetTempPath()
$WCtoolfolderFullName = Join-Path $tempfolder $FolderName




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

$script:ArrayData = @()
$ArrayData += [PSCustomObject] @{
    Depth  = $depth
    Url    = $url
    Domain = ""
    Href   = ""
}

$outputFolder = (Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath (Clean-WebsiteURL -url $url))
$outputFile = join-path $outputFolder -ChildPath "webcrawler"
# Start crawling the start URL
Write-Host "START Crawl-Url '$Url'"
#$script:historydomains += (Get-SchemeAndDomain -url $url)
Start-Crawl -url $Url -depth $depth -onlyDomains -verbose -debug -statusCodeVerbose -outputFile $outputFile

Write-Host "END ----"
Write-Host "liczba sprawdzonych domen: " -NoNewline
($script:historyDomains | Select-Object -Unique | Measure-Object).count

Write-Host "sprawdzone domeny:"
$script:historyDomains | Select-Object -Unique  | Sort-Object

$ArrayData | Where-Object { $_.Domain } | select depth, url, domain | Sort-Object url, domain









# Import the necessary .NET libraries
#Add-Type -Path "D:\dane\voytas\Dokumenty\visual_studio_code\github\htmlagilitypack.1.11.52\lib\netstandard2.0\HtmlAgilityPack.dll"
Add-Type -Path "D:\dane\voytas\Dokumenty\visual_studio_code\github\htmlagilitypack.1.11.54\lib\netstandard2.0\HtmlAgilityPack.dll"

# Switch to using TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
# Get the name of the current module
$ModuleName = "PSWebCrawler"

# Get the installed version of the module
$ModuleVersion = [version]"0.0.1"

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
