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

        [string]$url,

        [Parameter(Mandatory = $false)]
        [string]$SelectQuery = "//img"
    )

    try {
        $doc = New-Object HtmlAgilityPack.HtmlDocument
        $doc.LoadHtml($HtmlContent)

        $imageUrls = New-Object System.Collections.Generic.List[string]

        $selectedNodes = $doc.DocumentNode.SelectNodes($SelectQuery)
        if ($selectedNodes) {
            foreach ($node in $selectedNodes) {
                $src = $node.GetAttributeValue("src", "")
                if (-not ([string]::IsNullOrWhiteSpace($src))) {
                    if ($src -match "^https?://") {
                        $imageUrls.Add($src)
                    }
                    elseif ($src -match "^/|^\.\./") {
                        $internalUrl = $null
                        
                        # Attempt to create a new URI using the base URL and the source
                        $uriCreationResult = [System.Uri]::TryCreate([System.Uri]::new($url), $src, [ref]$internalUrl)
                        # If the URI creation fails, write an error message
                        if ($uriCreationResult -eq $false) {
                            Write-Error "Failed to create URI from base URL: $url and source: $src"
                        }
                        # Add the absolute URI of the internal URL to the imageUrls list
                        $imageUrls.Add($internalUrl.AbsoluteUri)
                    }
                    else {
                        $imageUrls.Add($src)
                    }
                }
            }
            #Write-Information ($imageUrls | ConvertTo-Json) -InformationAction Continue
        }
        #Write-Information ($imageUrls.gettype()) -InformationAction Continue
    }
    catch {
        Write-Error "An error occurred: $_"
    }
    return $imageUrls
}
