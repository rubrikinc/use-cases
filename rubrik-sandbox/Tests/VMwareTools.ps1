function VMwareTools {

    Write-Verbose -Message "Performing VMware Tools test"
    $tgtvm = Get-VM $global:vmProcessing.MountName

    $toolsStatus = $tgtvm.ExtensionData.Guest.ToolsRunningStatus

    if ($toolsStatus -eq "guestToolsRunning") {
        $result = "Passed"
    }
    else {
        $result = "Failed"
    }
    $moreinfo = "VMware Tools Status of $toolsStatus"
    Write-Verbose "VMware Tools test $result"
    $global:testProcessing.Status = "Completed"
    $global:testProcessing.Result = $result
    $global:testProcessing.ShortMore = $result
    $global:testProcessing.MoreInfo = "$moreinfo"
}