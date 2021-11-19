Write-Host "Hello there :) I will help you create the configurations needed for the Rubrik Sandbox Use-Case"
Write-Host "Let's kick it off by gathering some credentials and connection information"

$CredPath = Read-Host "Enter a path to a folder to store these encrypted credentials"

while ($true) {
    $vCenterServer = Read-Host "What is the IP or FQDN of your vCenter Server"
    $vCenterCreds = Get-Credential -Message "Credentials with access to $vCenterServer"

    try {
        $viserver = Connect-VIServer -Server $vcenterServer -Credential $vCenterCreds -ErrorAction Stop
        break
    }
    catch {
        Write-Host "Unable to connect with the specified configurations"
        Write-Host "Error is $_"
    }

}
Write-Host "Perfect we connected to vSphere, let's connect to Rubrik now"
while ($true) {
    $RubrikCluster = Read-Host "What is the IP or FQDN of your Rubrik Cluster"
    $APIAuthToken = Read-Host "API Authorization token to connect to Rubrik"

    try {
        $rubrik = Connect-Rubrik -Server $RubrikCluster -Token $APIAuthToken
        break
    }
    catch {
        Write-Host "Unable to connect with the specified configurations"
        Write-Host "Error is $_"
    }

}

Write-Host "Excellent - We've succesfully connected to Rubrik as well"
Write-Host "The sandbox validation script often executes scripts on the VMs within the isolated networks - to do this we need to have Guest OS credentials as well"
Write-Host "You can create as many Guest OS credentials as you wish, often we see users creating them for DomainAdministrator, LocalAdministrator, LinuxRoot, etc..."
Write-Host "Let's start off with our first Guest OS Credential"
$guestcreds = @()
while ($true) {
    $CredentialName = Read-Host "Give this credential a name (IE DomainAdmin, LocalAdmin, etc)"
    $Credentials = Get-Credential -Message "Enter credentials for the $CredentialName"
    $guestCred = @{
        CredentialName = $CredentialName"
    }
    $response = Read-Host "Would you like to create another Guest OS Credential [y/n]"
    if ($response.ToUpper() -ne "Y") {
        break
    }
}

#Write-Host "Alright, let's move on to the router configuration. This will help us create the router which sits between your managment network and all of the isolated networks we Live Mount into"
#$routername = Read-Host "First off, we need a name for the router"
#$routerpassword = Read-Host "Enter a default password for the vyos user on the router" -MaskInput

