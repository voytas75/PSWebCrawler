[CmdletBinding()]
param(
    [string]$url
)

# Import the necessary .NET libraries
Add-Type -Path "D:\dane\voytas\Dokumenty\visual_studio_code\github\htmlagilitypack.1.11.52\lib\netstandard2.0\HtmlAgilityPack.dll"

# Set the URL to start crawling from
$startUrl = $url
$visitedUrls = @()

$Timeout = 10

$tempfolder = [System.IO.Path]::GetTempPath()
# Replace any invalid characters with underscores
$validFileName = $url -replace '[^\w\d-]', '_'
$outputContentFilePath = Join-Path -Path $tempFolder -ChildPath "$validFileName.xml"

try {
    # save content
    #Invoke-WebRequest -Uri $Url -TimeoutSec $Timeout -OutFile $outputContentFilePath
    # | Out-Null

    Invoke-WebRequest -Uri $Url -TimeoutSec $Timeout | Export-Clixml $outputContentFilePath

    if (Test-Path -Path $outputContentFilePath -PathType Leaf) {
        Write-Verbose "Feed downloaded and saved to '$outputContentFilePath'."
        return $true
    }
    else {
        Write-Warning "Failed to save feed data to file: $outputContentFilePath"
        return $false
    }
}
catch {
    Write-Warning "Failed to download feed data: $($_.Exception.Message)"
    return $false
}

$webdata = Import-Clixml $outputContentFilePath

$webdata


# Function to crawl a URL
function Crawl-Url($url) {
    if ($visitedUrls -notcontains $url) {
        $visitedUrls += $url
        $response = [System.Net.WebRequest]::Create($url).GetResponse()
        $html = $response.Content
        $outerHTML = $html.OuterHTML
        $reader = [System.IO.StreamReader]($response.GetResponseStream())
        $content = $reader.ReadToEnd()
        $reader.Close()
        #$content
        # Use regex or HTML parsing libraries to extract links from $content

        # For example, using regex:
        # $links = [regex]::Matches($content, 'href\s*=\s*["\'](http[^"\']+)["\']') | ForEach-Object { $_.Groups[1].Value }
        $links = [regex]::Matches($content, 'href\s*=\s*["\''](http[^"\'']+)["\'']') | ForEach-Object { $_.Groups[1].Value }
        #$a = 'href\s*=\s*["''](http[^"'']+)["'']'


        # Install the HTML Agility Pack if you haven't already
        # Install-Package -Name HtmlAgilityPack

        # Import the HTML Agility Pack library

        # Load the HTML content into the HTML Agility Pack
        $html = New-Object HtmlAgilityPack.HtmlDocument
        $html.LoadHtml($outerHTML)  # $content is the HTML source
        $ele1 = $html.getElementbyId("href")
        $ele1

        # Select all anchor elements and extract their href attributes
        $urls = $html.DocumentNode.SelectNodes("//a[@href]") | ForEach-Object {
            $hrefValue = $_.GetAttributeValue("href", "")
            $hrefValue -replace "mailto:", ""  # Remove mailto: links
        }

        # Filter out non-HTTP links
        $httpUrls = $urls -match "^https?://"

        # Print the extracted HTTP URLs
        $httpUrls


        # foreach ($link in $links) {

        #     Write-Host "Found link: $link"
        #     Crawl-Url $link
        # }
    }
}

# Start crawling
#Crawl-Url $startUrl

#https://davidhamann.de/2019/04/12/powershell-invoke-webrequest-by-example/


$url = $startUrl

# Create a WebRequest object
$request = [System.Net.WebRequest]::Create($url)

# Get the response from the request
$response = $request.GetResponse()

write-host "response: `n$($response | out-string)"

write-host "Headers: `n$($response.headers | out-string)"

# Get the base URI from the URL
$baseUri = [System.Uri]::new($url).GetLeftPart([System.UriPartial]::Authority)

write-host "Base uri: $baseUri"


# Get the response stream and create a StreamReader
$stream = $response.GetResponseStream()
$reader = [System.IO.StreamReader]::new($stream)

# Read the entire HTML content of the response
$htmlContent = $reader.ReadToEnd()

# Close the StreamReader and Response
$reader.Close()
$response.Close()

# Load the HTML content into HtmlDocument
$htmlDocument = [HtmlAgilityPack.HtmlDocument]::new()
$htmlDocument.LoadHtml($htmlContent)

# Get the root HTML node and its outerHTML
$outerHTML = $htmlDocument.DocumentNode.OuterHtml

# Use regex or HTML parsing libraries to extract links from $content
# For example, using regex:
# $links = [regex]::Matches($content, 'href\s*=\s*["\'](http[^"\']+)["\']') | ForEach-Object { $_.Groups[1].Value }
$links = [regex]::Matches($outerHTML, 'href\s*=\s*["\''](http[^"\'']+)["\'']') | ForEach-Object { $_.Groups[1].Value }
#$a = 'href\s*=\s*["''](http[^"'']+)["'']'
write-host "Links (regex):"
$links

# Install the HTML Agility Pack if you haven't already
# Install-Package -Name HtmlAgilityPack

# Import the HTML Agility Pack library

# Load the HTML content into the HTML Agility Pack
<# $html = New-Object HtmlAgilityPack.HtmlDocument
$html.LoadHtml($outerHTML)  # $content is the HTML source
$ele1 = $html.getElementbyId("href")
$ele1 #>



# Now, you can use an HTML parsing library to extract the outerHTML from the HTML content
# Let's use the HtmlAgilityPack as an example (you'll need to have it installed)
#Install-Package -Name HtmlAgilityPack -Scope CurrentUser

# Import the HtmlAgilityPack namespace
#Add-Type -Path (Join-Path $env:USERPROFILE\.nuget\packages\htmlagilitypack\*\lib\netstandard2.0\HtmlAgilityPack.dll)

# Load the HTML content into HtmlDocument
<# $htmlDocument = [HtmlAgilityPack.HtmlDocument]::new()
$htmlDocument.LoadHtml($htmlContent)

# Get the root HTML node and its outerHTML
$outerHTML = $htmlDocument.DocumentNode.OuterHtml
 #>
# Display the outerHTML
#$outerHTML
#$htmlDocument.DescendantNodes("href")



#######write-host "links (HtmlAgilityPack):"
#######(($htmlDocument.DocumentNode.Descendants("a").attributes).where{$_.name -eq "href"}).value




<# 
$url = "https://www.example.com"
$response = Invoke-WebRequest -Uri $url
$headers = $response.Headers

# Display headers and their values
$headers.GetEnumerator() | ForEach-Object { Write-Host "$($_.Key): $($_.Value)" }


$url = "https://www.example.com"
$webClient = New-Object System.Net.WebClient
$response = $webClient.DownloadString($url)

# Parse headers
$headers = $webClient.ResponseHeaders

# Display headers and their values
$headers.Keys | ForEach-Object { Write-Host "$($_): $($headers[$_])" }



$url = "https://www.example.com"
$request = [System.Net.HttpWebRequest]::Create($url)
$response = $request.GetResponse()
$headers = $response.Headers

# Display headers and their values
$headers.Keys | ForEach-Object { Write-Host "$($_): $($headers[$_])" }





Add-Type -AssemblyName System.Net.Http

# Create a new HttpClient object
$client = New-Object System.Net.Http.HttpClient

# Make a request to a website
$response = $client.GetAsync("https://example.com").Result

# Display the response headers
$response.Headers  | ForEach-Object { Write-Host "$($_.key): $($_.value)" }

 #>
 #>