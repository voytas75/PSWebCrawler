# Function to crawl a website and retrieve HTML content
function Get-WebContent($url) {
    try {
        $webRequest = [System.Net.WebRequest]::Create($url)
        $webResponse = $webRequest.GetResponse()
        $stream = $webResponse.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($stream)
        $content = $reader.ReadToEnd()
        $reader.Close()
        $stream.Close()
        return $content
    }
    catch {
        Write-Host "Error retrieving web content: $_" -ForegroundColor Red
        return $null
    }
}

# Function to search for RSS feed URLs in HTML content
function Search-FeedUrls($content) {
    $pattern = '<link[^>]+type=["\'']application/rss\+xml["\''][^>]+href=["\''](.*?)["\'']'
    $matches1 = [regex]::Matches($content, $pattern)
    $urls = $matches1.Groups[1].Value
    $urls = $urls | Select-Object -Unique
    return $urls
}

# Function to filter and validate feed URLs
function Validate-FeedUrls($urls) {
    $validUrls = @()
    foreach ($url in $urls) {
        try {
            $response = Invoke-RestMethod -Uri $url -Method Head
            if ($response.StatusCode -eq 200) {
                $validUrls += $url
            }
        }
        catch {
            Write-Host "Error validating URL: $url" -ForegroundColor Yellow
        }
    }
    return $validUrls
}

# Function to parse feed data
function Parse-Feed($url) {
    try {
        $feed = Invoke-RestMethod -Uri $url
        # Parse feed data here and extract relevant information
        # Example: $title = $feed.channel.title
        #          $description = $feed.channel.description
        #          $items = $feed.channel.item
        #          ...
    }
    catch {
        Write-Host "Error parsing feed: $url" -ForegroundColor Red
    }
}

# Main script
$websiteUrl = "https://udt.gov.pl"

# Crawl the website and retrieve HTML content
$content = Get-WebContent -url $websiteUrl

if ($content) {
    # Search for feed URLs in the HTML content
    $feedUrls = Search-FeedUrls -content $content

    # Validate and filter the feed URLs
    $validFeedUrls = Validate-FeedUrls -urls $feedUrls

    foreach ($url in $validFeedUrls) {
        # Parse the feed data
        Parse-Feed -url $url
    }
}
