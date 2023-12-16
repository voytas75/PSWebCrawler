import-module D:\dane\voytas\Dokumenty\visual_studio_code\github\PSWebCrawler\PSWebCrawler\PSWebCrawler.psd1; PSWC -Url "https://ettvi.com/" -Depth 1
import-module D:\dane\voytas\Dokumenty\visual_studio_code\github\PSWebCrawler\PSWebCrawler\PSWebCrawler.psd1; pSWC -Url "https://ettvi.com/" -Depth 1 -Resolve
import-module D:\dane\voytas\Dokumenty\visual_studio_code\github\PSWebCrawler\PSWebCrawler\PSWebCrawler.psd1; pSWC -Url "https://gunb.gov.sspl" -Depth 1 -Resolve -onlyDomains
import-module D:\dane\voytas\Dokumenty\visual_studio_code\github\PSWebCrawler\PSWebCrawler\PSWebCrawler.psd1; PSWC -Url "https://gunb.gov.sspl" -Depth 1 -Resolve -onlyDomains -outputFolder "c:\temp2"
import-module D:\dane\voytas\Dokumenty\visual_studio_code\github\PSWebCrawler\PSWebCrawler\PSWebCrawler.psd1; PSWC -Url "https://gunb.gov.sspl" -ShowAllElements
import-module D:\dane\voytas\Dokumenty\visual_studio_code\github\PSWebCrawler\PSWebCrawler\PSWebCrawler.psd1; PSWC -Url "https://gunb.gov.sspl" -ShowAllElements -Type All
import-module D:\dane\voytas\Dokumenty\visual_studio_code\github\PSWebCrawler\PSWebCrawler\PSWebCrawler.psd1; PSWC -Url "https://gunb.gov.sspl" -ShowAllElements -Type All -onlyDomains
import-module D:\dane\voytas\Dokumenty\visual_studio_code\github\PSWebCrawler\PSWebCrawler\PSWebCrawler.psd1; PSWC -Url "https://gunb.gov.sspl" -GetImageUrls
import-module D:\dane\voytas\Dokumenty\visual_studio_code\github\PSWebCrawler\PSWebCrawler\PSWebCrawler.psd1; PSWC -Url "https://gunb.gov.sspl" -GetHTMLMetadata
import-module D:\dane\voytas\Dokumenty\visual_studio_code\github\PSWebCrawler\PSWebCrawler\PSWebCrawler.psd1; PSWC -Url "https://gunb.gov.sspl" -GetContactInformation
import-module D:\dane\voytas\Dokumenty\visual_studio_code\github\PSWebCrawler\PSWebCrawler\PSWebCrawler.psd1; PSWC -Url "https://gunb.gov.sspl" -GetHeadersAndValues


<# 
# Inside the Start-PSWebCrawler function
if ([string]::IsNullOrEmpty($outputFolder)) {
    $outputFolder = Join-Path ([Environment]::GetFolderPath("MyDocuments")) "PSWebCrawler"
}
            Write-Host "[+] Invoking cli: '$($MyInvocation.Line)'" -ForegroundColor DarkGray
            Add-Content -Path (Join-Path $script:SessionFolder "Settings.log") -Value "[+] Invoking cli: '$($MyInvocation.Line)'"

#>