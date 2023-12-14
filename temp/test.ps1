PSWC -Url "https://ettvi.com/" -Depth 1
pSWC -Url "https://ettvi.com/" -Depth 1 -Resolve
pSWC -Url "https://gunb.gov.sspl" -Depth 1 -Resolve -onlyDomains
PSWC -Url "https://gunb.gov.sspl" -Depth 1 -Resolve -onlyDomains -outputFolder "c:\temp2"
PSWC -Url "https://gunb.gov.sspl" -ShowAllElements
PSWC -Url "https://gunb.gov.sspl" -ShowAllElements -Type All
PSWC -Url "https://gunb.gov.sspl" -ShowAllElements -Type All -onlyDomains
PSWC -Url "https://gunb.gov.sspl" -GetImageUrls
PSWC -Url "https://gunb.gov.sspl" -GetHTMLMetadata
PSWC -Url "https://gunb.gov.sspl" -GetContactInformation
PSWC -Url "https://gunb.gov.sspl" -GetHeadersAndValues


<# 
# Inside the Start-PSWebCrawler function
if ([string]::IsNullOrEmpty($outputFolder)) {
    $outputFolder = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PSWebCrawler"
}

#>