function WindowsService {
    Write-Verbose -Message "Checking for $($global:testProcessing.ServiceName) on $($global:vmProcessing.MountName)"


    $GuestCredential = Import-CLIXML -Path ($global:credcfg.GuestCredentials | Where {$_.CredentialName -eq "$($global:vmProcessing.Credentials)"}).Credentials
    $splat = @{
        ScriptText      = 'if ( Get-Service "'+$($global:testProcessing.ServiceName)+'" -ErrorAction SilentlyContinue ) { Write-Output "running" } else { Write-Output "not running" }'
        ScriptType      = 'PowerShell'
        VM              =  $($global:vmProcessing.MountName)
        GuestCredential = $GuestCredential
    }  
    $result = Invoke-VMScript @splat 
    
    if ($result.ScriptOutput.trim() -eq "running"){
        $result = "Passed"
        $global:testProcessing.MoreInfo = "Service $($global:testProcessing.ServiceName) on $($global:vmProcessing.MountName) is running"
    }
    else {
        $result = "Failed"
        $global:testProcessing.MoreInfo = "Service $($global:testProcessing.ServiceName) on $($global:vmProcessing.MountName) is not running"
    }

    $global:testProcessing.Status = "Completed"
    $global:testProcessing.ShortMore = "$($global:testProcessing.ServiceName)"
    $global:testProcessing.Result = $result
    Write-Verbose -Message  "Service $($global:testProcessing.ServiceName) on $($global:vmProcessing.MountName) : $result"
}