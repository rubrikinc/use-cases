function PortStatus {
    Write-Verbose -Message "Checking to see if port $($global:testProcessing.Port) is $($global:testProcessing.SuccessIf) on $($global:vmProcessing.MasqIp)"
    $result = Test-Connection  $($global:vmProcessing.MasqIp) -TcpPort $($global:testProcessing.Port)
    if ($result) {
        if ($($global:testProcessing.SuccessIf) -eq "Open") {
            $result = "Passed"
        }
        else {
            $result = "Failed"
        }
        $global:testProcessing.MoreInfo = "Port $($global:testProcessing.Port) on $($global:vmProcessing.MountName) is open"

    }
    else {
        if ($($global:testProcessing.SuccessIf) -eq "Closed") {
            $result = "Passed"
        }
        else {
            $result = "Failed"
        }
        $global:testProcessing.MoreInfo = "Port $($global:testProcessing.Port) on $($global:vmProcessing.MountName) is Closed"
    }
    $global:testProcessing.Status = "Completed"
    $global:testProcessing.Result = $result
    $global:testProcessing.ShortMore = "Port $($global:testProcessing.Port) is $($global:testProcessing.SuccessIf)"
    Write-Verbose -Message " $($global:vmProcessing.MasqIp) Port $($global:testProcessing.Port) Test: $result"
    
}