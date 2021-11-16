function Ping {


    Write-Verbose -Message "Performing ping to  $($global:vmProcessing.MasqIp)"
    $result = Test-Connection  $($global:vmProcessing.MasqIp) -Ping -IPv4 -Count 6 -Quiet
    if ($result) {
        $result = "Passed"
    }
    else {
        
        $result = "Failed"
    }
    $global:testProcessing.Status = "Completed"
    $global:testProcessing.Result = $result
    $global:testProcessing.MoreInfo = "Ping to $($global:vmProcessing.MasqIp) $result "
    $global:testProcessing.ShortMore = $result
    Write-Verbose -Message " $($global:vmProcessing.MasqIp) Ping Test: $result"
    
}
