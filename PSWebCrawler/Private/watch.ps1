function Start-Watch {
    return [System.Diagnostics.Stopwatch]::StartNew()
}

function Stop-Watch {
    param (
        [System.Diagnostics.Stopwatch]$stopwatch
    )
    
    $stopwatch.Stop()
    $elapsedTime = $stopwatch.Elapsed.TotalSeconds
    $elapsedTimeInSeconds = [math]::Round($elapsedTime, 2)
    Write-Host "Elapsed time: $($elapsedTimeInSeconds) seconds" -ForegroundColor green
}