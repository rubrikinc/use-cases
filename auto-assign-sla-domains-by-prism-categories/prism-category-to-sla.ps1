param (
    [Parameter(Mandatory=$false)]
    [ValidateScript({Test-Path $_})]
    [String]$ConfigFile
)

function Invoke-NutanixRestCall {
    param (
        [string]$endpoint,
        [string]$method,
        [string]$body
    )
    $Uri = "https://$($Config.Nutanix.PrismAddress):9440/$endpoint"
    $returnVals = Invoke-RestMethod -uri $Uri -Body $body -Method $method -Headers $Headers  -ContentType "application/json" -SkipCertificateCheck
    return $returnVals
}

function New-ConfigurationFile {
    if (!($ConfigFilePath = Read-Host "What directory would you like to store the configuration file in? [c:\nutanix\cfg] ")) {$ConfigFilePath = "C:\nutanix\cfg"}
    if (-not (Test-Path $ConfigFilePath)) {
        Write-Output "$ConfigFilePath doesn't exist, proceeding to create..."
        New-Item -Path $ConfigFilePath -ItemType Directory | Out-Null
        Write-Output "$ConfigFilePath created..."
    }
    if (!($ConfigFileName = Read-Host "What would you like to name the config file? [config.json] ")) {$ConfigFileName = "config.json"}
    if (!($CredentialPath = Read-Host "What directory would you like to save encrypted credentials for Prism/Rubrik in? [c:\nutanix\creds] ")) {$CredentialPath = "c:\nutanix\creds"}
    if (-not (Test-Path $CredentialPath)) {
        Write-Output "$CredentialPath doesn't exist, proceeding to create..."
        New-Item -Path $CredentialPath -ItemType Directory | Out-Null
        Write-Output "$CredentialPath created..."
    }
    # Prompt for Nutanix Address
    $PrismAddress = Read-Host "What is the IP/FQDN of your Prism instance? "
    # Prompt for Nutanix Credentials
    $PrismCredentials = Get-Credential -Message "Enter Nutanix Credentials for $PrismAddress "
    $PrismCredentials | EXPORT-CLIXML -Path "$CredentialPath\NutanixCreds.xml"
    # Prompt for Prism Category to utilize
    $PrismCategory = Read-Host "What Category within Prism holds the values of Rubrik SLA Domains? "
    if (!($AutoUpdateFlag = Read-Host "Would you like to have the script automatically create and populate your Prism category and associated values based off of your Rubrik SLA Domains [Y/n] ? ")) {$AutoUpdateFlag = "Y"}
    if ($AutoUpdateFlag.toUpper() -eq "Y" -or $AutoUpdateFlag -eq "") {
        $AutoUpdateFlag = "True"
    } else {
        $AutoUpdateFlag = "False"
    }
    # Prompt for Rubrik Credentials
    $RubrikAddress = Read-Host "What is the IP/FQDN of your Rubrik cluster? "
    $RubrikCredentials = Get-Credential -Message "Enter Rubrik Credentials for $RubrikAddress "
    $RubrikCredentials | EXPORT-CLIXML -Path "$CredentialPath\RubrikCreds.xml"

    $CredentialPath = $CredentialPath.replace("\","\\")
    #$ConfigFilePath = $ConfigFilePath.replace("\","\\")

    $ConfigToWrite = @"
    {
        "Nutanix": {
            "PrismAddress": "$PrismAddress",
            "PrismCredentials": "$CredentialPath\\NutanixCreds.xml",
            "PrismCategory": "$PrismCategory",
            "AutoUpdate": "$AutoUpdateFlag"
        },
        "Rubrik": {
            "RubrikAddress": "$RubrikAddress",
            "RubrikCredentials": "$CredentialPath\\RubrikCreds.xml"
        }
    }
"@
    $ConfigToWrite | Out-File -FilePath $ConfigFilePath\$ConfigFileName
    Write-Output "Configuration file written to $ConfigFilePath/$ConfigFileName"
    if (!($answer = Read-Host "Would you like to run the script with the new configuration file now [Y/n]? ")) {$answer -eq "Y"}
    if ($answer.toUpper() -eq "Y"){
        Invoke-Expression -Command "$PSCommandPath -ConfigFile $ConfigFilePath/$ConfigFileName -Verbose"
        exit
    } else {
        Write-Output "All done, you can trigger the script with the following command"
        Write-Output "$PSCommandPath -ConfigFile $ConfigFilePath/$ConfigFileName -Verbose"
        exit
    }
}
# If no configuration file, prompt to create one
if (-not ($ConfigFile)) {
    Write-Output "Script has been called without the ConfigFile parameter"
    if (!($answer = Read-Host "Would you like to create a new configuration file now [Y/n] ? " )) {$answer = "Y"}
    if ($answer.toUpper() -eq "Y" ) {
        New-ConfigurationFile
    } else {
        Write-Output "Please call script with the ConfigFile parameter populated, exiting"
        exit
    }
}

# Load configuration
Write-Verbose -Message "Loading script configuration from $ConfigFile"
$script:Config = Get-Content -Path $ConfigFile | ConvertFrom-Json
$SLADomainCategory = $Config.Nutanix.PrismCategory

# Build out headers for Nutanix
$NutanixCredentials = IMPORT-CLIXML $config.Nutanix.PrismCredentials
$RESTAPIUser = $NutanixCredentials.UserName
$RESTAPIPassword = $NutanixCredentials.GetNetworkCredential().Password
$Headers = @{
    "Authorization" = "Basic "+[System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($RESTAPIUser+":"+$RESTAPIPassword ))
}

# Establish connection to Rubrik
Connect-Rubrik $config.Rubrik.RubrikAddress -Credential (Import-CLIXML $Config.Rubrik.RubrikCredentials) | Out-Null

# Ensure category exists in prism, if not, create it
Write-Verbose -Message "Checking if $SLADomainCategory exists in Prism..."
$categories = (Invoke-NutanixRestCall -endpoint "api/nutanix/v3/categories/list" -method "POST" -body '{"kind":"category"}').entities
if (-not ($categories.name -contains $SLADomainCategory)) {
    if ($Config.Nutanix.AutoUpdate -eq "True") {
        Write-Verbose -Message "$SLADomainCategory doesn't exist within Nutanix Prism, creating it now..."
        $endpoint = "api/nutanix/v3/categories/$SLADomainCategory"
        $body = @"
        {
            "name": "$SLADomainCategory"
        }
"@
        $result = Invoke-NutanixRestCall -endpoint $endpoint -body $body -method "PUT"
    } else {
        Write-Verbose -Message "Category $SLADomainCategory doesn't exist within Prism"
        Write-Verobse -Message "Either set the AutoUpdate flag to true in the config file or manually add the category"
        Write-Verbose -Message "Script will now exit"
        exit
    }
} else {
    Write-Verbose -Message "$SLADomainCategory found in Prism"
}

# Ensure all SLA domains within Rubrik exist as category value in prism
$RubrikSLADomains = Get-RubrikSLA -PrimaryClusterID local | Where-Object {$null -eq $_.polarisManagedId}
$body = '{"kind":"category"}'
$categoryValues = (Invoke-NutanixRestCall -endpoint "api/nutanix/v3/categories/$SLADomainCategory/list" -body $body -method "post").entities

foreach ($SLADomain in $RubrikSLADomains) {
    Write-Verbose -Message "Checking if $($SLADomain.name) exists as category value"
    if (-not ($categoryValues.value -contains $SLADomain.Name)) {
        if ($Config.Nutanix.AutoUpdate -eq "True") {
            Write-Verbose "Category value of $($SLADomain.name) doesn't exist within $SLADomainCategory, adding..."
            $endpoint = "api/nutanix/v3/categories/$SLADomainCategory/$($SLADomain.name)"
            $body = @"
            {
                "value": "$($SLADomain.name)"
            }
"@
            $returnResults = Invoke-NutanixRestCall -endpoint $endpoint -body $body -method "put"
        } else {
            Write-Warning -Message "$($SLADomain.name) doesn't exist as category value within $SLADomainCategory"
            Write-Verbose -Message "$($SLADomain.name) will not be used in the SLA Domain mapping process"
            Write-Verbose -Message "To use $($SLADomain.name) add it as a value manually to $SLADomainCategory or enable the AutoUpdate flag within the configuration file"
        }
    } else {
        Write-Verbose -Message "Found $($SLADomain.name) as category value"
    }
}

Write-Verbose -Message "Proceeding to map values of Prism Category ($SLADomainCategory) to Rubrik SLA Domains"
# Get list of all values within $SLADomainCategory
$body = '{"kind":"category"}'
$categoryValues = (Invoke-NutanixRestCall -endpoint "api/nutanix/v3/categories/$SLADomainCategory/list" -body $body -method "post").entities

#Loop through each category value
foreach ($categoryValue in $categoryValues) {
    $catVal = $categoryValue.value
    #Ensure SLA Domain exists within Rubrik
    $sladomain = Get-RubrikSLA -Name $catVal -PrimaryClusterID $local
    if ($sladomain) {
        Write-Verbose -Message "Processing SLADomain $catVal"

        # Retrieve list of VMs in category
        $body = @"
        {
            "usage_type": "APPLIED_TO",
            "group_member_offset": 0,
            "group_member_count": 100,
            "category_filter": {
            "type": "CATEGORIES_MATCH_ANY",
            "params": {
                "$SLADomainCategory": ["$catVal"]
        },
        "kind_list": ["vm"]
            },
            "api_version": "3.1.0"
        }
"@
        $vms = (Invoke-NutanixRestCall -endpoint "api/nutanix/v3/category/query" -body $body -method "post" ).results.kind_reference_list
        if ($vms) {
            # loop through each vm in vms and assign to proper SLA Domain ($catVal)
            foreach ($vm in $vms) {
                # Check if VMs SLA Domain needs to be changed
                $RubrikVM = Get-RubrikNutanixVM -Name "$($vm.name)"
                if ($RubrikVM.effectiveSLADomainName -ne "$catVal") {
                    Write-Verbose -Message "Adding $($vm.name) to $catVal"
                    # Assign SLA in Rubrik
                    Get-RubrikNutanixVM -Name "$($vm.name)" | Protect-RubrikNutanixVM -SLA $catVal
                } else {
                    Write-Verbose -Message "$($vm.name) is already a member of $catVal - no change required"
                }
            }
        } else {
            Write-Verbose -Message "No VMs found within $catval category"
        }
    }
    else {
        Write-Verbose -Message "$catVal doesn't exist in Rubrik, skipping"
    }
}