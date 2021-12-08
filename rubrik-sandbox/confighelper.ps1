Write-Host "Hello there :) I will help you create the configurations needed for the Rubrik Sandbox Use-Case"
$ConfigPath = Read-Host "First, enter a path to store the completed configuration files"
while ($true){
    if (-Not (Test-Path $ConfigPath)) {
        Write-Host "$ConfigPath doesn't seem to be a valid path"
        $ConfigPath = Read-Host "Enter a path to a folder to store the completed configuration files"
    } else {
        break
    }
}
$CredPath = Read-Host "Now we need a path to encrypted credentials"
while ($true){
    if (-Not (Test-Path $CredPath)) {
        Write-Host "$CredPath doesn't seem to be a valid path"
        $CredPath = Read-Host "Enter a path to a folder to store these encrypted credentials"
    } else {
        break
    }
}

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
$vCenterCredFile = Read-Host "Enter a filename of which to store the encrypted vSphere credentials [IE vsphere.creds]"
$vCenterCredFile = "$CredPath\$vCenterCredFile"
$vCenterCreds | Export-CLIXML -Path $vCenterCredFile

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
$RubrikTokenFile = Read-Host "Enter a filename of which to store the encrypted Rubrik API token [IE rubrik.token]"
$RubrikTokenFile = "$CredPath\$RubrikTokenFile"
$APIAuthToken | Export-CLIXML -Path $RubrikTokenFile

Write-Host "Excellent - We've succesfully connected to Rubrik as well"
Write-Host "The sandbox validation script often executes scripts on the VMs within the isolated networks - to do this we need to have Guest OS credentials as well"
Write-Host "You can create as many Guest OS credentials as you wish, often we see users creating them for DomainAdministrator, LocalAdministrator, LinuxRoot, etc..."
Write-Host "Let's start off with our first Guest OS Credential"
$guestcreds = @()
while ($true) {
    $CredentialName = Read-Host "Give this credential a name (IE DomainAdmin, LocalAdmin, etc)"
    $Credentials = Get-Credential -Message "Enter credentials for the $CredentialName"
    $FullPath = "$CredPath\$CredentialName" + ".creds"
    $Credentials | Export-CLIXML -Path $FullPath
    $guestCred = @{
        CredentialName = "$CredentialName"
        Credentials = "$FullPath"
    }
    $guestcreds += $guestCred
    $response = Read-Host "Would you like to create another Guest OS Credential [y/n]"
    if ($response.ToUpper() -ne "Y") {
        break
    }
}

$credsconfig = @{
    VMware = @{
        vCenterServer = "$vCenterServer"
        Credentials = "$vCenterCredFile"
    }
    Rubrik = @{
        RubrikCluster = "$RubrikCluster"
        APIAuthToken = "$RubrikTokenFile"
    }
    GuestCredentials = $guestcreds
}
$CredentialFileName = Read-Host "Please enter a filename to write the credential configuration to [IE creds.config]"
$CredentialFileName = "$ConfigPath\$CredentialFileName"
$credsconfig | ConvertTo-Json -Depth 5 | Out-File $CredentialFileName


Write-Host "Alright that's it for creds, let's move on to the router configuration. This will help us create the router which sits between your managment network and all of the isolated networks we Live Mount into"
$routername = Read-Host "First off, we need a name for the router"
$routerpassword = Read-Host "Enter a default password for the vyos user on the router" -MaskInput
$routersecret = Read-Host "Enter in any phrase (no spaces) to use as the API Secret for the router [IE apiSuperSecret]"
$vmhost = Read-Host "Which VMware host should we deploy the router (and subsequent isolated networks) on"
while ($true) {
    $valid = Get-VMHost $vmhost -ErrorAction SilentlyContinue
    if ($null -eq $valid) {
        $vmhost = Read-Host "$vmhost not found. Please enter the fqdn of a valid esxi host to deploy the router on"
    }
    else {
        break
    }
}
$vmdatastore = Read-Host "Please enter the datastore name to deploy the router on"
while ($true) {
    $valid = Get-Datastore $vmdatastore -ErrorAction SilentlyContinue
    if ($null -eq $valid) {
        $vmdatastore = Read-Host "$vmdatastore not found. Please enter the datastore name to deploy the router on"
    }
    else {
        break
    }
}

$ManagementNetwork = Read-Host "Please enter the name of the Management Network within VMware to attach the Management NIC to"

while ($true) {
    $valid = Get-VirtualNetwork $ManagementNetwork -ErrorAction SilentlyContinue
    if ($null -eq $valid) {
        $ManagementNetwork = Read-Host "$ManagementNetwork not found, Please enter the management network name to attach the router to"
    } else {
        break
    }
}
$ManagementNetworkIP = Read-Host "Please enter an IP address to assign to the router"
$ManagementNetworkSubnet = Read-Host "Please enter the associated subnet mask"
$ManagementNetworkGateway = Read-Host "Please enter the associated gateway"

Write-Host "OK - Let's now define the isolated networks we need to create"
WRite-Host "For each of your production networks, we will automatically create an isolated network matching that"
$IsolatedNetworks = @()
while ($true) {
    $ProductionNetworkName = Read-Host "Enter the production network name to isolate"
    while ($true) {
        $valid = Get-VirtualNetwork $ProductionNetworkName -ErrorAction SilentlyContinue
        if ($null -eq $valid) {
            $ProductionNetworkName = Read-Host "$ProductionNetworkName not found, enter the production network name to isolate"
        } else {
            break
        }
    }
    $IsolatedNetworkName = $ProductionNetworkName + "_isolated"
    $ProductionNetworkGateway  = Read-Host "Please enter the production network gateway (this will be used as the primary IP for the router interface serving the isolated network"
    $ProductionNetworkSubnet = Read-Host "Please enter the production network subnet mask [IE 255.255.255.0"
    $MasqueradeNetwork = Read-Host "Please enter the network address to use for the masquerade (to gain access into the isolated network) Ensure that this addressing is not used anywhere else within your environment [IE 192.168.121.0]"
    $DHCPEnabled = Read-Host "Would you like to enable DHCP on the isolated interface [y/n]"
    if ($DHCPEnabled.ToUpper() -eq "Y") {
        $DHCPEnabled = $true
        $DHCPScopeStart = Read-Host "Please enter the starting IP for the DHCP Scope"
        $DHCPScopeEnd = Read-Host "Please enter the ending IP for the DHCP Scope"
        $DHCPNameserver = Read-Host "Please enter the nameserver IP address to pass through DHCP"
    } else {
        $DHCPEnabled = $false
        $DHCPScopeEnd = ""
        $DHCPScopeStart = ""
        $DHCPNameserver = ""
    }

    $isolnetwork = @{
        ProductionNetworkName = "$ProductionNetworkName"
        InterfaceAddress = "$ProductionNetworkGateway"
        InterfaceSubnet = "$ProductionNetworkSubnet"
        MasqueradeNetwork = "$MasqueradeNetwork"
        IsolatedPortGroup = "$IsolatedNetworkName"
        DHCPEnabled = $DHCPEnabled
        $DHCPScopeStart = "$DHCPScopeStart"
        $DHCPScopeEnd = "$DHCPScopeEnd"
        $DHCPNameserver = "$DHCPNameserver"
    }
    $IsolatedNetworks += $isolnetwork
    $response = Read-Host "Would you like to map another production network to an isolated network [y/n]"
    if ($response.ToUpper() -ne "Y") {
        break
    }
}

$routercfg = @{
    RouterName = "$routername"
    RouterPassword = "$routerpassword"
    RouterAPIKey = "$routersecret"
    VMwareHost = "$vmhost"
    VMwareDatastore = "$vmdatastore"
    ManagementNetworkIP = "$ManagementNetworkIP"
    ManagementNetworkSubnet = "$ManagementNetworkSubnet"
    ManagementNetworkGateway = "$ManagementNetworkGateway"
    ManagementNetwork = "$ManagementNetwork"
    IsolatedNetworks = $IsolatedNetworks
}

$RouterFileName = Read-Host "Please enter a filename to write the router configuration to [IE router.config]"
$RouterFileName = "$ConfigPath\$RouterFileName"
$routercfg | ConvertTo-Json -Depth 5 | Out-File $RouterFileName

Write-Host "Alright, just about there, the last thing we need to do is setup our application config. This is the configuration of what VMs we want to live mount and test within the isolated networks..."

$GenerateReport = Read-Host "Would you like the script to generate an HTML report [y/n]"
if ($GenerateReport.ToUpper() -eq "Y") {
    $GenerateReport = $true
} else {
    $GenerateReport = $false
}
$ReportPath = Read-Host "Where would you like to store the report?"
while ($true){
    if (-Not (Test-Path $ReportPath)) {
        Write-Host "$ReportPath doesn't seem to be a valid path"
        $ReportPath = Read-Host "Enter a path to a folder to store the generated report"
    } else {
        break
    }
}
$ReportName = Read-Host "Enter a filename for the report"
$ReportPath = "$ReportPath\$ReportName"
$LeaveLabRunning = Read-Host "Would you like to leave the lab running after tests have been performed [y/n]"
if ($LeaveLabRunning.ToUpper() -eq "Y") {
    $LeaveLabRunning = $true
} else {
    $LeaveLabRunning = $false
}
#-=MWP=- prompt once implemented
$EmailReport = $true

Write-Host "OK, now let's configure the virtual machines you would like to test/clone"
$VirtualMachines = @()
while ($true) {
    $VMName = Read-Host "Enter the name of a virtual machine to clone"
    while ($true) {
        if ((Get-VM $VMName -ErrorAction SilentlyContinue) -eq $null) {
            $VMName = Read-Host "$VMName not found, enter the name of a virtual machine to clone"
        }
        else {
            break
        }
    }
    $MountName = Read-Host "Enter a name for the live mount of $VMName"
    while ($true) {
        if ($MountName -eq $VMName) {
            $MountName = Read-Host "$MountName is not valid, enter a name for the live mount of $VMName"
        }
        else {
            break
        }
    }
    $tempcreds = Get-Content -Raw -Path $CredentialFileName | ConvertFrom-Json -Depth 5
    $VMCredentials = Read-Host "What credentials should we use for this VM [$($tempcreds.GuestCredentials.CredentialName)]"
    while ($true) {
        $exist = $tempcreds.GuestCredentials | Where {$_.CredentialName -eq "$VMCredentials"}
        if ($null -eq $exist) {
            $VMCredentials = Read-Host "$VMCredentials is invalid, please enter one of $($tempcreds.GuestCredentials.CredentialName)"
        }
        else {
            break
        }
    }
    $SkipPingTest = Read-Host "Would you like to skip the ping test for this VM [y/n]"
    if ($SkipPingTest.ToUpper() -eq "Y") {
        $SkipPingTest = $true
    }
    else {
        $SkipPingTest = $false
    }
    $SkipToolsTest = Read-Host "Would you like to skip the VMware Tools test for this VM [y/n]"
    if ($SkipToolsTest.ToUpper() -eq "Y"){
        $SkipToolsTest = $true
    }
    else {
        $SkipToolsTest = $false
    }
    $tests = @()
    while ($true) {
        $response = Read-Host "Would you like to add any additional tests to this VM [y/n]"
        if ($response.ToUpper() -ne "Y"){
            break
        }
        $testname = Read-Host "What test would you like to perform? [PortStatus, WindowsService]"
        while ($testname -notin ('PortStatus','WindowsService')) {
            $testname = Read-Host "$testname is invalid, please enter a valid test name [PortStatus, WindowsService]"
        }
        if ($testname -eq "PortStatus") {
            $portnumber = Read-Host "What port would you like to test?"
            $SuccessIf = Read-Host "Should we test $portnumber to be [Open] or [Closed]"
            $test = @{
                Name = "$testname"
                Port = "$portnumber"
                SuccessIf = "$SuccessIf"
            }
        }
        if ($testname -eq "WindowsService") {
            $ServiceName = Read-Host "What service would you like to look for"
            $test = @{
                Name = "$testname"
                ServiceName = "$ServiceName"
            }
        }
        $tests += $test
    }

    $vm = @{
        name = "$VMName"
        mountname = "$MountName"
        credentials = "$VMCredentials"
        skipPingTest = $SkipPingTest
        skipToolsTest = $SkipToolsTest
        tasks = $tests
    }
    $VirtualMachines += $vm
    $answer = Read-Host "Would you like to add another VM [y/n]"
    if ($answer.ToUpper() -eq "N") {
        break
    }

}

$appcfg = @{
    settings = @{
        generateReport = $GenerateReport
        reportPath = $ReportPath
        leaveLabRunning = $LeaveLabRunning
        emailReport = $EmailReport
    }
    virtualMachines = $VirtualMachines
}

$AppFileName = Read-Host "Please enter a filename to write the application configuration to [IE app.config]"
$AppFileName = "$ConfigPath\$AppFileName"
$appcfg | ConvertTo-Json -Depth 5 | Out-File $AppFileName


Write-Host "All done!"

Write-Host "You can now execute the sandbox by running the following command"
Write-Host ".\Validate -routerconfig $RouterFileName -credentialconfig $CredentialFileName -applicationconfig $AppFileName"

$answer = Read-Host "Would you like to run now [y/n]"
if ($answer.ToUpper() -eq "Y") {
    & "$PSScriptRoot\Validate.ps1 -routerconfig $RouterFileName -credentialconfig $CredentialFileName -applicationconfig $AppFileName -Verbose"
}
else {
    exit
}
