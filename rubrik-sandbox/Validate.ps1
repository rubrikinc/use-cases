[CmdletBinding()]
param(
    [String]$routerconfig="",
    [String]$credentialconfig="",
    [String]$applicationconfig=""
)

#-=MWP=- TODO 
#
# Create helper function/script to prompt users to build out the config
# Possibility of either offloading all these functions a functions.ps1 file and dot sourcing, or maybe creating a module (probably not, but maybe)
# Ability to do something with the generated report, IE email
# Possible Security Related Tests to Add
#       - PortScan and report
# Possible Restore Validation Tests to Add
#       - Read content from file, compare to user specified string
#       - Do wget, look for html content from website, compare to user specified string
#       - SQL Query - Run sql query and report on results (or compare to user specified string for pass/fail status)
#       - Add test to call Rubrik Backup Verification API
# Could explore the use case around mounting databases using their native Live Mount and doing some stuff as well (waaaaaay down the road)
# Ability for users to specify dates around what snapshots to Live Mount (especially handy when looking to simply spin up a lab for manual testing)
# How's about some day, maybe expanding this to Hyper-V and Nutanix lol
# Unit testing
# Add ability to take screenshot of console - place in report - "https://vcsa.rubrik.us/screen?id=$moref"
#
#-=MWP=- TODO

# dot source all the tests
Get-ChildItem -Path ".\Tests" -Filter "*.ps1" | Foreach-Object { . $_.FullName }


# Rubrik Defined Variables
$global:config_changed = "false"
$global:rbk_router_ova = ".\rtr-ova\vyos13.ova"
$global:rbk_router_config_script = ".\rtr-ova\config-router-mgmt.sh"
$global:rbk_router_username = "vyos"
$global:rbk_router_password = "vyos"

function Test-RouterConfig($config) {
    # Establish Connection to vCenter
    $viserver = Connect-VIServer -Server $global:credcfg.VMware.vCenterServer -Credential (Import-CLIXML $global:credcfg.VMware.Credentials)
    # Ensure VMware host selected is valid
    try { $vmhost = Get-VMHost $config.VMwareHost -ErrorAction Stop }
    catch { throw("ESXi host ($($config.VMwareHost)) is not valid ($_)")}
    # Make sure Datastore is accessible 
    try { $datastore = $vmhost | Get-Datastore -Name $config.VMwareDatastore -ErrorAction Stop }
    catch {throw ("Datastore ($($config.VMwareDatastore)) attached to $($config.VMwareHost) not found ($_)" )}
    # Does the Management Network exist?
    try { $vmnetwork = Get-VirtualNetwork -Name $config.ManagementNetwork -ErrorAction Stop}
    catch {throw("Management Network ($($config.ManagementNetwork)) cannot be found ($_)")}
    # Check that other values passed are valid IP Addresses[]
    try { $valid = [IPAddress]$config.ManagementNetworkIP}
    catch {throw("Management Network IP ($($config.ManagementNetworkIP)) is not valid")}
    try { $valid = [IPAddress]$config.ManagementNetworkSubnet}
    catch {throw("Management Network Subnet ($($config.ManagementNetworkSubnet)) is not valid")}
    try { $valid = [IPAddress]$config.ManagementNetworkGateway}
    catch {throw("Management Network Gateway ($($config.ManagementNetworkGateway)) is not valid")}
    foreach ($network in $config.IsolatedNetworks) {
        try { $vmnetwork = Get-VirtualNetwork -Name $network.ProductionNetworkName -ErrorAction Stop}
        catch {throw("Production Network ($($network.ProductionNetworkName)) cannot be found ($_)")}
        try { $valid = [IPAddress]$network.MasqueradeNetwork}
        catch {throw("$($network.ProductionNetworkName) Masquerade Network ($($network.MasqueradeNetwork)) is not valid")}
        try { $valid = [IPAddress]$network.InterfaceAddress}
        catch {throw("$($network.ProductionNetworkName) Interface Address IP ($($network.InterfaceAddress)) is not valid")}
        try { $valid = [IPAddress]$network.InterfaceSubnet}
        catch {throw("$($network.ProductionNetworkName) Interface Subnet ($($network.InterfaceSubnet)) is not valid")}
        if ($network.DHCPEnabled) {
            try { $valid = [IPAddress]$network.DHCPNameserver}
            catch {throw("$($network.ProductionNetworkName) DHCP Nameserver ($($network.DHCPNameserver)) is not valid")}
            try { $valid = [IPAddress]$network.DHCPScopeStart}
            catch {throw("$($network.ProductionNetworkName) DHCP Scope Start ($($network.DHCPScopeStart)) is not valid")}
            try { $valid = [IPAddress]$network.DHCPScopeEnd}
            catch {throw("$($network.ProductionNetworkName) DHCP Scope End ($($network.DHCPScopeEnd)) is not valid")}
        }
    }
}
function Get-RouterConfig($routerconfig) {
    if ($routerconfig -ne "") {
        # Check path of config
        if (-Not (Test-Path $routerconfig)) {
            Write-Warning -Message "$routerconfig is not a valid path."
            exit
        }
        else {
            # We are good to go, load the config
            Write-Verbose -Message "Loading router configuration from $routerconfig"
            $config = Get-Content $routerconfig | ConvertFrom-Json -Depth 5
            Test-RouterConfig($config)


            if (Test-path "$PSScriptRoot\rtr-ova\config.bak") {
                # If we already have a backup, let's check to see if anything has changed
                $newconfig = Get-Content $routerconfig
                $oldconfig = Get-Content "$PSScriptRoot\rtr-ova\config.bak" 
                Write-Verbose -Message "Comparing passed configuration to running configuration"
                $differences = Compare-Object -ReferenceObject $newconfig -DifferenceObject $oldconfig
                if ($differences.count -ge 1) {
                    Write-Verbose -Message "Passed configuration differs from running configuration"
                    $global:config_changed = "true"
                }
                else {
                    Write-Verbose -Message "No configuration changed detected"
                    $global:config_changed = "false"
                }
            }
            else {
                Write-Verbose -Message "No running configuration found, assuming first run..."
                # No backup of config, this must mean it's the first time we are running the script
                $global:config_changed = "true"

            }

            # copy config to backup
            Copy-Item $routerconfig -Destination "$PSScriptRoot\rtr-ova\config.bak"
            return $config
        }

    }
    else {
        # No config passed - for now let's just exit
        Write-Warning -Message "No router configuruation passed or the config is invalid. I need that to function :)"
        Write-Warning -Message "If you need help creating the config, run confighelper.ps1"
        exit
    } 
}
function New-RouterConfig {

}
function Test-CredsConfig($config) {
    # Function will throw errors if any information in configuration is not valid
    # Check for valid files passed to those credentials that are required
    if (-Not (Test-Path $config.VMware.Credentials)) {
        throw ("Unable to find VMware credentials file $($config.VMware.Credentials) - Update config to a valid credentials path")
    }
    if (-Not (Test-Path $config.Rubrik.APIAuthToken)) {
        throw ("Unable to find Rubrik token file $($config.Rubrik.APIAuthToken) - Update config to a valid credentials path")
    }
    foreach ($cred in $config.GuestCredentials) {
        if (-Not (Test-Path $cred.Credentials)) {
            throw ("Unable to find GuestOS Credential file for $($cred.CredentialName) at $($cred.Credentials) - Update config to a valid credentials path")
        }
    }

    # Credential Files are valid, let's now test connection to both VMware and Rubrik
    try {
        $viserver = Connect-VIServer $config.VMware.vCenterServer -Credential (Import-CLIXML $config.VMware.Credentials) -ErrorAction Stop 
    }
    catch {
        throw ("Unable to connect to VMware ($_)")
    }
    try {
        $rubrik = Connect-Rubrik -Server $config.Rubrik.RubrikCluster -Token (Import-CLIXML $config.Rubrik.APIAuthToken) -ErrorAction Stop
    }
    catch {
        throw ("Unable to connect to Rubrik ($_)")
    }

}
function Get-CredsConfig($credentialconfig) {
    if ($credentialconfig -ne "") {
        # Check path of config
        if (-Not (Test-Path $credentialconfig)) {
            Write-Warning -Message "$credentialconfig is not a valid path."
            exit
        }
        else {
            # We are good to go, load the config
            Write-Verbose -Message "Loading credential configuration from $credentialconfig"
            $config = Get-Content $credentialconfig | ConvertFrom-Json -Depth 5
            # Validate values
            Test-CredsConfig($config)
            return $config
        }
    }
    else {
        # No config passed, for now, just exist, in the future, we will prompt to build one
        Write-Warning -Message "No credential configuruation passed or the config is invalid. I need that to function :)"
        exit
    }
}
function Test-AppConfig($config) {
   
    $rubrik = Connect-Rubrik -Server $global:credcfg.Rubrik.RubrikCluster -Token (Import-CLIXML $global:credcfg.RUbrik.APIAuthToken)
    foreach ($vm in $config.virtualMachines) {
         # Check that specified VMs exist
        if ((Get-RubrikVM -Name $vm.Name -PrimaryClusterId "local").count -eq 0) {
            throw ("VM ($($vm.Name)) does not exist within Rubrik")
        } 
        # Ensure credentials are available
        if (($global:credcfg.GuestCredentials | Where {$_.CredentialName -eq "$($vm.credentials)"}).Count -eq 0 ) {
            throw ("Unable to find credentials in config labelled $($vm.credentials)")
        }

    }
}
function Get-AppConfig($applicationconfig) {
    if ($applicationconfig -ne "") {
        # Check path of config
        if (-Not (Test-Path $applicationconfig)) {
            Write-Warning -Message "$applicationconfig is not a valid path."
            exit
        }
        else {
            # We are good to go, load the config
            Write-Verbose -Message "Loading application configuration from $applicationconfig"
            $config = Get-Content $applicationconfig | ConvertFrom-Json -Depth 5
            Test-AppConfig($config)
            return $config
        }
    }
    else {
        # No config passed, for now, just exist, in the future, we will prompt to build one
        Write-Warning -Message "No application configuruation passed or the config is invalid. I need that to function :)"
        exit
    }
}
Function Get-IPv4NetworkInfo {
    Param
    (
        [Parameter(ParameterSetName="IPandMask",Mandatory=$true)] 
        [ValidateScript({$_ -match [ipaddress]$_})] 
        [System.String]$IPAddress,
 
        [Parameter(ParameterSetName="IPandMask",Mandatory=$true)] 
        [ValidateScript({$_ -match [ipaddress]$_})] 
        [System.String]$SubnetMask,
 
        [Parameter(ParameterSetName="CIDR",Mandatory=$true)] 
        [ValidateScript({$_ -match '^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/([0-9]|[0-2][0-9]|3[0-2])$'})]
        [System.String]$CIDRAddress,
 
        [Switch]$IncludeIPRange
    )
 
    # If @CIDRAddress is set
    if($CIDRAddress)
    {
         # Separate our IP address, from subnet bit count
        $IPAddress, [int32]$MaskBits =  $CIDRAddress.Split('/')
 
        # Create array to hold our output mask
        $CIDRMask = @()
 
        # For loop to run through each octet,
        for($j = 0; $j -lt 4; $j++)
        {
            # If there are 8 or more bits left
            if($MaskBits -gt 7)
            {
                # Add 255 to mask array, and subtract 8 bits 
                $CIDRMask += [byte]255
                $MaskBits -= 8
            }
            else
            {
                # bits are less than 8, calculate octet bits and
                # zero out our $MaskBits variable.
                $CIDRMask += [byte]255 -shl (8 - $MaskBits)
                $MaskBits = 0
            }
        }
 
        # Assign our newly created mask to the SubnetMask variable
        $SubnetMask = $CIDRMask -join '.'
    }
 
    # Get Arrays of [Byte] objects, one for each octet in our IP and Mask
    $IPAddressBytes = ([ipaddress]::Parse($IPAddress)).GetAddressBytes()
    $SubnetMaskBytes = ([ipaddress]::Parse($SubnetMask)).GetAddressBytes()
 
    # Declare empty arrays to hold output
    $NetworkAddressBytes   = @()
    $BroadcastAddressBytes = @()
    $WildcardMaskBytes     = @()
 
    # Determine Broadcast / Network Addresses, as well as Wildcard Mask
    for($i = 0; $i -lt 4; $i++)
    {
        # Compare each Octet in the host IP to the Mask using bitwise
        # to obtain our Network Address
        $NetworkAddressBytes +=  $IPAddressBytes[$i] -band $SubnetMaskBytes[$i]
 
        # Compare each Octet in the subnet mask to 255 to get our wildcard mask
        $WildcardMaskBytes +=  $SubnetMaskBytes[$i] -bxor 255
 
        # Compare each octet in network address to wildcard mask to get broadcast.
        $BroadcastAddressBytes += $NetworkAddressBytes[$i] -bxor $WildcardMaskBytes[$i] 
    }
 
    # Create variables to hold our NetworkAddress, WildcardMask, BroadcastAddress
    $NetworkAddress   = $NetworkAddressBytes -join '.'
    $BroadcastAddress = $BroadcastAddressBytes -join '.'
    $WildcardMask     = $WildcardMaskBytes -join '.'
 
    # Now that we have our Network, Widcard, and broadcast information, 
    # We need to reverse the byte order in our Network and Broadcast addresses
    [array]::Reverse($NetworkAddressBytes)
    [array]::Reverse($BroadcastAddressBytes)
 
    # We also need to reverse the array of our IP address in order to get its
    # integer representation
    [array]::Reverse($IPAddressBytes)
 
    # Next we convert them both to 32-bit integers
    $NetworkAddressInt   = [System.BitConverter]::ToUInt32($NetworkAddressBytes,0)
    $BroadcastAddressInt = [System.BitConverter]::ToUInt32($BroadcastAddressBytes,0)
    $IPAddressInt        = [System.BitConverter]::ToUInt32($IPAddressBytes,0)
 
    #Calculate the number of hosts in our subnet, subtracting one to account for network address.
    $NumberOfHosts = ($BroadcastAddressInt - $NetworkAddressInt) - 1
 
    # Declare an empty array to hold our range of usable IPs.
    $IPRange = @()
 
    # If -IncludeIPRange specified, calculate it
    if ($IncludeIPRange)
    {
        # Now run through our IP range and figure out the IP address for each.
        For ($j = 1; $j -le $NumberOfHosts; $j++)
        {
            # Increment Network Address by our counter variable, then convert back
            # lto an IP address and extract as string, add to IPRange output array.
            $IPRange +=[ipaddress]([convert]::ToDouble($NetworkAddressInt + $j)) | Select-Object -ExpandProperty IPAddressToString
        }
    }
    
    $SubnetMaskIP = [ipaddress]$SubnetMask
    $octets = $SubnetMaskIP.getAddressBytes()
    $binaryString = ""
    foreach ($octet in $octets) {
        $binaryString += [Convert]::ToString($octet,2)
    }

    $BitMask =  $binaryString.TrimEnd('0').Length
    # Create our output object
    $obj = New-Object -TypeName psobject
 
    # Add our properties to it
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "IPAddress"           -Value $IPAddress
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "SubnetMask"          -Value $SubnetMask
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "BitMask"             -Value $BitMask
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "NetworkAddress"      -Value $NetworkAddress
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "BroadcastAddress"    -Value $BroadcastAddress
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "WildcardMask"        -Value $WildcardMask
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "NumberOfHostIPs"     -Value $NumberOfHosts
    Add-Member -InputObject $obj -MemberType NoteProperty -Name "IPRange"             -Value $IPRange
 
    # Return the object
    return $obj
}
function Invoke-VyosRestCall {
    [cmdletbinding(SupportsShouldProcess)]
    param(
        $Endpoint,
        $Data
    )

    $body =@{}
    $body.Add("data",$Data)
    $body.Add("key","$($routercfg.RouterAPIKey)")
    $uri = "https://" + $routercfg.ManagementNetworkIP + "/" + $Endpoint 
    $response = Invoke-WebRequest -Uri $uri -SkipCertificateCheck -Body $body -Method POST

    #-=MWP=- TODO - Add in some error checking around the response from the router.
    return $response
}
function New-Router() {
    Write-Progress -Activity "Deploying New Router: Gathering VMware details"
    $vmHost = Get-VMHost $routercfg.VMwareHost
    $vmDatastore = Get-Datastore -Name $routercfg.VMwareDatastore
    Write-Verbose -Message "Importing new router"
    Write-Progress -Activity "Deploying New Router: Importing vApp"
    $rtr = Import-vApp -VMHost $vmHost –Source $rbk_router_ova -Datastore $vmDatastore -Name $routercfg.RouterName -Force
    $vm = Get-VM $routercfg.RouterName
    
    Write-Progress -Activity "Deploying New Router: Attaching eth0 to $($routercfg.ManagementNetwork)"
    Write-Verbose -Message "Attaching nic1 of router to management network"
    $vm | Get-NetworkAdapter -Name 'Network adapter 1' | Set-NetworkAdapter -NetworkName $routercfg.ManagementNetwork -Confirm:$false
    Write-Progress -Activity "Deploying New Router: Removing extra network adapter"
    Write-Verbose -Message "Removing Second NIC"
    $nic = $vm | Get-NetworkAdapter -Name 'Network adapter 2'
    Remove-NetworkAdapter -NetworkAdapter $nic -Confirm:$false

    Write-Progress -Activity "Deploying New Router: Powering on virtual machine $($vm.name) and waiting for VMware Tools"
    Write-Verbose -Message "Powering on VM and waiting for VMware tools status of running"
    Start-VM -vm $vm
    Write-Progress -Activity "Deploying New Router: Waiting for VMware Tools"
    Wait-Tools -VM $vm
    Start-Sleep -Seconds 10
    Write-Progress -Activity "Deploying New Router: Building initial network configuration"
    Write-Verbose -Message "Building initial configuration for router"

    $mgmt_network_info = Get-IPv4NetworkInfo -IPAddress $routercfg.ManagementNetworkIP -SubnetMask $routercfg.ManagementNetworkSubnet

    # Build out strings to inject into config
    $mgmtipbit = $mgmt_network_info.IPAddress + "/" + $mgmt_network_info.BitMask
    $mgmtnetsubnet = $mgmt_network_info.NetworkAddress + "/" + $mgmt_network_info.BitMask

    $rtconf = Get-Content $global:rbk_router_config_script -Raw
    $rtconf = $rtconf -Replace "MANAGEMENT_IP_BITMASK", $mgmtipbit
    $rtconf = $rtconf -Replace "MANAGEMENT_SUBNET_BITMASK", $mgmtnetsubnet
    $rtconf = $rtconf -Replace "MANAGEMENT_GATEWAY", $routercfg.ManagementNetworkGateway
    $rtconf = $rtconf -Replace "MANAGEMENT_IP", $routercfg.ManagementNetworkIP
    $rtconf = $rtconf -Replace "MANAGEMENT_NAME", $routercfg.ManagementNetwork
    $rtconf = $rtconf -Replace "RBKPASSWORD", $routercfg.RouterPassword
    $rtconf = $rtconf -Replace "RBKAPIKEY", $routercfg.RouterAPIKey

    $rtconf | Set-Content "$PSScriptRoot\rtr-ova\config-router-ready.sh"

    Write-Progress -Activity "Deploying New Router: Copying initial configuration to router - eth0 IP Address: $($routercfg.ManagementNetworkIP)"
    Copy-VMGuestFile -VM $routercfg.RouterName -LocalToGuest -Source "$PSScriptRoot\rtr-ova\config-router-ready.sh" -Destination "/config/" -GuestUser vyos -GuestPassword vyos
    Start-Sleep -Seconds 3
    Write-Progress -Activity "Deploying New Router: Modifing configuration permissions and executing script"
    Write-Verbose -Message "Changing initial configuration script permissions and executing"
    Start-SLeep -Seconds 5
    Invoke-VMScript -VM $vm -ScriptText "chmod 777 /config/config-router-ready.sh" -ScriptType Bash -GuestUser vyos -GuestPassword vyos
    Invoke-VMScript -VM $vm -ScriptText "/config/config-router-ready.sh" -ScriptType Bash -GuestUser vyos -GuestPassword vyos

    # Change vyos password after initial configuration
    Write-Progress -Activity "Modifying vyos default password"
    $data = '{"op": "set", "path": ["system", "login", "user", "vyos", "authentication", "plaintext-password","NewPass123!"]}'
    $r = Invoke-VyOSRestcall  -Data $data -Endpoint "configure"

    Write-Verbose -Message "Configuring isolated networks within VMware"
    Write-Progress -Activity "Deploying New Router: Configuring the RubrikSandbox vSwitch"
    $vswitch = Get-VirtualSwitch -Name "RubrikSandbox" -VMHost $vmhost -ErrorAction SilentlyContinue
    if ($null -eq $vswitch) {
        Write-Verbose -Message "Creating a new vSwitch for Sandbox Usage..."
        Write-Progress -Activity "Deploying New Router: RubrikSandbox not found, creating..."
        $vswitch = $vmhost | New-VirtualSwitch -Name "RubrikSandbox" -Confirm:$false
    }
    $vswitch = Get-VirtualSwitch -Name "RubrikSandbox" -VMHost $vmhost -ErrorAction SilentlyContinue
    Write-Progress -Activity "Deploying New Router: Proceeding with RubrikSandbox vSwitch"
    # Create the isolated port group
    Write-Verbose -Message "Creating port groups"   
    Write-Progress -Activity "Deploying New Router: Creating portgroups for isolated networks" 
    foreach ($network in $routercfg.IsolatedNetworks) {
        Write-Progress -Activity "Deploying New Router: Creating $($network.IsolatedPortGroup)"
        $portgroup = New-VirtualPortGroup -VirtualSwitch $vswitch -Name $network.IsolatedPortGroup -Confirm:$false -ErrorAction SilentlyContinue
        $isol_network_info = Get-IPv4NetworkInfo -IPAddress $network.InterfaceAddress -SubnetMask $network.InterfaceSubnet   
        $isolipbit = $isol_network_info.IPAddress + "/" + $isol_network_info.BitMask
        $isolmasqsubnet = $network.MasqueradeNetwork + "/" +  $isol_network_info.BitMask
        $isolnetsubnet = $isol_network_info.NetworkAddress + "/" +  $isol_network_info.BitMask

        Start-Sleep -Seconds 5
        Write-Verbose -Message "Connecting router to isolated port group"
        Write-Progress -Activity "Deploying New Router: Creating additional NIC on $($routercfg.RouterName) and attaching to $($network.IsolatedPortGroup) "
        New-NetworkAdapter -VM $vm -NetworkName $network.IsolatedPortGroup -StartConnected -Confirm:$false

        Start-Sleep -Seconds 10
    
        # need to figure out what eth# we just added
        $interface = "eth" + ($routercfg.IsolatedNetworks.Count).ToString()
        Write-Progress -Activity "Deploying New Router: Interface detected as $interface"
        
        # run api calls to configure it with IP
        Write-Progress -Activity "Deploying New Router: Assigning $isolipbit to $interface"
        $data = '{"op": "set", "path": ["interfaces", "ethernet", "'+$interface+'", "address", "'+$isolipbit+'"]}'
        $r = Invoke-VyOSRestcall  -Data $data -Endpoint "configure"
    
        Write-Progress -Activity "Saving configuration"
        $data = '{"op": "save", "path": []}'
        $r = Invoke-VyOSRestcall  -Data $data -Endpoint "config-file"
    
        Write-Progress -Activity "Deploying New Router: Creating NAT rules to translate $isolnetsubnet to $isolmasqsubnet"
        $data = '[{"op": "set", "path": ["nat","destination","rule","100","inbound-interface","eth0"]},
        {"op": "set", "path": ["nat", "destination", "rule", "100", "destination", "address", "'+$isolmasqsubnet+'"]},
        {"op": "set", "path": ["nat", "destination", "rule", "100", "translation","address","'+$isolnetsubnet+'"]}]'
        $r = Invoke-VyOSRestcall -Data $data -Endpoint "configure"
    
        Write-Progress -Activity "Deploying New Router: Configuring firewall to isolate $($network.IsolatedPortGroup)"
        $data = '[{"op": "set", "path": ["firewall","name","'+$network.IsolatedPortGroup+'","default-action","drop"]},
        {"op": "set", "path": ["firewall","name","'+$network.IsolatedPortGroup+'","enable-default-log"]}]'
        $r = Invoke-VyOSRestcall  -Data $data -Endpoint "configure"
    
        $data = '[{"op": "set", "path": ["firewall","name","'+$network.IsolatedPortGroup+'","rule","1","action","accept"]},
        {"op": "set", "path": ["firewall","name","'+$network.IsolatedPortGroup+'","rule","1","state","established","enable"]},
        {"op": "set", "path": ["firewall","name","'+$network.IsolatedPortGroup+'","rule","1","state","related","enable"]},
        {"op": "set", "path": ["firewall","name","'+$network.IsolatedPortGroup+'","rule","2","action","drop"]},
        {"op": "set", "path": ["firewall","name","'+$network.IsolatedPortGroup+'","rule","2","log","enable"]},
        {"op": "set", "path": ["firewall","name","'+$network.IsolatedPortGroup+'","rule","2","state","invalid","enable"]},
        {"op": "set", "path": ["firewall","name","'+$network.IsolatedPortGroup+'","rule","2","state","new","enable"]}]'
        $r = Invoke-VyOSRestcall  -Data $data -Endpoint "configure"
    
        $data = '{"op": "set", "path": ["interfaces","ethernet","'+$interface+'","firewall","in","name","'+$network.IsolatedPortGroup+'"]}'
        $r = Invoke-VyOSRestcall -Data $data -Endpoint "configure"
        Write-Progress -Activity "Deploying New Router: Saving Configuration"
        $data = '{"op": "save", "path": []}'
        $r = Invoke-VyOSRestcall  -Data $data -Endpoint "config-file"
    
        if ($network.DHCPEnabled) {
            Write-Progress -Activity "Deploying New Router: Creating DHCP Scope on $interace ($($network.DHCPScopeStart) - $($network.DHCPScopeEnd))"
            #MWP - left off here, need to destroy and try and recreate dhcp
            Write-Verbose -Message "DHCP"
            $data = '[{"op": "set", "path": ["service","dhcp-server","shared-network-name","'+$network.IsolatedPortGroup+'","authoritative"]},
            {"op": "set", "path": ["service","dhcp-server","shared-network-name","'+$network.IsolatedPortGroup+'","subnet","'+$isolnetsubnet+'","default-router","'+$network.InterfaceAddress+'"]},
            {"op": "set", "path": ["service","dhcp-server","shared-network-name","'+$network.IsolatedPortGroup+'","subnet","'+$isolnetsubnet+'","range","0","start","'+$network.DHCPScopeStart+'"]},
            {"op": "set", "path": ["service","dhcp-server","shared-network-name","'+$network.IsolatedPortGroup+'","subnet","'+$isolnetsubnet+'","range","0","stop","'+$network.DHCPScopeEnd+'"]},
            {"op": "set", "path": ["service","dhcp-server","shared-network-name","'+$network.IsolatedPortGroup+'","name-server","'+$network.DHCPNameserver+'"]}]'
            $r = Invoke-VyOSRestcall -Data $data -Endpoint "configure"
            Write-Progress -Activity "Deploying New Router: Saving Configuration"
            $data = '{"op": "save", "path": []}'
            $r = Invoke-VyOSRestcall  -Data $data -Endpoint "config-file"
        }


    }
    Write-Progress -Activity "Deploying New Router: Completed" -Completed
    return $vm
}
function Sync-Router() {
    # Check status of ova file
    Write-Verbose -Message "Checking for router ova"
    if (Test-path $global:rbk_router_ova) {
        Write-Verbose -Message "Router OVA found, continuing"
    }
    else {
        Write-Verbose -Message "No ova found, downloading"
        Invoke-RestMethod -Uri "https://rubrik-tm-use-cases.s3.amazonaws.com/rubrik-sandbox/vyos13.ova" -OutFile $global:rbk_router_ova
    }


    $vm = Get-VM $routercfg.RouterName -ErrorAction SilentlyContinue
    if ($vm) {
        if ($global:config_changed -eq "true") {
            Write-Verbose -Message "Configuration has changed for $($routercfg.RouterName) - Removing and reinstalling VM"
            Stop-VM -VM $vm -Confirm:$false
            Start-Sleep -Seconds 2
            Remove-VM $vm -DeletePermanently -Confirm:$false
            Get-VirtualSwitch -Name RubrikSandbox | Remove-VirtualSwitch -Confirm:$false
            $vm = New-Router
        }
        else {
            Write-Verbose -Message "Ensuring $($vm.name) is ready..."
            if ($vm.PowerState -ne 'PoweredOn') {
                Write-Verbose -Message "Powering on router"
                Start-VM -VM $vm
                WRite-Verbose -Message "Waiting for VMware tools"
                Wait-Tools -VM $vm
            } 
        }
    } 
    else {
        Write-Verbose -Message "Router ($($routercfg.RouterName)) cannot be found - Redeploying"
        $vm = New-Router
    }

    $vm = Get-VM -Name $routercfg.RouterName

    # Ensure Static Routes are created
    foreach ($network in $routercfg.IsolatedNetworks) {
        $isol_network_info = Get-IPv4NetworkInfo -IPAddress $network.InterfaceAddress -SubnetMask $network.InterfaceSubnet 
        $isolmasqsubnet = $network.MasqueradeNetwork + "/" +  $isol_network_info.BitMask
        Write-Verbose -Message "Creating static routes for $isolmasqsubnet"
        # Add Static Routes
        $route = Get-NetRoute -DestinationPrefix $isolmasqsubnet -ErrorAction SilentlyContinue

        if ($route) {
            Remove-NetRoute -DestinationPrefix $isolmasqsubnet -Confirm:$false
        }

        $InterfaceIndex = (Find-NetRoute -RemoteIPAddress $routercfg.ManagementNetworkGateway | Select -First 1 ).InterfaceIndex
        New-NetRoute -DestinationPrefix "$isolmasqsubnet" -InterfaceIndex $InterfaceIndex -NextHop $routercfg.ManagementNetworkIP -PolicyStore ActiveStore
    
    }
    return $vm
}
function Invoke-RubrikLiveMountsAsync {
    $jobstomonitor = @()

    foreach ($vm in $appcfg.virtualMachines) {
        Write-Verbose -Message "Processing $($vm.MountName)"
        # Scriptblock containing code to issue Async Live Mounts
        $scriptblock = {
            param ($vm, $routercfg, $credcfg, $appcfg)
            $viserver = Connect-VIServer -Server $credcfg.VMware.vCenterServer -Credential (Import-CLIxml $credcfg.VMware.Credentials)
            $rubrikcluster = Connect-Rubrik -Server $credcfg.Rubrik.RubrikCluster -Token (Import-CLIxml $credcfg.Rubrik.APIAuthToken)
            $starttime = Get-date -Format "MM/dd/yyyy hh:mm tt"
            # Get network settings - need these for later
            Write-Verbose -Message "Saving network configuration for VM $($vm.Name)"
            $nics = Get-VM $vm.name | Get-NetworkAdapter
            # Live Mount the VM
            Write-Verbose -Message "Live mounting $($vm.name) as $($vm.mountName)"
            $task = Get-RubrikVM -Name $vm.name -PrimaryClusterId local | Get-RubrikSnapshot -Latest | New-RubrikMount -HostID (Get-RubrikVMwareHost -Name $routercfg.VMwareHost -PrimaryClusterId local).id -MountName $vm.mountName -PowerOn
            # Monitor task till completion
            $mid = $task.id
            
            $event = Get-RubrikEvent -EventType Recovery -ObjectName $vm.name | Where-Object {$_.jobInstanceId -eq $mid}
            Write-Verbose -Message "Waiting for mount status of success"
            $attempts = 0
            while ($event.eventStatus -ne "Success"){
                $attempts++
                Start-Sleep -Seconds 6
                $event = Get-RubrikEvent -EventType Recovery -ObjectName $vm.name | Where-Object {$_.jobInstanceId -eq $mid}
                if ($attempts -gt 20) {
                    Write-Verbose -Message "VM Live Mount timeout"
                    $vmInfo = (@{
                        ProductionName="$($vm.Name)"
                        MountName = "$($vm.mountName)"
                        MountStatus = "Failed"
                        Credentials = "$($vm.credentials)"
                        IsolatedIP = "not available"
                        MasqIP = ""
                        StartTime = "$starttime"
                        EndTime = ""
                        MoidLink = ""
                        Tests = @()
                    })
                    $test = New-Object -TypeName PSCustomObject
                    $test | Add-Member -NotePropertyName "Name" -NotePropertyValue "Ping"
                    $test | Add-Member -NotePropertyName "Status" -NotePropertyValue "Skipped"
                    $test | Add-Member -NotePropertyName "Result" -NotePropertyValue "Skipped"
                    $test | Add-Member -NotePropertyName "MoreInfo" -NotePropertyValue "Live Mount Failed"
                    $test | Add-Member -NotePropertyName "ShortMore" -NotePropertyValue "Live Mount Failed"

                    $vmInfo.tests += $test

                  
                    $test = New-Object -TypeName PSCustomObject
                    $test | Add-Member -NotePropertyName "Name" -NotePropertyValue "VMwareTools"
                    $test | Add-Member -NotePropertyName "Status" -NotePropertyValue "Skipped"
                    $test | Add-Member -NotePropertyName "Result" -NotePropertyValue "Skipped"
                    $test | Add-Member -NotePropertyName "MoreInfo" -NotePropertyValue "Live Mount Failed"
                    $test | Add-Member -NotePropertyName "ShortMore" -NotePropertyValue "Live Mount Failed"
                    $vmInfo.tests += $test
                    return $vmInfo
                }
            }
            # Attach VM to proper networks
            $mountedvm = Get-VM $vm.mountName
            Write-Verbose -Message "Attaching VM to proper isolated networks"
            foreach ($nic in $nics){
                $isolatednetwork = $routercfg.IsolatedNetworks | ?{ $_.ProductionNetworkName -eq "$($nic.NetworkName)"}
                if ($isolatednetwork.count -ge 1){
                    Write-Verbose -Message "Attaching $($nic.Name) to $($isolatednetwork.IsolatedPortGroup)"
                    Get-NetworkAdapter -VM $mountedvm -Name $nic.Name | Set-NetworkAdapter -NetworkName $isolatednetwork.IsolatedPortGroup -Connected $true -StartConnected $true -Confirm:$false | Out-Null
                }
                else {
                    #-=MWP=- We need to do more than just output a message here, we need to ensure that any tests which require network connectivity
                    # basically, anything that doesn't use Invoke-VMScript are skipped
                    Write-Verbose -Message "No isolated network found matching $($nic.NetworkName)"
                }
            }
        
            # Wait a bit to allow VM Tools to get an initialize status
            Start-Sleep -Seconds 15
            # Get VM status again
            $mountedvm = Get-VM $vm.mountName
            # Wait for VM tools to begin
            Wait-Tools -VM $mountedvm -TimeoutSeconds 120 -ErrorAction SilentlyContinue
            #-=MWP=- Need to do more here, if VMware Tools cannot be found running then the VMwareTools test needs to be skipped
            # along with any other tests that rely on Tools
            # Check to see if we have an IP yet
            $mountedvmip = (Get-VM $vm.mountName).guest.IPAddress[0] 
            $vmmoid = $mountedvm.id.split("-")[2]
            if ($null -eq $mountedvmip) {
                $round = 1
                while ($null -eq $mountedvmip){
                    Write-Verbose -Message "Waiting to obtain IP for VM... Attempt $round of 3"
                    Start-Sleep -Seconds 30
                    $mountedvmip = (Get-VM $vm.mountName).guest.IPAddress[0] 
                    if ($null -ne $mountedvmip) {
                        Write-Verbose -Message "IP of $mountedvmip found!"
                        break
                    }
                    else {
                        if ($round -gt 3){
                            $mountedvmip = "not available"
                            break
                        }
                    }
                    $round++
                }
            }

            $vmInfo = (@{
                ProductionName="$($vm.Name)"
                MountName = "$($vm.mountName)"
                MountStatus = ""
                Credentials = "$($vm.credentials)"
                IsolatedIP = "$mountedvmip"
                MasqIP = ""
                StartTime = "$starttime"
                EndTime = ""
                MoidLink = "vmrc://$($credcfg.Vmware.vCenterServer)/?moid=vm-$($vmmoid)"
                Tests = @()
            })

            if ($lmstatus -eq "Failed") { 
                $vminfo.MountStatus = "Failed" 
            }
            
            foreach ($test in $vm.tasks) {
                $test | Add-Member -NotePropertyName "Status" -NotePropertyValue "NotStarted"
                $test | Add-Member -NotePropertyName "Result" -NotePropertyValue ""
                $test | Add-Member -NotePropertyName "MoreInfo" -NotePropertyValue ""
                $test | Add-Member -NotePropertyName "ShortMore" -NotePropertyValue ""
        
                $vmInfo.tests += $test
            }

            # Now let's add the default tests if applicable
            if ($true -eq $vm.skipPingTest) {
                $test = New-Object -TypeName PSCustomObject
                $test | Add-Member -NotePropertyName "Name" -NotePropertyValue "Ping"
                $test | Add-Member -NotePropertyName "Status" -NotePropertyValue "Skipped"
                $test | Add-Member -NotePropertyName "Result" -NotePropertyValue "Skipped"
                $test | Add-Member -NotePropertyName "MoreInfo" -NotePropertyValue ""
                $test | Add-Member -NotePropertyName "ShortMore" -NotePropertyValue "User Instructed"
            } else {
                $test = New-Object -TypeName PSCustomObject
                $test | Add-Member -NotePropertyName "Name" -NotePropertyValue "Ping"
                $test | Add-Member -NotePropertyName "Status" -NotePropertyValue "NotStarted"
                $test | Add-Member -NotePropertyName "Result" -NotePropertyValue ""
                $test | Add-Member -NotePropertyName "MoreInfo" -NotePropertyValue ""
                $test | Add-Member -NotePropertyName "ShortMore" -NotePropertyValue ""
            }
            $vmInfo.tests += $test

            if ($vm.skipToolsTest) {
                $test = New-Object -TypeName PSCustomObject
                $test | Add-Member -NotePropertyName "Name" -NotePropertyValue "VMwareTools"
                $test | Add-Member -NotePropertyName "Status" -NotePropertyValue "Skipped"
                $test | Add-Member -NotePropertyName "Result" -NotePropertyValue "Skipped"
                $test | Add-Member -NotePropertyName "MoreInfo" -NotePropertyValue ""
                $test | Add-Member -NotePropertyName "ShortMore" -NotePropertyValue "User Instructed"
            } else {
                $test = New-Object -TypeName PSCustomObject
                $test | Add-Member -NotePropertyName "Name" -NotePropertyValue "VMwareTools"
                $test | Add-Member -NotePropertyName "Status" -NotePropertyValue "NotStarted"
                $test | Add-Member -NotePropertyName "Result" -NotePropertyValue ""
                $test | Add-Member -NotePropertyName "MoreInfo" -NotePropertyValue ""
                $test | Add-Member -NotePropertyName "ShortMore" -NotePropertyValue "" 
            }
            $vmInfo.tests += $test

            $vmInfo
        }
        $job =  Start-Job -Name $vm.MountName -ScriptBlock $scriptblock -ArgumentList $vm, $routercfg, $credcfg, $appcfg
        $jobstomonitor += $job.id
    }
    Start-Sleep -Seconds 5

    #-=MWP=- there has to be a better way of doing this lol
    $alljobs = Get-Job | Where {$_.id -in $jobstomonitor}

    $totaljobs = $alljobs.count
    $completedjobs = 0
    $jobsnotrunning = @()

    while ($totaljobs -gt $completedjobs) {
        $jobs = $alljobs | Where {$_.id -notin $jobsnotrunning}
        
        foreach ($job in $jobs) {
            if ($job.State -ne "Running") {
                $completedjobs ++
                $jobsnotrunning += $job.id
            }
        }
        Write-Verbose -Message "Live Mount: $($completedjobs) of $totaljobs VMs Complete - Waiting on $($jobs.Name)"
        Start-Sleep -Seconds 5
    }
    $vmsToTest = @()
    foreach ($job in $alljobs) {
        if ($job.State -eq "Completed") {
            $vmInfo = $job | Receive-Job
            if ($vmInfo.MountStatus -ne "Failed") {
                $vmInfo.MountStatus = "Success"
            }

        } else {
            $vmInfo = $job | Receive-Job
            $vmInfo.MountStatus = "Failed"
        }
        $vmsToTest += $vmInfo
    }

    #Update Masq IP
    foreach ($vm in $vmsToTest) {
        # Figure out masquerade ip of mounted vm
        if ($vmInfo.MountStatus -eq "Success") {
            if ($vm.IsolatedIP -ne "not available") {
                $mountedvm = Get-VM $vm.MountName
                $mountedvmip = $vm.IsolatedIP
                $prodnet = (Get-NetworkAdapter -VM $mountedvm).NetworkName
                $isolnet = $routercfg.IsolatedNetworks | ?{ $_.IsolatedPortGroup -eq "$prodnet"}
                $masqsubnet = $isolnet.MasqueradeNetwork
                $netinfo = Get-IPv4NetworkInfo -IPAddress $vm.IsolatedIP -SubnetMask $isolnet.InterfaceSubnet 
                $octets_to_keep = ($netinfo.WildcardMask.split('.') | group | where {$_.Name -eq '0'}).Count
                $newip = ""
                for(($i=0); $i -lt $octets_to_keep;$i++ ) {
                    # get the octet from the prod add
                    $newip = $newip + $masqsubnet.split('.')[$i] + "."
                }
            
                $i = 1
                foreach ($octet in $mountedvmip.split('.')){
                    if ($i -gt $octets_to_keep) {
                        $newip = $newip + $octet + "."
                    }
                    $i++ 
                }
                $newip = $newip.Substring(0,$newip.Length-1)
                Write-Verbose -Message "Masquerade IP address calculated as $newip"    
            }
            else {
                $newip = "not available"
            }
            $vm.MasqIP = $newip
            if ($newip -eq "not available"){
                $test = $vm.tests | Where {$_.Name -eq "Ping"}
                $test.Status = "Skipped"
                $test.Result = "Skipped"
                $test.ShortMore = "IP not found"
            }
        } 
    }
    
    return [array]$vmsToTest
}
function Invoke-RubrikTests {
    # Let's go throught each VM
    # -=MWP=- Once we have established error checking around Live Mounts, the following loop will need to be modified to only
    # process those VMs which have been Live Mounted successfully
    for ($i=0;$i -le $vmsToTest.Count -1; $i++) {
        Write-Verbose -Message "Beginning tests on $($vmsToTest[$i].ProductionName)"
        # global variables established to pass between files
        # can't just pass as argument
        $global:vmProcessing = $vmsToTest[$i]
        $tests = $vmsToTest[$i].Tests
        for ($j=0;$j -le $tests.Count -1;$j++){
            if ($($tests[$j].Status -ne "Skipped")) {
                $global:testProcessing = $tests[$j]
                Invoke-Expression "$($tests[$j].Name)"
                $tests[$j] = $global:testProcessing
            }

        }
        $vmsToTest[$i].Tests = $tests
        $endtime = Get-date -Format "MM/dd/yyyy hh:mm tt"
        $vmsToTest[$i].EndTime = "$endtime"


    }
    
    return [array]$vmsToTest
}
function New-RestoreValidationReport {
    #-=MWP=- this is all still very much work in progress
    Write-Verbose "Generating HTML report"

    $numSuccess = 0
    foreach ($vm in $VMResults) {
        if ($vm.MountStatus -eq "Success") {
            $numSuccess ++
        }
    }
    $numFailed = $VMResults.Count - $numSuccess
    
    $report = [System.Text.StringBuilder]::new()
    $report.Append("<HTML><HEAD><TITLE>Rubrik Recovery Validation Report</TITLE><link rel='stylesheet' href='styles.css'></HEAD><BODY>")
    $date = Get-Date
    $report.Append("<h1>Rubrik Sandbox - Restore Validation Report - $date</h1>")
    $report.Append("<h2>Run Details</h2>")
    $report.Append("<table class='info'><tr><th>Router Name</th><td>$($routercfg.RouterName)</td><th>Start Time</th><td>$scriptstart</td></tr>")
    $report.Append("<tr><th>IP Address</th><td>$($routercfg.ManagementNetworkIP)</td><th>End Time</th><td>$scriptend</td></tr>")
    $report.Append("<tr><th>Management Network</th><td>$($routercfg.ManagementNetwork)</td><th>Total VMs</th><td>$($appcfg.virtualMachines.Count)</td></tr>")
    $report.Append("<tr><th>VMware Host</th><td>$($routercfg.VMwareHost)</td><th>Processed VMs</th><td>$($VMResults.Count)</td></tr>")
    $report.Append("<tr><th>VMware Datastore</th><td>$($routercfg.VMwareDatastore)</td><th>Live Mount Successful</th><td>$numSuccess</td></tr>")
    $report.Append("<tr><th>Isolated Networks</th><td>")
    foreach ($isolnet in $($routercfg.IsolatedNetworks)){
        $report.Append("$($isolnet.IsolatedPortGroup) - $($isolnet.MasqueradeNetwork)<br>")
    }
    $report.Append("</td><th>Live Mount Failed</th><td>$numFailed</td></tr>")
    $report.Append("</table>")
    
    $report.Append("<h2>Virtual Machine Information</h2>")
    $report.Append("<table><thead><tr><td>VM Name</td><td>Mount Status</td><td>Start time</td><td>End time</td><td>Ping Test</td><td>Tools Test</td><td>Other Tests</td></tr></thead><tbody>")
    # Create some HTM
    foreach ($vm in $vmResults) {
        $report.Append("<tr><td>")
        if ($appcfg.settings.leaveLabRunning) {
            $report.Append("<a href='$($vm.MoidLink)'>$($vm.ProductionName)</a>")
        }
        else {
            $report.Append("$($vm.ProductionName)")
        }
        $report.Append("</td><td class='$($vm.MountStatus)'>$($vm.MountStatus)</td>")
        # Get the Ping Test Results
        $pingtest = $vm.Tests | Where-Object {$_.Name -eq "Ping"}
        $toolstest =  $vm.Tests | Where-Object {$_.Name -eq "VMwareTools"}
        #if ($pingtest.Result -eq "Passed" -and $toolstest.Result -eq "Passed") {
        #    $report.Append("<td class='Passed'>Passed</td>")
        #} else {
        #    $report.Append("<td class='Failed'>Failed</td>")
        #}
        $report.Append("<td>$($vm.StartTime)</td><td>$($vm.EndTime)</td>")
        $report.Append("<td class='")
        $report.Append($($pingtest.Result))
        $report.Append("'>$($pingtest.Result)")
        if ($($pingtest.Status -eq "Skipped")) {
            $report.Append("<br>$($pingtest.ShortMore)")
        }
        $report.Append("</td>")
        $report.Append("<td class='")
        $report.Append($($toolstest.Result))
        $report.Append("'>$($toolstest.Result)")
        if ($($toolstest.Status -eq "Skipped")) {
            $report.Append("<br>$($toolstest.ShortMore)")
        }
        $report.Append("</td><td>")
        if ($vm.MountStatus -eq "Failed") {
            $report.Append("Skipped All<BR>Live Mount Failed")
        }
        else {
            $tests = $vm.Tests | Where {$_.Name -notin "Ping","VMwareTools"}
            foreach ($test in $tests) {
                $report.Append("$($test.Name) ($($test.ShortMore)): <span class='")
                $report.Append("$($test.Result)'>$($test.Result)</span><br>")
                
            }
        }

        $report.Append("</td></tr>")
    }
    $report.Append("</tbody></table>")
    
    $report.Append("</BODY></HTML>")
    
    $report.ToString() | Out-File $appcfg.Settings.reportPath
    return $report
}


# Get the start time
$scriptstart = Get-date -Format "MM/dd/yyyy hh:mm tt"

# Load configs into global vars
$global:credcfg = Get-CredsConfig($credentialconfig)
$global:routercfg = Get-RouterConfig($routerconfig)
$global:appcfg = Get-AppConfig($applicationconfig)

# Connect to vCenter
Write-Verbose -Message "Connecting to vCenter Server ($($credcfg.VMware.vCenterServer))"
$viserver = Connect-VIServer -Server $credcfg.VMware.vCenterServer -Credential (Import-CLIxml $credcfg.VMware.Credentials)

# Alright, let's now check to see if we have a router already!
$router = Sync-Router



# Connect to Rubrik
Write-Verbose -Message "Connecting to Rubrik Cluster ($($credcfg.Rubrik.RubrikCluster))"
$rubrikcluster = Connect-Rubrik -Server $credcfg.Rubrik.RubrikCluster -Token (Import-CLIxml $credcfg.Rubrik.APIAuthToken)

# Live Mount VMs
$vmsToTest = Invoke-RubrikLiveMountsAsync

# Sometimes, this was getting returned as a single object, let's force it to an array
if ($vmsToTest.getType().Name -ne "Object[]") {
    $vmsToTest = [array]$vmsToTest
}

# Run tests
$VMResults = Invoke-RubrikTests
# Again with this single item array odd stuff#
if ($VMResults.getType().Name -ne "Object[]") {
   $VMResults = [array]$VMResults
}

# Get the end time
$scriptend = Get-date -Format "MM/dd/yyyy hh:mm tt"

# Generate Report
if ($appcfg.settings.generateReport) {
    $report = New-RestoreValidationReport
}


# And finally, if applicable, remove Live Mounts
if ($false -eq $appcfg.settings.leaveLabRunning) {
    # Remove Live Mounts
    foreach ($vm in $appcfg.virtualMachines) {
        Write-Verbose -Message "Removing $($vm.MountName) Live Mount"
        $mountedvm = Get-RubrikMount | Where { (Get-RubrikVM -id $_.mountedVmId).Name -eq "$($vm.MountName)" }
        Remove-RubrikMount -id $mountedvm.id | Out-Null
    }
}
