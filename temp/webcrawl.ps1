# Define the URL of the webpage you want to start crawling from
$startUrl = "https://microsoft.com"

# Define the keyword to search for in the webpage content
$keyword = "eth"

# Create a WebClient object
$webClient = New-Object System.Net.WebClient

# Function to crawl a webpage and search for RSS feeds
function CrawlWebpage($url) {
    # Download the HTML content of the webpage
    try {
        $htmlContent = $webClient.DownloadString($url)
    
        # Define a regular expression pattern to match RSS feed URLs
        #$pattern = 'href=["\'](https?://[^"\']+\.rss)["\']'
        #$pattern = 'href=[\'"]((?:https?://(?:www\.)?[^\'"\']+\.rss))["\']i'
        #$pattern = 'href=["\'](https?:\/\/[^"\']+\.rss)["\']'
        $pattern = 'href=["''](https?://[^"'']+\.rss)["'']'
    
    
        # Find all matches of the pattern in the HTML content
        $matches1 = [regex]::Matches($htmlContent, $pattern)
    
        # Loop through the matches and output the URLs of the RSS feeds
        foreach ($match in $matches1) {
            $rssUrl = $match.Groups[1].Value
            Write-Output $rssUrl
        }
    
    }
    catch {
        <#Do this if a terminating exception happens#>
    }
}

# Function to crawl webpages recursively
function RecursiveCrawl($url) {
    # Crawl the current webpage
    CrawlWebpage $url

    try {
        # Download the HTML content of the webpage
        $htmlContent = $webClient.DownloadString($url)
    
        # Check if the webpage contains the keyword
        if ($htmlContent -like "*$keyword*") {
            # Define a regular expression pattern to match anchor tags
            $pattern = '<a href=["\'']([^"\'']+)?["\'']'
    
            # Find all matches of the pattern in the HTML content
            $matches1 = [regex]::Matches($htmlContent, $pattern)
    
            # Loop through the matches and recursively crawl the linked webpages
            foreach ($match in $matches1) {
                $linkedUrl = $match.Groups[1].Value
                if ($linkedUrl -like "http*" -and $linkedUrl -notlike "*.css" -and $linkedUrl -notlike "*.js" -and $linkedUrl -ne $url) {
                    RecursiveCrawl $linkedUrl
                }
            }
        }
    
    }
    catch {
        <#Do this if a terminating exception happens#>
    }
}

# Start the recursive crawling process from the initial URL
RecursiveCrawl $startUrl