function OpenPort {
    Write-Verbose -Message "Checking to see if port $($global:testProcessing.Port) is open on $($global:vmProcessing.MasqIp)"
    $result = Test-Connection  $($global:vmProcessing.MasqIp) -TcpPort $($global:testProcessing.Port)
    if ($result) {
        $result = "Passed"
        $global:testProcessing.MoreInfo = "Port $($global:testProcessing.Port) on $($global:vmProcessing.MountName) is open"
    }
    else {
        
        $result = "Failed"
        $global:testProcessing.MoreInfo = "Port $($global:testProcessing.Port) on $($global:vmProcessing.MountName) is Closed"
    }
    $global:testProcessing.Status = "Completed"
    $global:testProcessing.Result = $result
    $global:testProcessing.ShortMore = "Port $($global:testProcessing.Port)"
    Write-Verbose -Message " $($global:vmProcessing.MasqIp) Port $($global:testProcessing.Port) Test: $result"
    
}