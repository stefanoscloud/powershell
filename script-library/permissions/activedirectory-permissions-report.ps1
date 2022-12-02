Import-Module ActiveDirectory
# Array for report.
$report = @()
$schemaIDGUID = @{}
# ignore duplicate errors if any #
$ErrorActionPreference = 'SilentlyContinue'
Get-ADObject -SearchBase (Get-ADRootDSE).schemaNamingContext -LDAPFilter '(schemaIDGUID=*)' -Properties name, schemaIDGUID |
 ForEach-Object {$schemaIDGUID.add([System.GUID]$_.schemaIDGUID,$_.name)}
Get-ADObject -SearchBase "CN=Extended-Rights,$((Get-ADRootDSE).configurationNamingContext)" -LDAPFilter '(objectClass=controlAccessRight)' -Properties name, rightsGUID |
 ForEach-Object {$schemaIDGUID.add([System.GUID]$_.rightsGUID,$_.name)}
$ErrorActionPreference = 'Continue'
# Get a list of AD objects.
$AOs  = @(Get-ADDomain | Select-Object -ExpandProperty DistinguishedName)
$AOs += Get-ADOrganizationalUnit -Filter * | Select-Object -ExpandProperty DistinguishedName
$AOs += Get-ADObject -SearchBase (Get-ADDomain).DistinguishedName -SearchScope Subtree -LDAPFilter '(objectClass=*)' | Select-Object -ExpandProperty DistinguishedName
# Loop through each of the AD objects and retrieve their permissions.
# Add report columns to contain the path.
ForEach ($AO in $AOs) {
    $report += Get-Acl -Path "AD:\$AO" |
     Select-Object -ExpandProperty Access | 
     Select-Object @{name='organizationalunit';expression={$AO}}, `
                   @{name='objectTypeName';expression={if ($_.objectType.ToString() -eq '00000000-0000-0000-0000-000000000000') {'All'} Else {$schemaIDGUID.Item($_.objectType)}}}, `
                   @{name='inheritedObjectTypeName';expression={$schemaIDGUID.Item($_.inheritedObjectType)}}, `
                   *
} # Filter by single user and export to a CSV file.
$User ='Username'
$report | Where-Object {$_.IdentityReference -like "*$User*"} | Select-Object IdentityReference, ActiveDirectoryRights, OrganizationalUnit, IsInherited -Unique |
Export-Csv -Path "C:\data\explicit_permissions.csv" -NoTypeInformation

#Source: https://www.netwrix.com/how_to_get_ad_user_permissions_report.html
