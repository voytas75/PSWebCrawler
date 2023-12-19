function Get-PSWCBanner {
    <#
    .SYNOPSIS
    Retrieves and displays the content of a banner file.

    .DESCRIPTION
    The Get-PSWCBanner function reads the content of a banner file and displays it in the console.

    .PARAMETER FilePath
    Specifies the path to the banner file.

    .EXAMPLE
    Get-PSWCBanner -FilePath "C:\path\to\banner.txt"
    Retrieves the content of the banner file located at the specified path and displays it in the console.

    .NOTES
    Author: scripsavvyninja
    Date: 25.11.2023
    #>

    param (
        [string] 
        $FilePath = (Join-Path -Path $PSScriptRoot -ChildPath "images\PSWCbanner.txt")
    )

    # Read the content of the banner file.
    $banner = Get-Content -Path $FilePath -Raw

    # Display the banner in the console.
    Write-Output $banner
}

function Get-PSWCAllElements {
    <#
    .SYNOPSIS
        Get-PSWCAllElements - Extracts all elements from a given URL.

    .DESCRIPTION
        This function extracts all elements from a given URL, including Href elements, non-Href elements, domains, and internal links.

    .PARAMETER url
        The URL to extract elements from.

    .PARAMETER Node
        The XPath node to select elements from. Default is "//a[@href]".

    .PARAMETER timeoutSec
        The timeout in seconds for the HTTP request. Default is 10 seconds.

    .PARAMETER onlyDomains
        If specified, only the domains will be returned.

    .PARAMETER Type
        The type of elements to return. Valid values are "Href", "noHref", "onlyDomains", and "All". Default is "All".

    .PARAMETER userAgent
        The user agent string to use for the HTTP request. Default is "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36 Edg/117.0.2045.43".

    .EXAMPLE
        Get-PSWCAllElements -url "https://www.example.com" -Type "All"

        This example extracts all elements from the URL "https://www.example.com".
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$url,
        [string]$Node = "//a[@href]",
        [int]$timeoutSec = 10,
        [switch]$onlyDomains,
        [ValidateSet("Href", "noHref", "onlyDomains", "All")]
        [string]$Type = "All",
        [string]$userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/117.0.0.0 Safari/537.36 Edg/117.0.2045.43"
    )
    begin {

        # Initialize arrays to store the results.
        $domains = @()
        $hrefElements = @()
        $nonhrefElements = @()
        $internalLinks = @()

    }
    process {
        # If onlyDomains switch is present, get the domain from the URL.
        if ($onlyDomains.IsPresent) {
            $url = Get-PSWCSchemeAndDomain -Url $url
        }
        # Send an HTTP GET request to the URL
        $response = Get-PSWCHttpResponse -url $url -userAgent $userAgent -timeout $timeoutSec
        Write-Log "Got response from [$url]"

        # If the HTTP request is successful, extract the elements from the HTML content.
        if ($response[1].IsSuccessStatusCode) {
            Write-Log "Response [$($response[1].StatusCode)] succeded from [$url] "
            $htmlContent = $response[1].Content.ReadAsStringAsync().Result
            # Extract all anchor elements from the HTML document
            $anchorElements = Get-PSWCDocumentElements -htmlContent $htmlContent -Node $Node

            # If there are anchor elements, extract the Href and non-Href elements.
            if ($anchorElements[1].count -gt 0) {
                foreach ($anchorElement in $anchorElements[1]) {
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
                        if ($href -match "^/|^\.\./") {
                            $internalLink = [System.Uri]::new([System.Uri]::new($url), $href)
                            $internalLinks += $internalLink.AbsoluteUri
                        }
                        $nonhrefelements += $href
                    }
                }
                # Output the results based on the Type parameter.
                $domainsunique = $domains | Select-Object -Unique | Sort-Object
                $hrefsUnique = $hrefelements | Select-Object -Unique | Sort-Object
                $nonhrefsUnique = $nonhrefelements | Select-Object -Unique | Sort-Object
                $internalLinksUnique = $internalLinks | Select-Object -Unique | sort-object
                switch ($Type) {
                    "href" {
                        
                        Write-Host "Href elements: $($hrefsUnique.count)" -ForegroundColor Yellow
                        
                        #$hrefsUnique | Add-Content -Path (join-path $CurrentDomainSessionFolder $(Set-PSWCCleanWebsiteURL -url $url) )

                        $UrlsFullName = Join-Path -Path $script:SessionFolder -ChildPath "UrlsUnique.txt"
                        $hrefsUnique | Out-File -FilePath $UrlsFullName -Encoding utf8

                        Write-Host "`nFiles Saved at:" -ForegroundColor Cyan
                        Write-Host "- Hrefs: $UrlsFullName" -ForegroundColor Cyan

                    }
                    "nohref" {
                        Write-Host "no Href elements: $($nonhrefsUnique.count)"   -ForegroundColor Yellow
                        #$nonhrefelements | Where-Object { $_ -notin ("", "/", "#") } | Select-Object -Unique | sort-object
                        $noUrlsFullName = Join-Path -Path $script:SessionFolder -ChildPath "noHrefUnique.txt"
                        $nonhrefsUnique | Out-File -FilePath $noUrlsFullName -Encoding utf8

                        Write-Host "no Href elements as absolute links: $($internalLinksUnique.count)"   -ForegroundColor Yellow
                        $InternalLinksFullName = Join-Path -Path $script:SessionFolder -ChildPath "InternalLinksUnique.txt"
                        $internalLinksUnique | Out-File -FilePath $InternalLinksFullName -Encoding utf8

                        Write-Host "`nFiles Saved at:" -ForegroundColor Cyan
                        Write-Host "- no Href: $noUrlsFullName" -ForegroundColor Cyan
                        Write-Host "- no Href elements as absolute links: $InternalLinksFullName" -ForegroundColor Cyan

                    }
                    "onlyDomains" {
                        Write-Host "Domains elements: $($domainsunique.count)"   -ForegroundColor Yellow
                        #$domains | Select-Object -Unique | sort-object
                        $DomainsFullName = Join-Path -Path $script:SessionFolder -ChildPath "DomainsUnique.txt"
                        $domainsunique | Out-File -FilePath $DomainsFullName -Encoding utf8

                        Write-Host "`nFiles Saved at:" -ForegroundColor Cyan
                        Write-Host "- Domains: $DomainsFullName" -ForegroundColor Cyan

                    }
                    "All" {
                        Write-Host "All elements: " -ForegroundColor Yellow

                        Write-Host "Href elements: $($hrefsUnique.count)" -ForegroundColor Yellow
                        #$hrefsUnique | Add-Content -Path (join-path $CurrentDomainSessionFolder $(Set-PSWCCleanWebsiteURL -url $url) )
                        $UrlsFullName = Join-Path -Path $script:SessionFolder -ChildPath "UrlsUnique.txt"
                        $hrefsUnique | Out-File -FilePath $UrlsFullName -Encoding utf8

                        Write-Host "no Href elements: $($nonhrefsUnique.count)"   -ForegroundColor Yellow
                        #$nonhrefelements | Where-Object { $_ -notin ("", "/", "#") } | Select-Object -Unique | sort-object
                        $noUrlsFullName = Join-Path -Path $script:SessionFolder -ChildPath "noHrefUnique.txt"
                        $nonhrefsUnique | Out-File -FilePath $noUrlsFullName -Encoding utf8

                        Write-Host "no Href elements as absolute links: $($internalLinksUnique.count)"   -ForegroundColor Yellow
                        $InternalLinksFullName = Join-Path -Path $script:SessionFolder -ChildPath "InternalLinksUnique.txt"
                        $internalLinksUnique | Out-File -FilePath $InternalLinksFullName -Encoding utf8

                        Write-Host "Domains elements: $($domainsunique.count)"   -ForegroundColor Yellow
                        #$domains | Select-Object -Unique | sort-object
                        $DomainsFullName = Join-Path -Path $script:SessionFolder -ChildPath "DomainsUnique.txt"
                        $domainsunique | Out-File -FilePath $DomainsFullName -Encoding utf8

                        Write-Host "`nFiles Saved at:" -ForegroundColor Cyan
                        Write-Host "- Hrefs: $UrlsFullName" -ForegroundColor Cyan
                        Write-Host "- no Href: $noUrlsFullName" -ForegroundColor Cyan
                        Write-Host "- no Href elements as absolute links: $InternalLinksFullName" -ForegroundColor Cyan
                        Write-Host "- Domains: $DomainsFullName" -ForegroundColor Cyan

                    }
                    Default {}
                }
                Write-Host "- Setting log: $(Join-Path $script:SessionFolder "Settings.log")" -ForegroundColor Cyan

                # Output the results to the log.
                Write-Log "Hrefs (w/o domains) count: [$($hrefelements.count)], unique: $(($hrefsUnique).count)"
                Write-Log "no-Hrefs (w/o domains) count: [$($nonhrefelements.count)], unique: $(($nonhrefsUnique).count)"
                Write-Log "Domain count: [$($domains.count)], unique: $(($domainsUnique).count)"
                Write-Log "no-Hrefs as absolute links count: [$($internalLinks.count)], unique: $(($internalLinksUnique).count)"
    
            } 
            else {
                Write-Host "No elements in '$url'" -ForegroundColor Red    
                Write-Log "No elements in '$url'"
            }
        }
        else {
            Write-Host "HTTP request failed for URL: '$url'." -ForegroundColor Red
            if ($response.StatusCode) {
                Write-Host "Status code: $($response.StatusCode)" -ForegroundColor DarkRed
            }
        }
    }
    end {
        #if ($anchorElements[1].count -gt 0) {

        #}
    }
}

function Get-PSWCImageUrls {
    <#
    .SYNOPSIS
        Retrieves the URLs of all images in an HTML document.
    .DESCRIPTION
        This function retrieves the URLs of all images in an HTML document using the HtmlAgilityPack library.
    .PARAMETER HtmlContent
        The HTML content to search for images.
    .PARAMETER url
        The base URL of the HTML content.
    .PARAMETER SelectQuery
        The XPath query to select the image nodes. Defaults to "//img".
    .EXAMPLE
        PS> Get-PSWCImageUrls -HtmlContent $html -url "https://example.com"
        Retrieves the URLs of all images in the $html content.
    #>

    param (
        [Parameter(Mandatory = $true, ValueFromPipeline)]
        [string]$HtmlContent,

        [string]
        $url,

        [Parameter(Mandatory = $false)]
        [string]$SelectQuery = "//img"
    )

    try {
        $doc = New-Object HtmlAgilityPack.HtmlDocument
        $doc.LoadHtml($HtmlContent)

        $imageUrls = @()

        $selectedNodes = $doc.DocumentNode.SelectNodes($SelectQuery)
        if ($selectedNodes) {
            foreach ($node in $selectedNodes) {
                $src = $node.GetAttributeValue("src", "")
                if (![string]::IsNullOrWhiteSpace($src)) {
                    if ($src -match "^https?://") {
                        $imageUrls += $src                            <# Action to perform if the condition is true #>
                    }
                    elseif ($src -match "^/|^\.\./") {
                        $internalUrl = [System.Uri]::new([System.Uri]::new($url), $src)
                        $imageUrls += $internalUrl.AbsoluteUri
                    }
                    else {
                        $imageUrls += $src
                    }
                }
            }
        }

        $imageUrls
    }
    catch {
        Write-Error "An error occurred: $_"
    }
}

Function Get-PSWCHTMLMetadata {
    <#
    .SYNOPSIS
    Extracts metadata from an HTML document.

    .DESCRIPTION
    The Get-PSWCHTMLMetadata function extracts metadata (title, description, keywords, author, copyright, robots, viewport, generator) from an HTML document.

    .PARAMETER htmlContent
    Specifies the HTML content to extract metadata from.

    .EXAMPLE
    $htmlContent = Get-Content -Path "C:\path\to\index.html" -Raw
    $metadata = Get-PSWCHTMLMetadata -htmlContent $htmlContent
    $metadata
    Retrieves the metadata from the specified HTML content and displays it.

    .NOTES
    Author: scripsavvyninja
    Date: 25.11.2023
    #>

    param (
        [string]$htmlContent
    )
    
    # Create a new HtmlDocument
    $htmlDocument = New-Object HtmlAgilityPack.HtmlDocument

    # Load the HTML content
    $htmlDocument.LoadHtml($htmlContent)

    # Initialize metadata hashtable
    $metadata = @{}

    # Extract title
    $titleNode = $htmlDocument.DocumentNode.SelectSingleNode("//title")
    if ($titleNode) {
        $metadata['Title'] = $titleNode.InnerText
    }
    else {
        $metadata['Title'] = ""
    }

    # Extract description
    $descriptionNode = $htmlDocument.DocumentNode.SelectSingleNode("//meta[@name='description']")
    if ($descriptionNode) {
        $metadata['Description'] = $descriptionNode.GetAttributeValue("content", "")
    }
    else {
        $metadata['Description'] = ""
    }

    # Extract keywords
    $keywordsNode = $htmlDocument.DocumentNode.SelectSingleNode("//meta[@name='keywords']")
    if ($keywordsNode) {
        $metadata['Keywords'] = $keywordsNode.GetAttributeValue("content", "")
    }
    else {
        $metadata['Keywords'] = ""
    }

    # Extract author
    $keywordsNode = $htmlDocument.DocumentNode.SelectSingleNode("//meta[@name='author']")
    if ($keywordsNode) {
        $metadata['Author'] = $keywordsNode.GetAttributeValue("content", "")
    }
    else {
        $metadata['Author'] = ""
    }
    
    # Extract copyright
    $keywordsNode = $htmlDocument.DocumentNode.SelectSingleNode("//meta[@name='copyright']")
    if ($keywordsNode) {
        $metadata['Copyright'] = $keywordsNode.GetAttributeValue("content", "")
    }
    else {
        $metadata['Copyright'] = ""
    }
    
    # Extract robots
    $keywordsNode = $htmlDocument.DocumentNode.SelectSingleNode("//meta[@name='robots']")
    if ($keywordsNode) {
        $metadata['Robots'] = $keywordsNode.GetAttributeValue("content", "")
    }
    else {
        $metadata['Robots'] = ""
    }

    # Extract viewport
    $keywordsNode = $htmlDocument.DocumentNode.SelectSingleNode("//meta[@name='viewport']")
    if ($keywordsNode) {
        $metadata['Viewport'] = $keywordsNode.GetAttributeValue("content", "")
    }
    else {
        $metadata['Viewport'] = ""
    }

    # Extract generator
    $keywordsNode = $htmlDocument.DocumentNode.SelectSingleNode("//meta[@name='generator']")
    if ($keywordsNode) {
        $metadata['Generator'] = $keywordsNode.GetAttributeValue("content", "")
    }
    else {
        $metadata['Generator'] = ""
    }

    # Return the metadata
    return $metadata
}

function Get-PSWCGetHostAddresses {
    param (
        [string]$domain
    )
    return ([System.Net.Dns]::GetHostAddresses($domain)).IPAddressToString
    #return (Resolve-DnsName $domain -NoHostsFile).ipaddress
}

Function Get-PSWCContactInformation {
    <#
    .SYNOPSIS
    Extracts contact information from an HTML document.

    .DESCRIPTION
    The Get-PSWCContactInformation function extracts contact information (emails, addresses, phone numbers) from an HTML document.

    .PARAMETER htmlContent
    Specifies the HTML content to extract contact information from.

    .EXAMPLE
    $htmlContent = Get-Content -Path "C:\path\to\index.html" -Raw
    $contactInfo = Get-PSWCContactInformation -htmlContent $htmlContent
    $contactInfo
    Retrieves the contact information from the specified HTML content and displays it.

    .NOTES
    Author: scripsavvyninja
    Date: 25.11.2023
    #>

    param (
        [string]$htmlContent
    )
    
    # Create a new HtmlDocument
    $htmlDocument = New-Object HtmlAgilityPack.HtmlDocument

    # Load the HTML content
    $htmlDocument.LoadHtml($htmlContent)

    # Initialize contact information hashtable
    $contactInfo = @{}

    # Extract emails
    $emailNodes = $htmlDocument.DocumentNode.SelectNodes('//a[starts-with(@href, "mailto:")]')
    if ($emailNodes) {
        $contactInfo['Emails'] = $emailNodes | ForEach-Object { $_.GetAttributeValue("href", "").Replace("mailto:", "") }
    }

    # Extract addresses
    $addressNodes = $htmlDocument.DocumentNode.SelectNodes('//address')
    if ($addressNodes) {
        $contactInfo['Addresses'] = $addressNodes | ForEach-Object { $_.InnerText }
    }

    # Extract phone numbers
    $phoneNodes = $htmlDocument.DocumentNode.SelectNodes('//a[starts-with(@href, "tel:")]')
    if ($phoneNodes) {
        $contactInfo['PhoneNumbers'] = $phoneNodes | ForEach-Object { $_.GetAttributeValue("href", "").Replace("tel:", "") }
    }

    # Return the contact information
    return $contactInfo
}

Function Get-PSWCHeadersAndValues {
    <#
    .SYNOPSIS
    Extracts headers and their values from an HTML document.

    .DESCRIPTION
    The Get-PSWCHeadersAndValues function extracts headers and their corresponding values from the `<head>` section of an HTML document.

    .PARAMETER htmlContent
    Specifies the HTML content to extract headers and values from.

    .EXAMPLE
    $htmlContent = Get-Content -Path "C:\path\to\index.html" -Raw
    $headersAndValues = Get-PSWCHeadersAndValues -htmlContent $htmlContent
    $headersAndValues
    Retrieves the headers and their values from the specified HTML content and displays them.

    .NOTES
    Author: scripsavvyninja
    Date: 25.11.2023
    #>

    param (
        [string]$htmlContent
    )

    # Create a new HtmlDocument
    $htmlDocument = New-Object HtmlAgilityPack.HtmlDocument

    # Load the HTML content
    $htmlDocument.LoadHtml($htmlContent)

    # Initialize a hashtable to store headers and their values
    $headersAndValues = @{}

    # Extract headers and values
    $headerNodes = $htmlDocument.DocumentNode.SelectNodes('//head/meta[@name]')
    if ($headerNodes) {
        foreach ($node in $headerNodes) {
            $name = $node.GetAttributeValue("name", "")
            $content = $node.GetAttributeValue("content", "")
            $headersAndValues[$name] = $content
        }
    }

    # Return the headers and values
    return $headersAndValues
}

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
        [switch]$resolve,
        [string]$userAgent = (get-RandomUserAgent)
    )

    $outputFile = ""
    if ($outputFolder) { 
        $outputFile = join-path $script:SessionFolder -ChildPath (Set-PSWCCleanWebsiteURL -url $url) 
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

    if ($onlyDomains.IsPresent) {
        $url = Get-PSWCSchemeAndDomain -url $url
        #write-verbose "create `$url as Get-PSWCSchemeAndDomain -url '$url'"
    }

    if ($script:ArrayData.url.Contains($url)) {
        # why?
        Write-Log "[Arraydata] url contains '$url' "
        try {
            # Send an HTTP GET request to the URL
            $response = Get-PSWCHttpResponse -url $url -userAgent "$userAgent" -timeout $timeoutSec
            Write-Log "Got response from [$url] "
            #$response | ConvertTo-Json

            # Check if the request was successful
            if ($response[1].IsSuccessStatusCode) {
                Write-Log "Response succeded from [$url] "
                #write-verbose "`$response.IsSuccessStatusCode for '$url': $($response.IsSuccessStatusCode)"
                $htmlContent = $response[1].Content.ReadAsStringAsync().Result

                if ($outputFolder -ne "") {

                    #Convert HTML2Text - PSparseHTML
                    Convert-HTMLToText -Content ($htmlContent) -OutputFile ([string]::Concat($outputFile, "$(get-date -Format "HHmmss").ConvertedtoTextContent.txt")) -ErrorAction SilentlyContinue -warningaction SilentlyContinue

                    #format HTML - PSparseHTML
                    $formatedContent = Format-HTML -Content $htmlContent -RemoveHTMLComments -RemoveOptionalTags -RemoveEmptyBlocks -RemoveEmptyAttributes -AlphabeticallyOrderAttributes
                    $formatedContentFileFullName = ([string]::Concat($outputFile, "$(get-date -Format "HHmmss").FormatedHTMLContent.txt"))
                    Out-File -FilePath $formatedContentFileFullName -InputObject $formatedContent        
                }

                $responseHeaders = $response[1].Headers | ConvertTo-Json  # Capture response headers

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

                if (-not ($anchorElements[1] -and (($anchorElements[1].GetAttributeValue("href", "")) -match "^https?://"))) {
                    # This code is checking if the second element in the $anchorElements array exists and if the href attribute of that element matches the regex pattern "^https?://"
                    # If the condition is not true, the code will continue to the next iteration of the loop
                    continue
                }

                # Get the domain of the current URL
                $currentDomain = [System.Uri]::new($url).Host
                $script:CurrentDomainSessionFolder = Set-PSWCSessionFolder -FolderPath $script:SessionFolder -FolderName $currentDomain
                Write-Log "Current domain is [$currentDomain]"
                #Write-Verbose "`$currentDomain: '$currentDomain', Domains: $domains"

                # wykryte domeny w linkach
                $domains = @()
                Write-Log "Created empty array [domains]"

                if (-not $onlyDomains.IsPresent) {

                    Write-Verbose "processing hreflinks from '$url'..."
                        
                    # Iterate over the anchor elements and extract the href attributes
                    foreach ($anchorElement in $anchorElements[1]) {
                        $href = $anchorElement.GetAttributeValue("href", "")
    
                        # remove from hreflinks
                        $hrefcontains = @("^mailto:", "^tel:", "^#")
                        $href = $href | Where-Object { $_ -notMatch ($hrefcontains -join "|") }
    
    
                        # Filter out non-HTTP links
                        if ($href -match "^https?://") {
                            <#                             if ($depth -eq 0) {
                                    # immediately returns the program flow to the top of a program loop
                                    continue
                                }
     #>                            # Add the link to the output file, if specified
                            if ($outputFolder -ne "") {
                                #$hrefFile = (Join-Path -Path $outputFolder -ChildPath (Set-PSWCCleanWebsiteURL -Url $url)) + ".hrefs.txt"
                                #Add-Content -Path ([string]::Concat($outputFile, ".hrefs.txt")) -Value $href
                                Add-Content -Path (join-path $CurrentDomainSessionFolder $(Set-PSWCCleanWebsiteURL -url $url) ) -Value $href
                            }
                                
                            # Get the domain of the linked URL
                            $linkedDomain = [System.Uri]::new($href).Host

                            # Check if the linked domain is different from the current domain
                            if ($linkedDomain -ne $currentDomain -and -not $noCrawlExternalLinks -and -not $script:ArrayData.href.Contains($href)) {

                                Write-Log "[$currentDomain] is different then [$linkedDomain] and not [noCrawlExternalLinks]"
    
                                # Decrease the depth when moving to a different site
                                $newDepth = $depth - 1
    
                                if (-not ($script:ArrayData.url.contains($href))) {
                                    #Write-Host "`t[$depth] '$url' - [$newDepth] '$href'"
                                    $thisobject = [PSCustomObject] @{
                                        Depth     = $depth
                                        Url       = $href
                                        Domain    = ""
                                        Href      = ""
                                        UrlServer = ""
                                        Date      = (get-date)
                                    }
                                    $script:ArrayData += $thisobject
                                    Write-Log "Depth:[$depth] and url:[$href] added to ArrayData"
                                }
    
                                Write-Log "Newdepth is [$newDepth]"
    
                                $domains += $hrefdomain
                                Write-Log "[$href] added to [domains] list"
                                if (-not ($script:ArrayData.domain.contains($href))) {
                                    $server = $response[1].Headers.Server -join "; "
                                    if ($server -eq "") {
                                        $server = "no data"
                                    }
                                    #$server_ = $server.count
                                    #write-host "[${server}]"
                                    $thisobject = [PSCustomObject] @{
                                        Depth     = $depth
                                        Url       = $url
                                        Domain    = $linkedDomain
                                        Href      = $href
                                        UrlServer = $server
                                        Date      = (get-date)
                                    }
                                    $script:ArrayData += $thisobject
                                    Write-Log "Depth: [$depth], url: [$url], domain: [$linkedDomain], href: [$href], server: [$server] added to ArrayData"
                                }
                                    
                                if ($depth -le 1) {
                                    # immediately returns the program flow to the top of a program loop
                                    Write-Log "Depth is 0; skipping [$href]"
                                    continue
                                }
    
                                Write-Log "start iteration for [$href]"

                                $CrawlingStartTimestamp = get-date 
                                Write-host "`nTimestamp: $CrawlingStartTimestamp" -ForegroundColor Yellow
                                Write-host "URL: $href" -ForegroundColor Magenta
                                if ($resolve.IsPresent) {
                                    $ResolveIPs = ""
                                    $ResolveIPs = (Get-PSWCGetHostAddresses -domain ([System.Uri]::new($href).Host))
                                    #$ResolveIPs = (Get-PSWCGetHostAddresses -domain $url)
                                    Write-Host "IP address: $ResolveIPs" -ForegroundColor Cyan
                                }
                                Write-Host "Crawling depth: $newdepth" -ForegroundColor Blue
                    

                                #Write-Host "Crawling depth: $newdepth"
                                #Write-host "Crawling: $href"
                                #Write-host "Status: In progress"
                                #$CrawlingStartTimestamp = get-date 
                                #Write-host "Timestamp: $CrawlingStartTimestamp"

                                Start-PSWCCrawl -url $href -depth $newDepth -timeoutSec $timeoutSec -outputFolder $outputFolder -statusCodeVerbose:$statusCodeVerbose -noCrawlExternalLinks:$noCrawlExternalLinks -userAgent $userAgent -onlyDomains:$onlyDomains -verbose:$verbose -debug:$debug
                                
                                #Write-Host "Crawling depth: $newdepth"
                                #Write-host "Crawling: $href"
                                #Write-host "Status: Completed"
                                #$CrawlingCompletedTimestamp = get-date 
                                #Write-host "Timestamp: $CrawlingCompletedTimestamp"
                            }
                            else {
                                $newDepth = $depth
                                Write-Log "Newdepth is [$newDepth]"
    
                            }
        
                            # Add the link to the list of links to crawl
                            #Write-Verbose "Found link: $href (Depth: $newDepth)"
                                
                            # Recursively crawl with the adjusted depth
                            #Start-PSWCCrawl -url $href -depth $newDepth -timeoutSec $timeoutSec -outputFolder $outputFolder -verbose:$verbose -statusCodeVerbose:$statusCodeVerbose -noCrawlExternalLinks:$noCrawlExternalLinks -userAgent $userAgent -onlyDomains:$onlyDomains
                            #Start-PSWCCrawl -url $href -depth $newDepth -timeoutSec $timeoutSec -outputFolder $outputFolder -statusCodeVerbose:$statusCodeVerbose -noCrawlExternalLinks:$noCrawlExternalLinks -userAgent $userAgent -onlyDomains:$onlyDomains -verbose:$verbose -debug:$debug
    
                        }
                        else {
                            # Add the link to the output file, if specified
                            if ($outputFolder -ne "") {
                                #$hrefFile = (Join-Path -Path $outputFolder -ChildPath $(Set-PSWCCleanWebsiteURL -Url $url)) + ".hrefs.anchorElement.txt"
                                Add-Content -Path ([string]::Concat($outputFile, ".hrefs.anchorElement.txt")) -Value $href
                            }
                        }
                    }
    
                }
                else {

                    Write-Verbose "processing onlydomains url from '$url'..."
                    # Iterate over the anchor elements and extract the href attributes - only domains
                    foreach ($anchorElement in $anchorElements[1]) {
                        $href = $anchorElement.GetAttributeValue("href", "")
                        #Write-Verbose " processing '$href'..."
                        #Write-Log "analyze element [$href]"

                        # remove from hreflinks
                        $hrefcontains = @("^mailto:", "^tel:", "^#")
                        $href = $href | Where-Object { $_ -notMatch ($hrefcontains -join "|") }

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
                                #Add-Content -Path ([string]::Concat($outputFile, ".hrefs.txt")) -Value $href
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

                                # Decrease the depth when moving to a different site
                                $newDepth = $depth - 1

                                if (-not ($script:ArrayData.url.contains($hrefdomain))) {
                                    #Write-Host "  [$depth] ['$url' - [$newDepth] '$hrefdomain']"
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
                                if ($depth -le 1) {
                                    # immediately returns the program flow to the top of a program loop
                                    Write-Log "Depth is 0; skipping [$hrefDomain]"
                                    continue
                                }

                                $CrawlingStartTimestamp = get-date 
                                Write-host "`nTimestamp: $CrawlingStartTimestamp" -ForegroundColor Yellow
                                Write-host "URL: $hrefDomain" -ForegroundColor Magenta
                                #resolve to IP address
                                if ($resolve.IsPresent) {
                                    $ResolveIPs = ""
                                    $ResolveIPs = (Get-PSWCGetHostAddresses -domain ([System.Uri]::new($hrefDomain).Host))
                                    #$ResolveIPs = (Get-PSWCGetHostAddresses -domain $url)
                                    Write-Host "IP address: $ResolveIPs" -ForegroundColor Cyan
                                }
                                Write-Host "Crawling depth: $newdepth" -ForegroundColor Blue

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
                Write-Log "Response from [$url] was not successful"
                Write-Host "HTTP request failed for URL: $url." -ForegroundColor DarkRed
                if ($response.StatusCode) {
                    Write-Host "Status code: $($response.StatusCode)" -ForegroundColor DarkRed
                }
                else {
                    Write-Host "Verify URL and try again." -ForegroundColor Red
                    break
                }
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
        if ($onlyDomains) {
            Write-Verbose "Already processed domain: '$url'" -verbose
        }
        else {
            Write-Verbose "Already processed href: '$url'" -verbose
        }
        Write-Log "[$url] was skipped"
        continue
    }

}

function Get-PSWCHttpResponse {
    <#
    .SYNOPSIS
    Sends an HTTP GET request and retrieves the response.

    .DESCRIPTION
    The Get-PSWCHttpResponse function sends an HTTP GET request to the specified URL and retrieves the response.

    .PARAMETER url
    Specifies the URL to send the HTTP GET request to.

    .PARAMETER userAgent
    Specifies the User-Agent header to use in the HTTP request. Defaults to a Chrome User-Agent string.

    .PARAMETER timeout
    Specifies the number of seconds to wait for a response before timing out. Defaults to 10 seconds.

    .EXAMPLE
    $url = "https://www.example.com"
    $response = Get-PSWCHttpResponse -url $url
    $response
    Sends an HTTP GET request to the specified URL and retrieves the response.

    .NOTES
    Author: scripsavvyninja
    Date: 25.11.2023
    #>

    param (
        [string]$url,
        [string]$userAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36 Edg/118.0.2088.57",
        [int]$timeout = 10
    )

    # This function is called Get-PSWCHttpResponse and takes in three parameters: $url, $userAgent, and $timeout.
    # $url is a string that represents the URL to send an HTTP GET request to.
    # $userAgent is a string that represents the User-Agent header to use in the HTTP request. It defaults to a Chrome User-Agent string.
    # $timeout is an integer that represents the number of seconds to wait for a response before timing out. It defaults to 10 seconds.
    

    # Create an HttpClient with a custom User-Agent header
    try {
        $httpClient = New-Object System.Net.Http.HttpClient
        $httpClient.DefaultRequestHeaders.Add("User-Agent", $userAgent)
        # Set the timeout for the HttpClient
        $httpClient.Timeout = [System.TimeSpan]::FromSeconds($timeout)
        # Send an HTTP GET request to the URL
        $response = $httpClient.GetAsync($url).Result # Stored the response in a variable before returning it
    }
    catch {
        # some user-agents (i.e. "Mozilla/4.0 (compatible; MSIE 6.0; Windows CE; IEMobile 7.11) Sprint:PPC6800") generate error 
        $httpClient.Timeout = [System.TimeSpan]::FromSeconds($timeout)
        # Send an HTTP GET request to the URL
        $response = $httpClient.GetAsync($url).Result # Stored the response in a variable before returning it

    }
    # Return the HttpClient instance and the response
    return $httpClient, $response

    # The function creates an instance of the HttpClient class and sets the User-Agent header to the value of $userAgent.
    # It then sets the timeout for the HttpClient to the value of $timeout.
    # Finally, it sends an HTTP GET request to the URL specified in $url and stores the response in the $response variable.
    # The function then returns both the HttpClient instance and the response.
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
    return $htmlDocument, $rootXmlNode.SelectNodes($Node)
}

function Set-PSWCCleanWebsiteURL {
    <#
    .SYNOPSIS
    Cleans an array of website URLs by removing "http://" or "https://" and replacing non-letter and non-digit characters with underscores.

    .DESCRIPTION
    The Set-PSWCCleanWebsiteURL function takes an array of website URLs as input, removes "http://" or "https://" from each URL, and replaces all characters that are not digits or letters with underscores. It then returns an array of cleaned URLs.

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
    <#
    .SYNOPSIS
    Extracts the scheme and domain from a given URL.

    .DESCRIPTION
    The Get-PSWCSchemeAndDomain function takes a URL as input and extracts the scheme (e.g., "http" or "https") and the domain (e.g., "www.example.com") from it.

    .PARAMETER url
    Specifies the URL from which to extract the scheme and domain.

    .EXAMPLE
    $url = "https://www.example.com/path/to/page"
    $schemeAndDomain = Get-PSWCSchemeAndDomain -url $url
    Write-Host "Scheme and Domain: $schemeAndDomain"
    
    This example extracts the scheme and domain from the provided URL and displays it.

    .NOTES
    Author         : Wojciech Napierała (@scriptsavvyninja)
    Date           : 25.11.2023
    #>

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

function New-PSWCoutPath {
    <#
    .SYNOPSIS
    Gets the output path for PSWebCrawler.

    .DESCRIPTION
    The Get-PSWCoutPath function retrieves the output path for PSWebCrawler based on the specified folder name and type.

    .PARAMETER FolderName
    Specifies the name of the output folder.

    .PARAMETER Type
    Specifies the type of the output folder. Default value is "UserDoc".

    .EXAMPLE
    Get-PSWCoutPath -FolderName "OutputFolder" -Type "UserDoc"
    Retrieves the output path for the "OutputFolder" under the user's documents folder.

    .EXAMPLE
    Get-PSWCoutPath -FolderName "TempFolder" -Type "UserTEMP"
    Retrieves the output path for the "TempFolder" under the system's temporary folder.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [string]$FolderName,
        [ValidateSet("UserDoc", "UserTEMP")]
        [string]$Type = "UserDoc"
    )

    if ($Type -eq "UserDoc") {
        $outPathFolder = Join-Path ([Environment]::GetFolderPath("MyDocuments")) $FolderName
    }
    elseif ($Type -eq "UserTEMP") {
        $outPathFolder = Join-Path ([System.IO.Path]::GetTempPath()) $FolderName
    }

    if (-not (Get-PSWCoutPath -FolderName $FolderName -Type $type)) {
        try {
            [void](New-Item -Path $outPathFolder -ItemType Directory)
            Write-Verbose "Out log and data folder '$outPathFolder' was created successfully."
            return $outPathFolder
        }
        catch {
            Write-Error "Error creating cache folder. [$($_.error.message)]"
            return $false
        }
    }
    return $outPathFolder
}

function Get-PSWCoutPath {
    <#
    .SYNOPSIS
    Gets the output path for PSWebCrawler.

    .DESCRIPTION
    The Get-PSWCoutPath function retrieves the output path for PSWebCrawler based on the specified folder name and type.

    .PARAMETER FolderName
    Specifies the name of the output folder.

    .PARAMETER Type
    Specifies the type of the output folder. Default value is "UserDoc".

    .EXAMPLE
    Get-PSWCoutPath -FolderName "OutputFolder" -Type "UserDoc"
    Retrieves the output path for the "OutputFolder" under the user's documents folder.

    .EXAMPLE
    Get-PSWCoutPath -FolderName "TempFolder" -Type "UserTEMP"
    Retrieves the output path for the "TempFolder" under the system's temporary folder.
    #>

    param (
        [Parameter(Mandatory = $true)]
        [string]$FolderName,
        [ValidateSet("UserDoc", "UserTEMP")]
        [string]$Type = "UserDoc"
    )

    if ($Type -eq "UserDoc") {
        $outPathFolder = Join-Path ([Environment]::GetFolderPath("MyDocuments")) $FolderName
    }
    elseif ($Type -eq "UserTEMP") {
        $outPathFolder = Join-Path ([System.IO.Path]::GetTempPath()) $FolderName
    }

    if (Test-Path -Path $outPathFolder) {
        return $outPathFolder
    }
    return $false
}
<# function Set-PSWCDataFolder {
    $userDocumentFolder = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments)
    $moduleName = $MyInvocation.MyCommand.Module.Name
    $dataFolder = Join-Path $userDocumentFolder $moduleName

    #Write-Verbose $dataFolder -Verbose
    if (-not (Test-Path -Path $dataFolder)) {
        New-Item -Path $dataFolder -ItemType Directory | Out-Null
    }
    return $dataFolder
}
 #>

function Set-PSWCSessionFolder {
    <#
    .SYNOPSIS
    Creates a session folder for storing web crawling session data.

    .DESCRIPTION
    The Set-PSWCSessionFolder function creates a session folder with the specified name at the specified path for storing web crawling session data. If the folder already exists, it does not create a new one.

    .PARAMETER FolderName
    Specifies the name of the session folder to be created.

    .PARAMETER FolderPath
    Specifies the path where the session folder will be created.

    .EXAMPLE
    Set-PSWCSessionFolder -FolderName "Session1" -FolderPath "C:\WebCrawlingSessions"
    Creates a session folder named "Session1" at the specified path "C:\WebCrawlingSessions".
    #>

    param (
        [string]$FolderName,
        [string]$FolderPath
    )
    $script:SessionFolder = Join-Path $FolderPath $FolderName
    if (-not (Test-Path -Path $script:SessionFolder)) {
        try {
            [void](New-Item -Path $script:SessionFolder -ItemType Directory)
            Write-Verbose "Session folder '$script:SessionFolder' was created successfully."
            return $script:SessionFolder
        }
        catch {
            Write-Error "Error creating session folder. [$($_.error.message)]"
            return $false
        }
    }
    return $script:SessionFolder
}


function Open-PSWCExplorerCache {
    <#
    .SYNOPSIS
    Opens the cache folder in Windows File Explorer.

    .DESCRIPTION
    The Open-PSWCExplorerCache function opens the cache folder in Windows File Explorer. It takes the name of the folder as input and attempts to start the Windows File Explorer process with the specified folder path as an argument. If the folder does not exist, it creates a new cache folder and then opens it in Windows File Explorer.

    .PARAMETER FolderName
    Specifies the name of the cache folder to be opened.

    .EXAMPLE
    Open-PSWCExplorerCache -FolderName "Cache1"
    Opens the cache folder named "Cache1" in Windows File Explorer.
    #>
    param (
        [string]$FolderName
    )
    $tempfolder = $script:loganddatafolderPath
    #$tempfolderFullName = Join-Path $tempfolder $FolderName
    $tempfolderFullName = $tempfolder
    if (test-path $tempfolderFullName) {
        try {
            Start-Process explorer.exe -ArgumentList $tempfolderFullName
            Write-Log "Process [explorer.exe] was started with arguments [$tempfolderFullName]"

        }
        catch {
            Write-Error "An error starting process: $_"
            Write-Log "Process [explorer.exe] was not started with arguments [$tempfolderFullName]"
        }
    }
    else {
        New-PSWCoutPath -FolderName $FolderName
        Open-PSWCExplorerCache -FolderName $FolderName
        #Write-Information -InformationAction Continue -MessageData "Cache folder does not exist."
    }
}

function Write-Log {
    <#
    .SYNOPSIS
    Writes a log message to a log file with a timestamp.

    .DESCRIPTION
    The Write-Log function appends a log message to a log file with a timestamp. The log message is provided as the mandatory input parameter, and the log file path is an optional parameter. If the log file path is not specified, the function creates a log file in the user's temporary directory with the name of the module that contains the function.

    .PARAMETER logstring
    Specifies the log message to be written to the log file.

    .PARAMETER logFile
    Specifies the path to the log file. If not specified, the log file will be created in the user's temporary directory with the name of the module that contains the function.

    .EXAMPLE
    Write-Log -logstring "This is a log message"

    This example writes the log message "This is a log message" to the default log file in the user's temporary directory.

    .EXAMPLE
    Write-Log -logstring "Error occurred" -logFile "C:\Logs\MyLogFile.log"

    This example writes the log message "Error occurred" to the specified log file path "C:\Logs\MyLogFile.log".

    .NOTES
    Author: scriptsavvyninja
    Date: 25.11.2023
    #>

    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$logstring,
        [string]$logFile = (Join-Path $script:loganddatafolderPath "$($script:ModuleName).log")
    )

    try {
        if (-not (Test-Path -Path $logFile)) {
            New-Item -Path $logFile -ItemType File | Out-Null
        }
        # Create the log message with a timestamp
        $strToLog = "[{0}]: {1}" -f (Get-Date), $logstring
        # Append the log message to the log file
        Add-Content -Path $logFile -Value $strToLog -Encoding utf8 -Force
    }
    catch {
        Write-Error "Failed to write to the log file: $_"
    }
}

function Show-PSWCMenu {
    param (        
    )
    Write-Host "How to use, examples:" -ForegroundColor White
    Write-Host ""
    Write-Host "[1] Crawling two levels from the given URL, only domains from Hypertext Reference (HREF) are taken."
    Write-host "    If the 'outputFolder' parameter is not provided, the default output log and data folder path is set to the user's document folder under the 'PSWebCrawler' directory:"
    Write-Host "    PSWC -Url 'http://allafrica.com/tools/headlines/rdf/latest/headlines.rdf' -Depth 2 -onlyDomains" -ForegroundColor Green
    Write-Host ""
    Write-Host "[2] Crawling two levels from the given URL, only domains from Hypertext Reference (HREF) are taken, and resolves the domain names to IP addresses:"
    Write-Host "    PSWC -Url 'http://allafrica.com/tools/headlines/rdf/latest/headlines.rdf' -Depth 2 -onlyDomains -Resolve" -ForegroundColor Green  
    Write-Host ""
    Write-Host "[3] Crawling two levels from the given URL, only domains with Hypertext Reference (HREF) are taken. Output log and data folder path is given:"
    Write-Host "    PSWC -Url 'http://allafrica.com/tools/headlines/rdf/latest/headlines.rdf' -Depth 2 -onlyDomains -outputFolder 'c:\temp\crawl\loganddata\'" -ForegroundColor Green
    Write-Host ""
    Write-Host "[4] Retrieves all href elements from the URL:"
    Write-Host "    PSWC -ShowAllElements -Type All -Url 'https://www.w3schools.com/'" -ForegroundColor Green
    Write-Host ""
    Write-Host "[5] Retrieves the URLs of all images on the webpage:"
    Write-Host "    PSWC -GetImageUrls -url 'http://allafrica.com/tools/'" -ForegroundColor Green
    Write-Host ""
    Write-Host "[6] Shows metadata from an HTML document located at the specified URL:"
    Write-Host "    PSWC -GetHTMLMetadata -url 'http://allafrica.com/tools/headlines/rdf'" -ForegroundColor Green
    Write-Host ""
    Write-Host "[7] Shows contact information from an HTML document located at the specified URL:"
    Write-Host "    PSWC -GetContactInformation -Url 'https://games.com'" -ForegroundColor Green
    Write-Host ""
    Write-Host "[8] Shows headers and their corresponding values from an HTML document located at the specified URL:"
    Write-Host "    PSWC -GetHeadersAndValues -url 'http://allafrica.com'" -ForegroundColor Green
    Write-Host ""
    Write-Host "[9] Opens default log and data folder in Windows File Explorer:"
    Write-Host "    PSWC -ShowCacheFolder" -ForegroundColor Green
    Write-Host ""
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
        [Parameter(ParameterSetName = 'GetImageUrls', Mandatory = $true)]
        [Parameter(ParameterSetName = 'GetHTMLMetadata', Mandatory = $true)]
        [Parameter(ParameterSetName = 'GetContactInformation', Mandatory = $true)]
        [Parameter(ParameterSetName = 'GetHeadersAndValues', Mandatory = $true)]
        #[ValidateNotNullOrEmpty()]
        #[ValidatePattern('^https?://.*')]
        [string]$Url,

        [Parameter(ParameterSetName = 'ShowAllElements')]
        [switch]$ShowAllElements,

        [Parameter(ParameterSetName = 'ShowAllElements')]
        [ValidateSet("Href", "noHref", "onlyDomains", "All")]
        [string]$Type = "All",
        
        [Parameter(ParameterSetName = 'WebCrawl')]
        [int]$Depth = 2,

        [Parameter(ParameterSetName = 'WebCrawl')]
        [switch]$Resolve,

        [Parameter(ParameterSetName = 'ShowAllElements')]
        [Parameter(ParameterSetName = 'WebCrawl')]
        [switch]$onlyDomains,

        [Parameter(ParameterSetName = 'WebCrawl')]
        [string]$outputFolder = $script:loganddatafolderPath,

        [Parameter(ParameterSetName = 'ShowCacheFolder', Mandatory = $true)]
        [switch]$ShowCacheFolder,

        # Parameter help description
        [Parameter(ParameterSetName = 'GetImageUrls', Mandatory = $true)]
        [switch]
        $GetImageUrls,

        # Parameter help description
        [Parameter(ParameterSetName = 'GetHTMLMetadata', Mandatory = $true)]
        [switch]
        $GetHTMLMetadata,

        # Parameter help description
        [Parameter(ParameterSetName = 'GetContactInformation', Mandatory = $true)]
        [Switch]
        $GetContactInformation,

        # Parameter help description
        [Parameter(ParameterSetName = 'GetHeadersAndValues', Mandatory = $true)]
        [switch]
        $GetHeadersAndValues
        
    )
    # try {
    Get-PSWCBanner
    Write-Verbose "ParameterSetName: [$($PSCmdlet.ParameterSetName)]"
    Write-Log "Start; ParameterSetName: [$($PSCmdlet.ParameterSetName)]"

    if ($($PSCmdlet.ParameterSetName) -notin 'ShowCacheFolder', 'Default') {
        # Check if the URL is valid
        # The regex '^https?://[^/].*' checks if the URL starts with 'http://' or 'https://' and has at least one character after the domain name
        while ((-not ($Url -match '^https?://[^/].*')) -or [string]::IsNullOrEmpty($url)) {
            Write-Host "URL is not valid." -ForegroundColor Red
            $url = ""
            $url = Read-Host -Prompt "Provide valid URL"
        
            Write-Host ""
        }
    }
    # start measure execution of script
    $watch_ = start-watch

    # get random User-Agent
    $UserAgent = get-RandomUserAgent
    #$UserAgent = 'Mozilla/4.0 (compatible; MSIE 6.0; Windows CE; IEMobile 7.11) Sprint:PPC6800'

    if ($($PSCmdlet.ParameterSetName) -ne "Default") {
        $date = Get-Date -Format "dd-MM-yyyy-HH-mm-ss"
        try {
            $script:SessionFolder = Set-PSWCSessionFolder -FolderName $date -FolderPath $outputFolder
            Write-Log "Session folder '$script:SessionFolder' was created successfully."
        }
        catch {
            Write-Log "ERROR: Session folder '$script:SessionFolder' was NOT created."
        }
    }
        
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
            $outputfoldertext = $script:loganddatafolderPath
            Write-Log "[outputfoldertext] is set to [$script:loganddatafolderPath]"

            if (-not $verbose.IsPresent) {
                $verbose = $false
            }
                        
            Write-Host "Settings:" -ForegroundColor Gray 
            Write-Host "[+] Option: $($PSCmdlet.ParameterSetName)" -ForegroundColor DarkGray
            Write-Host "[+] Url: $Url" -ForegroundColor DarkGray
            Write-Host "[+] Depth: $depth" -ForegroundColor DarkGray
            write-host "[+] OnlyDomains: $onlydomains" -ForegroundColor DarkGray
            write-host "[+] Resolve: $resolve" -ForegroundColor DarkGray
            Write-Host "[+] Session folder path: $script:SessionFolder" -ForegroundColor DarkGray
            write-host "[+] Log output folder: $outputfoldertext" -ForegroundColor DarkGray
            write-host "[+] Log:" (Join-Path $script:loganddatafolderPath "$($script:ModuleName).log") -ForegroundColor DarkGray
            Write-Host "[+] Used UserAgent: '$UserAgent'" -ForegroundColor DarkGray
            Write-Host "[+] Invoking cli: '$($MyInvocation.Line)'" -ForegroundColor DarkGray
            Write-Host ""
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "Settings:"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Option: $($PSCmdlet.ParameterSetName)"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Url: $Url"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Depth: $depth" 
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] OnlyDomains: $onlydomains"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Resolve: $resolve"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Session folder path: $script:SessionFolder"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Log: $(Join-Path $script:loganddatafolderPath "$($script:ModuleName).log")"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Used UserAgent: '$UserAgent'"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Invoking cli: '$($MyInvocation.Line)'"

            #$script:historydomains += (Get-PSWCSchemeAndDomain -url $url)
            Write-Host "[Start Crawling] with '$url', depth: $depth`n" -ForegroundColor White
            Write-Log "Start iteration for [$url] with depth: [$depth]"

            $CrawlingStartTimestamp = get-date 
            Write-host "Timestamp: $CrawlingStartTimestamp" -ForegroundColor Yellow
            Write-host "URL: $url" -ForegroundColor Magenta
            if ($resolve.IsPresent) {
                $ResolveIPs = ""
                $ResolveIPs = (Get-PSWCGetHostAddresses -domain ([System.Uri]::new($url).Host))
                #$ResolveIPs = (Get-PSWCGetHostAddresses -domain $url)
                Write-Host "IP address: $ResolveIPs" -ForegroundColor Cyan
            }
            Write-Host "Crawling depth: $depth" -ForegroundColor Blue
            # Write-host "Status: In progress"

            # Start crawling the start URL
            Start-PSWCCrawl -url $Url -depth $depth -onlyDomains:$onlyDomains -outputFolder $outputFolder -resolve:$resolve -Verbose:$verbose -userAgent "$UserAgent"

            #Write-Host "Crawling depth: $depth"
            #Write-host "Crawling: $url"
            #Write-host "Status: Completed"
            #$CrawlingCompletedTimestamp = get-date 
            #Write-host "Timestamp: $CrawlingCompletedTimestamp"

            Write-Host "`n[End Crawling] Web crawling completed successfully.`n" -ForegroundColor White

            Write-Host "Summary:" -ForegroundColor Cyan
            $DomainsFound = ($ArrayData.domain | Where-Object { $_ } | Select-Object -Unique | Measure-Object).count
            $LinksFound = ($ArrayData | Where-Object { $_.href } | Select-Object href -Unique).count
            write-host "- Total Unique Domains: $DomainsFound" -ForegroundColor Cyan
            Write-Host "- Total Unique URLs: $LinksFound" -ForegroundColor Cyan

            Write-Host "`nFiles Saved at:" -ForegroundColor Cyan
            
            #Write-Host "`nLiczba sprawdzonych domen (var: historyDomains): " -NoNewline
            #($script:historyDomains | Select-Object -Unique | Measure-Object).count
            $DomainsFullName = Join-Path -Path $script:SessionFolder -ChildPath "UniqueDomain.txt"
            $ArrayData.domain | Where-Object { $_ } | Select-Object -Unique | Out-File -FilePath $DomainsFullName -Encoding utf8
            Write-Host "- Domains: $DomainsFullName" -ForegroundColor Cyan
            
            #($ArrayData | Where-Object { $_.Domain } | Select-Object domain -Unique | Sort-Object domain).domain -join "; "
                
            #Write-Host "sprawdzone domeny (po url; var: historyDomains):"
            #$script:historyDomains | Select-Object -Unique  | Sort-Object
            #$ArrayData | Where-Object { $_.Domain } | Select-Object depth, url, domain | Sort-Object url, domain
            #$ArrayData | Where-Object { $_.Domain } | Sort-Object url, domain | Select-Object url -Unique | Format-Table url
    
            #Write-Host "`nsprawdzone domeny (po domain; var: historyDomains):"
            #$script:historyDomains | Select-Object -Unique  | Sort-Object
            #$ArrayData | Where-Object { $_.Domain } | Select-Object depth, url, domain | Sort-Object url, domain
            $URLsFullname = Join-Path -Path $script:SessionFolder -ChildPath "UniqueURLs.txt"
            $ArrayData.href | Where-Object { $_ } | Select-Object -Unique | Out-File -FilePath $URLsFullname -Encoding utf8
            Write-Host "- URLs: $URLsFullname" -ForegroundColor Cyan
            #($ArrayData | Where-Object { $_.href } | Select-Object href -Unique | Sort-Object href).href -join "; "
            Write-Host "- Setting log: $(Join-Path $script:SessionFolder "Settings.log")" -ForegroundColor Cyan
            Write-Host "- Other logs: $(Join-Path $script:loganddatafolderPath "$($script:ModuleName).log")" -ForegroundColor Cyan
            Write-Host "- Other logs: $script:SessionFolder" -ForegroundColor Cyan

            Write-Log "End; ParameterSetName: [$($PSCmdlet.ParameterSetName)]"

            break

        }
        'ShowCacheFolder' {
            #New-PSWCoutPath -FolderName $script:WCtoolfolderFullName
            Write-Host "Open log and data folder in Windows File Explorer" -ForegroundColor Cyan
            Open-PSWCExplorerCache -FolderName $script:ModuleName
            Write-Log "End; ParameterSetName: [$($PSCmdlet.ParameterSetName)]"

            break

        }
        'ShowAllElements' {

            Write-Host "Settings:" -ForegroundColor Gray
            Write-Host "[+] Option: $($PSCmdlet.ParameterSetName)" -ForegroundColor DarkGray
            Write-Host "[+] Url: $Url" -ForegroundColor DarkGray
            write-host "[+] Type: $Type" -ForegroundColor DarkGray
            write-host "[+] OnlyDomains: $onlyDomains" -ForegroundColor DarkGray
            Write-Host "[+] Used UserAgent: '$UserAgent'" -ForegroundColor DarkGray
            Write-Host "[+] Session folder path: $script:SessionFolder" -ForegroundColor DarkGray
            write-host "[+] Log: $(Join-Path $script:loganddatafolderPath "$($script:ModuleName).log")" -ForegroundColor DarkGray
            Write-Host "[+] Invoking cli: '$($MyInvocation.Line)'" -ForegroundColor DarkGray
            Write-Host ""
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "Settings:"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Option: $($PSCmdlet.ParameterSetName)"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Url: $Url"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Type: $Type"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] OnlyDomains: $onlydomains"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Session folder path: $script:SessionFolder"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Log: $(Join-Path $script:loganddatafolderPath "$($script:ModuleName).log")"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Used UserAgent: '$UserAgent'"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Invoking cli: '$($MyInvocation.Line)'"

            if ($VerbosePreference -eq "Continue") {
                Write-Log "Verbose output is requested."

                # Output the parameters and their default values.
                Write-verbose "Parameters and Default Values:" -Verbose
                foreach ($param in $MyInvocation.MyCommand.Parameters.keys) {
                    $value = Get-Variable -Name $param -ValueOnly -ErrorAction SilentlyContinue
                    if (-not $null -eq [string]$value) {
                        Write-Verbose "${param}: [${value}]" -Verbose
                    }
                }

                Get-PSWCAllElements -url $url -onlyDomains:$onlyDomains -Type $type -userAgent $UserAgent -Verbose
                # Your verbose output logic here
            }
            else {
                #Write-Log "Verbose output is not requested."
                Get-PSWCAllElements -url $url -onlyDomains:$onlyDomains -Type $type -userAgent $UserAgent
            }

            Write-Log "End; ParameterSetName: [$($PSCmdlet.ParameterSetName)]"

            break
        }
        'GetImageUrls' {

            Write-Host "Settings:" -ForegroundColor Gray
            Write-Host "[+] Option: $($PSCmdlet.ParameterSetName)" -ForegroundColor DarkGray
            Write-Host "[+] Url: $Url" -ForegroundColor DarkGray
            Write-Host "[+] Used UserAgent: '$UserAgent'" -ForegroundColor DarkGray
            Write-Host "[+] Session folder path: $script:SessionFolder" -ForegroundColor DarkGray
            write-host "[+] Log: $(Join-Path $script:loganddatafolderPath "$($script:ModuleName).log")" -ForegroundColor DarkGray
            Write-Host "[+] Invoking cli: '$($MyInvocation.Line)'" -ForegroundColor DarkGray
            Write-Host ""
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "Settings:"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Option: $($PSCmdlet.ParameterSetName)"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Url: $Url"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Session folder path: $script:SessionFolder"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Log: $(Join-Path $script:loganddatafolderPath "$($script:ModuleName).log")"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Used UserAgent: '$UserAgent'"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Invoking cli: '$($MyInvocation.Line)'"

            Write-Host "Images for '${url}':" -ForegroundColor Cyan
            $response = Get-PSWCHttpResponse -url $url -userAgent $UserAgent
            if (-not [string]::IsNullOrEmpty($response[1])) {

                $htmlContent = $response[1].Content.ReadAsStringAsync().Result
                $ImageUrlsArray = Get-PSWCImageUrls -HtmlContent $htmlContent -url $Url
                write-host "`nImages count: $($ImageUrlsArray.count)" -ForegroundColor white
                $ImagesFullName = Join-Path -Path $script:SessionFolder -ChildPath "Images.txt"
                $ImageUrlsArray | Out-File -FilePath $ImagesFullName -Encoding utf8
                Write-Host "`nFiles Saved at:" -ForegroundColor Cyan
                Write-Host "- Images URLs: $ImagesFullName" -ForegroundColor Cyan
                Write-Host "- Setting log: $(Join-Path $script:SessionFolder "Settings.log")" -ForegroundColor Cyan
            }
            else {
                Write-Host "There was no data returned from the specified URL. Please check the URL and try again." -ForegroundColor Red
                $LogMessage = "There was no data returned from the specified URL ($url). Please check the URL and try again."
                Write-Log $LogMessage
                Write-Host ""
                $ImagesFullName = Join-Path -Path $script:SessionFolder -ChildPath "Header.json"
                Out-File -FilePath $ImagesFullName -Encoding utf8 -InputObject $LogMessage
                Write-Host "Files Saved at:" -ForegroundColor Cyan
                Write-Host "- Image URLs: $ImagesFullName" -ForegroundColor Cyan
                Write-Host "- Setting log: $(Join-Path $script:SessionFolder "Settings.log")" -ForegroundColor Cyan
            }

            Write-Log "End; ParameterSetName: [$($PSCmdlet.ParameterSetName)]"

            break

        }
        'GetHTMLMetadata' {

            Write-Host "Settings:" -ForegroundColor Gray
            Write-Host "[+] Option: $($PSCmdlet.ParameterSetName)" -ForegroundColor DarkGray
            Write-Host "[+] Url: $Url" -ForegroundColor DarkGray
            Write-Host "[+] Used UserAgent: '$UserAgent'" -ForegroundColor DarkGray
            Write-Host "[+] Session folder path: $script:SessionFolder" -ForegroundColor DarkGray
            write-host "[+] Log: $(Join-Path $script:loganddatafolderPath "$($script:ModuleName).log")" -ForegroundColor DarkGray
            Write-Host "[+] Invoking cli: '$($MyInvocation.Line)'" -ForegroundColor DarkGray
            Write-Host ""
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "Settings:"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Option: $($PSCmdlet.ParameterSetName)"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Url: $Url"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Session folder path: $script:SessionFolder"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Log: $(Join-Path $script:loganddatafolderPath "$($script:ModuleName).log")"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Used UserAgent: '$UserAgent'"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Invoking cli: '$($MyInvocation.Line)'"

            Write-Host "HTML header data for '${url}':" -ForegroundColor Cyan
            $response = Get-PSWCHttpResponse -url $url -userAgent $UserAgent
            if (-not [string]::IsNullOrEmpty($response[1])) {

                $htmlContent = $response[1].Content.ReadAsStringAsync().Result
                $HTMLMetadata = Get-PSWCHTMLMetadata -htmlContent $htmlContent
                $HTMLMetadata | convertto-json           
                $HeaderFullName = Join-Path -Path $script:SessionFolder -ChildPath "Header.json"
                $HTMLMetadata | convertto-json | Out-File -FilePath $HeaderFullName -Encoding utf8
                Write-Host "`nFiles Saved at:" -ForegroundColor Cyan
                Write-Host "- HTML header data: $HeaderFullName" -ForegroundColor Cyan
                Write-Host "- Setting log: $(Join-Path $script:SessionFolder "Settings.log")" -ForegroundColor Cyan
            }
            else {
                Write-Host "There was no data returned from the specified URL. Please check the URL and try again." -ForegroundColor Red
                $LogMessage = "There was no data returned from the specified URL ($url). Please check the URL and try again."
                Write-Log $LogMessage
                Write-Host ""
                $HeaderFullName = Join-Path -Path $script:SessionFolder -ChildPath "Header.json"
                Out-File -FilePath $HeaderFullName -Encoding utf8 -InputObject $LogMessage
                Write-Host "Files Saved at:" -ForegroundColor Cyan
                Write-Host "- HTML header data: $HeaderFullName" -ForegroundColor Cyan
                Write-Host "- Setting log: $(Join-Path $script:SessionFolder "Settings.log")" -ForegroundColor Cyan
            }
            
            Write-Log "End; ParameterSetName: [$($PSCmdlet.ParameterSetName)]"

            break

        }
        'GetContactInformation' {

            Write-Host "Settings:" -ForegroundColor Gray
            Write-Host "[+] Option: $($PSCmdlet.ParameterSetName)" -ForegroundColor DarkGray
            Write-Host "[+] Url: $Url" -ForegroundColor DarkGray
            Write-Host "[+] Used UserAgent: '$UserAgent'" -ForegroundColor DarkGray
            Write-Host "[+] Session folder path: $script:SessionFolder" -ForegroundColor DarkGray
            write-host "[+] Log: $(Join-Path $script:loganddatafolderPath "$($script:ModuleName).log")" -ForegroundColor DarkGray
            Write-Host "[+] Invoking cli: '$($MyInvocation.Line)'" -ForegroundColor DarkGray
            Write-Host ""
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "Settings:"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Option: $($PSCmdlet.ParameterSetName)"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Url: $Url"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Session folder path: $script:SessionFolder"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Log: $(Join-Path $script:loganddatafolderPath "$($script:ModuleName).log")"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Used UserAgent: '$UserAgent'"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Invoking cli: '$($MyInvocation.Line)'"

            Write-Host "Contact data for '${url}':" -ForegroundColor Cyan
            $response = Get-PSWCHttpResponse -url $url -userAgent $UserAgent
            if (-not [string]::IsNullOrEmpty($response[1])) {
                $htmlContent = $response[1].Content.ReadAsStringAsync().Result
                $ContactData = Get-PSWCContactInformation -htmlContent $htmlContent
                $ContactData | convertto-json
                $ContactFullName = Join-Path -Path $script:SessionFolder -ChildPath "Contact.json"
                $ContactData | convertto-json | Out-File -FilePath $ContactFullName -Encoding utf8
                Write-Host "`nFiles Saved at:" -ForegroundColor Cyan
                Write-Host "- Contact information: $ContactFullName" -ForegroundColor Cyan
                Write-Host "- Setting log: $(Join-Path $script:SessionFolder "Settings.log")" -ForegroundColor Cyan
            }
            else {
                Write-Host "There was no data returned from the specified URL. Please check the URL and try again." -ForegroundColor Red
                $LogMessage = "There was no data returned from the specified URL ($url). Please check the URL and try again."
                Write-Log $LogMessage
                Write-Host ""
                $ContactFullName = Join-Path -Path $script:SessionFolder -ChildPath "Contact.json"
                Out-File -FilePath $ContactFullName -Encoding utf8 -InputObject $LogMessage
                Write-Host "Files Saved at:" -ForegroundColor Cyan
                Write-Host "- Contact information: $ContactFullName" -ForegroundColor Cyan
                Write-Host "- Setting log: $(Join-Path $script:SessionFolder "Settings.log")" -ForegroundColor Cyan
            }

            Write-Log "End; ParameterSetName: [$($PSCmdlet.ParameterSetName)]"

            break

        }
        'GetHeadersAndValues' {

            Write-Host "Settings:" -ForegroundColor Gray
            Write-Host "[+] Option: $($PSCmdlet.ParameterSetName)" -ForegroundColor DarkGray
            Write-Host "[+] Url: $Url" -ForegroundColor DarkGray
            Write-Host "[+] Used UserAgent: '$UserAgent'" -ForegroundColor DarkGray
            Write-Host "[+] Session folder path: $script:SessionFolder" -ForegroundColor DarkGray
            write-host "[+] Log: $(Join-Path $script:loganddatafolderPath "$($script:ModuleName).log")" -ForegroundColor DarkGray
            Write-Host "[+] Invoking cli: '$($MyInvocation.Line)'" -ForegroundColor DarkGray
            Write-Host ""
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "Settings:"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Option: $($PSCmdlet.ParameterSetName)"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Url: $Url"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Session folder path: $script:SessionFolder"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Log: $(Join-Path $script:loganddatafolderPath "$($script:ModuleName).log")"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Used UserAgent: '$UserAgent'"
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Invoking cli: '$($MyInvocation.Line)'"

            Write-Host "HTML head data for '${url}':" -ForegroundColor Cyan
            $response = Get-PSWCHttpResponse -url $url -userAgent $UserAgent
            # Verify that the response is not empty
            if (-not [string]::IsNullOrEmpty($response[1])) {
                $htmlContent = $response[1].Content.ReadAsStringAsync().Result
                $HTMLheadData = Get-PSWCHeadersAndValues -htmlContent $htmlContent
                $HTMLheadData | convertto-json
                $HTMLheadFullName = Join-Path -Path $script:SessionFolder -ChildPath "HTMLhead.json"
                $HTMLheadData | convertto-json | Out-File -FilePath $HTMLheadFullName -Encoding utf8
                Write-Host ""
                Write-Host "Files Saved at:" -ForegroundColor Cyan
                Write-Host "- HTML head data: $HTMLheadFullName" -ForegroundColor Cyan
                Write-Host "- Setting log: $(Join-Path $script:SessionFolder "Settings.log")" -ForegroundColor Cyan
            }
            else {
                Write-Host "There was no data returned from the specified URL. Please check the URL and try again." -ForegroundColor Red
                $LogMessage = "There was no data returned from the specified URL ($url). Please check the URL and try again."
                Write-Log $LogMessage
                Write-Host ""
                $HTMLheadFullName = Join-Path -Path $script:SessionFolder -ChildPath "HTMLhead.json"
                Out-File -FilePath $HTMLheadFullName -Encoding utf8 -InputObject $LogMessage
                Write-Host "Files Saved at:" -ForegroundColor Cyan
                Write-Host "- HTML head data: $HTMLheadFullName" -ForegroundColor Cyan
                Write-Host "- Setting log: $(Join-Path $script:SessionFolder "Settings.log")" -ForegroundColor Cyan
            }           

            Write-Log "End; ParameterSetName: [$($PSCmdlet.ParameterSetName)]"

            break

        }
        default {
            
            Show-PSWCMenu

            break
        }
    }

    # stop measure execution of script
    if ($($PSCmdlet.ParameterSetName) -ne "Default") {
        Write-Host ""
        stop-watch $watch_
    }
    Write-Host ""

    #}
    #catch {
    #Write-Error "An error occurred: $_"
    #}    
}

function Get-RandomUserAgent {
    param (
        [string]
        $UserAgentFileFullName = "$PSScriptRoot\Data\useragents.txt"
    )
    return (get-random (Get-Content $UserAgentFileFullName))
}

Clear-Host

$Public = @( Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -ErrorAction SilentlyContinue -Recurse )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue -Recurse )

# Import the necessary .NET libraries
if ($PSEdition -eq 'core') {
    Write-Error "Module can not be run on core edition!"
    exit
}
elseif ($PSEdition -eq 'desktop') {
    $Assembly = @( Get-ChildItem -Path $PSScriptRoot\Lib\Net45\*.dll -ErrorAction SilentlyContinue )
}

$FoundErrors = @(
    Foreach ($Import in @($Assembly)) {
        try {
            Add-Type -Path $Import.Fullname -ErrorAction Stop
        }
        catch [System.Reflection.ReflectionTypeLoadException] {
            Write-Warning "Processing $($Import.Name) Exception: $($_.Exception.Message)"
            $LoaderExceptions = $($_.Exception.LoaderExceptions) | Sort-Object -Unique
            foreach ($E in $LoaderExceptions) {
                Write-Warning "Processing $($Import.Name) LoaderExceptions: $($E.Message)"
            }
            $true
            #Write-Error -Message "StackTrace: $($_.Exception.StackTrace)"
        }
        catch {
            Write-Warning "Processing $($Import.Name) Exception: $($_.Exception.Message)"
            $LoaderExceptions = $($_.Exception.LoaderExceptions) | Sort-Object -Unique
            foreach ($E in $LoaderExceptions) {
                Write-Warning "Processing $($Import.Name) LoaderExceptions: $($E.Message)"
            }
            $true
            #Write-Error -Message "StackTrace: $($_.Exception.StackTrace)"
        }
    }
    #Dot source the files
    Foreach ($Import in @($Public + $Private)) {
        Try {
            . $Import.Fullname
        }
        Catch {
            Write-Error -Message "Failed to import functions from $($import.Fullname): $_"
            $true
        }
    }
)


if ($FoundErrors.Count -gt 0) {
    $ModuleName = (Get-ChildItem $PSScriptRoot\*.psd1).BaseName
    Write-Warning "Importing module $ModuleName failed. Fix errors before continuing."
    break
}


#Add-Type -Path "D:\dane\voytas\Dokumenty\visual_studio_code\github\htmlagilitypack.1.11.52\lib\netstandard2.0\HtmlAgilityPack.dll"
#Add-Type -Path "D:\dane\voytas\Dokumenty\visual_studio_code\github\htmlagilitypack.1.11.54\lib\Net45\HtmlAgilityPack.dll"

# Switch to using TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
# Get the name of the current module
$script:ModuleName = "PSWebCrawler"

# Get the installed version of the module
$ModuleVersion = [version]"0.0.4"

# Find the latest version of the module in the PSGallery repository
$LatestModule = Find-Module -Name $ModuleName -Repository PSGallery -ErrorAction SilentlyContinue

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

Write-Host "Welcome to PSWebCrawler! ($($moduleVersion))" -ForegroundColor DarkYellow
Write-Host "Start with command: " -ForegroundColor Yellow -NoNewline
Write-Host "PSWC" -ForegroundColor DarkGreen
#Write-Host "Some important changes and informations that may be of interest to you:" -ForegroundColor Yellow
#Write-Host "- You can filter the built-in snippets (category: 'Example') by setting 'ShowExampleSnippets' to '`$false' in config. Use: 'Save-PAFConfiguration -settingName ""ShowExampleSnippets"" -settingValue `$false'" -ForegroundColor Yellow

# Set the default output folder path to the user's document folder under the 'PSWebCrawler' directory if 'outpath' is not provided
if (-not (Get-PSWCoutPath -FolderName $ModuleName -Type UserDoc)) {
    $script:loganddatafolderPath = New-PSWCoutPath -FolderName $ModuleName -Type UserDoc
    Write-Log "Log and Data folder '$script:loganddatafolderPath' was created successfully."
}
else {
    $script:loganddatafolderPath = Get-PSWCoutPath -FolderName $ModuleName -Type UserDoc
    Write-Verbose "Log and Data folder '$script:loganddatafolderPath' already exists."
}
