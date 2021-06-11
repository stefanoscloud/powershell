#region Namespaces
using namespace System.Management.Automation.Host
#endregion Namespaces

#region ScriptRequirements
#requires -version 4
#requires -Modules logging
#endregion ScriptRequirements

#region Documentation
<#
.SYNOPSIS
  This script automates the Fermorite Cloud Citrix VDA server weekly reboot schedule

.DESCRIPTION
  The script carries out the following tasks on a weekly basis. It can be triggered via scheduled task or manually by an administrator user. 
    * Put all Citrix VDA servers into maintenance mode
    * Start logging off all users from the VDAs
    * Wait until all users are fully logged off (all file server sessions are closed)
    * Perform proactive disk health checks on all Cloud servers
    * Install all latest application updates from PatchMyPC
    * Reboot all VDA servers
    * Run delprof on all VDA servers
    * Check all Windows automatic services running status
    * Citrix VDA maintenance mode off for demo VDA server only
  
  The script must be run on the daas-mgmt server in elevated Powershell window with an administrator user who is member of the FrmOperations AD security group.
  The script utilizes Windows PowerShell remoting and thus all remote VDA computers must be configured for remote management: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_remote_requirements?view=powershell-7.1
  After the script run is complete, the administrator must check the script execution log under C:\Scripts\Cloud folder to ensure that no errors occured and then launch a demo Citrix desktop to confirm operations

  Last manual step is to: 
      * Citrix VDA maintenance mode off for remaining Citrix VDA servers

.PARAMETER VDAServerList
  Provide name of csv file containing the list of Citrix VDA servers to maintain and reboot.

.INPUTS Csv File
  The script takes a VDAServers.csv file as input.

.OUTPUTS Log File
  The script execution log file is stored in C:\Scripts\Cloud\CloudMaintenance.log

.NOTES
  Version:        1.0
  Author:         Fermorite Cloud
  Creation Date:  10 March 2021
  Purpose/Change: Initial script development
  External PS repositories:   The script utilizes the following reposities and modules: 
    * Powershell Logging functions from https://github.com/EsOsO/Logging/wiki/Usage.   
    * Get-ActiveSessions Function: https://github.com/ThePoShWolf/Utilities/blob/master/ActiveSessions/Get-ActiveSessions.ps1
    * Powershell menu using .NET objects: https://adamtheautomator.com/powershell-menu/ 

.EXAMPLE
  Fermorite-Cloud-Maintenance-VDA.ps1 VDAServers.csv
  
  Run the Citrix VDA maintenance script for all servers included in the VDAServers.csv file.
#>
#endregion Documentation

#region StaticVariables
#----------------------------------------------------------[Static Variables]----------------------------------------------------------
#Script Version
$sScriptVersion = '1.0'
#Log File Info
$sLogPath = 'C:\Scripts\Cloud\Logs'
$sCurrentDate = (get-date).ToString('ddMMyyyy')
$sLogFilename = "CloudMaintenance_$sCurrentDate.log"
#Citrix Delivery Controller hostname required by the Citrix PS SDK cmdlets
$sDDCHostname = "daas-ctxctrl01"
$sDomainNETBIOS = "frmdaas"
# $gVDAServerListCsvFilePath = "C:\Scripts\Cloud\VDAServers-DEMO-ONLY.csv"
$gVDAServerListCsvFilePath = "C:\Scripts\Cloud\VDAServers.csv"
#endregion StaticVariables

#region Parameters
#---------------------------------------------------------[Script Parameters]------------------------------------------------------
Param (
# [Mandatory]  
# [ValidateNotNullOrEmpty()]
  # [string] $VDAServerList = $gVDAServerListCsvFilePath
  [string] $VDAServerList
)
#endregion Parameters

#region Initializations
#---------------------------------------------------------[Initializations]--------------------------------------------------------
#Set Error Action to Stop
$ErrorActionPreference = 'Stop'
#Import Modules & Snap-ins
#WriteLogEntry module is available in Daas-Mgmt server under C:\Scripts\Cloud\PSLogging folder.
Import-Module -Name Logging -Verbose
Set-LoggingDefaultLevel -Level 'DEBUG' 
Add-LoggingTarget -Name File -Configuration @{Level = 'DEBUG'; Path = "$sLogPath\$sLogFilename"}
#Citrix Powershell SDK snap-ins initialization
Add-PSSnapin Citrix*
#endregion Initializations

#region Functions
#-----------------------------------------------------------[Functions]------------------------------------------------------------
# Use function template below to add all script functions in this region
function StartAutomaticWindowsServices {
<# Function documentation
        .SYNOPSIS
        Automatically starts specific Windows services on the host machine

        .DESCRIPTION
       Checks all Citrix, RDS and Icinga Windows Services set to automatically start and starts them if they are stopped after a server reboot.

        .PARAMETER ServerName
        ServerName of which to start the Windows services.

        .INPUTS
        N/A

        .OUTPUTS
        N/A

        .EXAMPLE
        PS> extension -name "File"
        File.txt

        .LINK
        Online version: https://github.com/stefanoscloud

    #>
  Param ([string]$ServerName)

  Begin {
    Write-Log -Level INFO -Message "Function StartAutomaticWindowsServices is being initialized"
  }

  Process {
    Try 
    {
      #Start of remote code invocation
        $ErrorActionPreference = 'Stop'
        $DaaSServices = get-service -ComputerName $ServerName | Where-Object {($_.DisplayName -match "Citrix*") -or ($_.DisplayName -match "Remote Desktop*") -or ($_.DisplayName -match "FsLogix*") -or ($_.DisplayName -match "Icinga*") -or ($_.DisplayName -match "metricbeat") -or ($_.DisplayName -match "winlogbeat") -or ($_.DisplayName -match "auditbeat") -and ($_.Name -ne "vmicrdv") }

        foreach ($DaaSService in $DaaSServices) 
        {
          $DaaSServiceStatus = $DaaSService.Status 
          $DaaSServiceName = $DaaSService.Name
          $DaaSServiceStartType = $DaaSService.StartType

          if($DaaSServiceStartType -ne 'Disabled')
          {   
            while ($DaaSServiceStatus -ne 'Running')
            {
            $DaasService | Set-Service -Status Running
            Write-Log -Level INFO -Message "Waiting for service $DaaSServiceName of server $ServerName to come up..."
            Write-Host -ForegroundColor "Yellow" "Waiting for service $DaaSServiceName of server $ServerName to come up..."
            Start-Sleep -seconds 20
            # Refresh() method not supported on remote machines
            # $DaaSService.Refresh()
            $DaaSService = get-service -ComputerName $ServerName -Name $DaaSServiceName
            $DaaSServiceStatus = $DaaSService.Status
            }
          }
          Write-Log -Level INFO -Message "Service $DaaSServiceName of server $ServerName is now up!"
          Write-Host -ForegroundColor "DarkGreen" "Service $DaaSServiceName of server $ServerName is now up!"
        }

      }

  Catch {
    Write-Log -Level ERROR -Message 'This is the exception stack of StartAutomaticWindowsServices function: {0}!' -Arguments $_.Exception 
    $PSCmdlet.ThrowTerminatingError($PSItem)
    Break
  }

    }

  End {
    If ($?) {
      Write-Log -Level INFO -Message "Function StartAutomaticWindowsServices execution completed successfully."
    }
  }

}
function Remove-LocalProfiles {
  <# Function Documentation
        .SYNOPSIS
        Delete Windows local profiles

        .DESCRIPTION
Checks local profiles for RDS roaming or FsLogix and deletes and local profile leftovers using the Delfprof2 tool
        .PARAMETER ServerName
        ServerName of which to start the Windows services.

        .INPUTS
        N/A

        .OUTPUTS
        N/A

        .EXAMPLE


        .LINK
        Online version: https://github.com/stefanoscloud

    #>
  Param ([String] $ServerName)

  Begin {
    Write-Log -Level INFO -Message "Function CleanupLocalProfiles is being initialized"
  }

  Process {
    Try {
      $ErrorActionPreference = 'Stop'
      Write-Log -Level INFO -Message "Function CleanupLocalProfiles execution started"
      Invoke-Command -ComputerName $ServerName -ScriptBlock {Start-Process -FilePath "C:\Scripts\DelProf2.exe /q" -Verbose}
          Write-Log -Level INFO -Message "Delprof is running'"
          Start-Sleep -seconds 20
          $LocalProfileFolders = Get-ChildItem "local_*" -Path C:\Users
          if ($LocalProfileFolders) {
            Write-Log -Level ERROR -Message 'Delprof was not able to delete some local profiles - Manual check required for {0}!' -Arguments $LocalProfileFolders 
            Throw "Delprof was not able to delete some local profiles - Manual check required for {0}!"
            } 
            elseif (!$LocalProfileFolders) { Write-Log -Level INFO -Message "Delprof was able to delete all local profiles."  }       
    }

    Catch {
      Write-Log -Level ERROR -Message 'This is the exception stack of CleanupLocalProfiles function: {0}!' -Arguments $_.Exception 
      $PSCmdlet.ThrowTerminatingError($PSItem)
      Break
    }
  }

  End {
    If ($?) {
      Write-Log -Level INFO -Message "Function Remove-LocalProfiles execution completed successfully."
    }
  }
}
function LogOffVDAUsers {
  <# Function Documentation
        .SYNOPSIS
        LogOffVDAUsers

        .DESCRIPTION
       Logoff all users from a specified Citrix VDA server.

        .PARAMETER ServerName
        ServerName whose users to log off.

        .INPUTS
        N/A

        .OUTPUTS
        N/A

        .EXAMPLE
        LogOffVDAUsers [Servername]

        .LINK
        Online version: https://github.com/stefanoscloud

    #>

  #Passing array of sessionID as parameter. The function will logoff all users whose sessionIDs are inside the array parameter.
  Param ([string[]] $SessionIDs, [string]$ServerName)

  Begin {
    Write-Log -Level INFO -Message "Function LogOffVDAUsers is being initialized"
  }

  Process {
    Try {
      Write-Log -Level INFO -Message "Function LogOffVDAUsers execution started"

    Invoke-Command -ComputerName $ServerName -ScriptBlock {
      $ErrorActionPreference = 'Stop'
  
      try {
          ## Find all session IDs matching the specified criteria (all users)
          # $sessions = quser | Where-Object {$_ -match 'username'}
          # $sessionIds = Get-ActiveSessions -ServerName $ServerName
          ## Loop through each session ID and pass each to the logoff command
          $using:sessionIds | ForEach-Object {
              # Write-Log -Level INFO -Message "Logging off session id [$($_)]..."
              logoff $_
          }
      } catch {
          if ($_.Exception.Message -match 'No user exists') {
            Write-Host -ForegroundColor "Yello" "There are no logged on users"
          } else {
              throw $_.Exception.Message
          }
      }
  }

    }

    Catch {
      Write-Log -Level ERROR -Message 'This is the exception stack of LogOffVDAUsers function: {0}!' -Arguments $_.Exception 
      $PSCmdlet.ThrowTerminatingError($PSItem)
      Break
    }
  }

  End {
    If ($?) {
      Write-Log -Level INFO -Message "Function LogOffVDAUsers execution completed successfully."
    }
  }
}
function Get-ActiveSessions{
  <# Function Documentation
        .SYNOPSIS
Gets all active RDP sessions of a Windows machine
       .DESCRIPTION
Get a list of all RDP users logged on a specific Windows Server

        .PARAMETER ServerName
        ServerName of which to get list of RDP users.

        .INPUTS
        N/A

        .OUTPUTS
        N/A

        .EXAMPLE


        .LINK
        Online version: https://github.com/stefanoscloud

    #>
  Param(
      [Parameter(
          Mandatory = $true,
          ValueFromPipeline = $true,
    ValueFromPipelineByPropertyName = $true
      )]
      [ValidateNotNullOrEmpty()]
      [string]$ServerName
      ,
      [switch]$Quiet
  )
  Begin{
      $return = @()
  }
  Process{
      If(!(Test-Connection $ServerName -Quiet -Count 1)){
          Write-Error -Message "Unable to contact $ServerName. Please verify its network connectivity and try again." -Category ObjectNotFound -TargetObject $ServerName
          Return
      }
      If([bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")){ #check if user is admin, otherwise no registry work can be done
          #the following registry key is necessary to avoid the error 5 access is denied error
          $LMtype = [Microsoft.Win32.RegistryHive]::LocalMachine
          $LMkey = "SYSTEM\CurrentControlSet\Control\Terminal Server"
          $LMRegKey = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey($LMtype,$ServerName)
          $regKey = $LMRegKey.OpenSubKey($LMkey,$true)
          If($regKey.GetValue("AllowRemoteRPC") -ne 1){
              $regKey.SetValue("AllowRemoteRPC",1)
              Start-Sleep -Seconds 1
          }
          $regKey.Dispose()
          $LMRegKey.Dispose()
      }
      $result = qwinsta /server:$ServerName
      If($result){
          ForEach($line in $result[1..$result.count]){ #avoiding the line 0, don't want the headers
              $tmp = $line.split(" ") | ?{$_.length -gt 0}
              If(($line[19] -ne " ")){ #username starts at char 19
                  If($line[48] -eq "A"){ #means the session is active ("A" for active)
                      $return += New-Object PSObject -Property @{
                          "ComputerName" = $ServerName
                          "SessionName" = $tmp[0]
                          "UserName" = $tmp[1]
                          "ID" = $tmp[2]
                          "State" = $tmp[3]
                          "Type" = $tmp[4]
                      }
                  }Else{
                      $return += New-Object PSObject -Property @{
                          "ComputerName" = $ServerName
                          "SessionName" = $null
                          "UserName" = $tmp[0]
                          "ID" = $tmp[1]
                          "State" = $tmp[2]
                          "Type" = $null
                      }
                  }
              }
          }
      }Else{
          Write-Error "Unknown error, cannot retrieve logged on users"
      }
  }
  End{
      If($return){
          If($Quiet){
              Return $true
          }
          Else{
              Return $return
          }
      }Else{
          If(!($Quiet)){
              Write-Host "No active sessions."
          }
          Return $false
      }
  }
}
function Show-Menu {
  <# Function Documentation
        .SYNOPSIS
        Shows a menu with options

        .DESCRIPTION
Runs in loop constantly allowing user to run commands from number of options until the Q button is pressed and then script terminates.
        .PARAMETER Title
        Title of the menu
        .INPUTS
        N/A

        .OUTPUTS
        N/A

        .EXAMPLE
        Show-Menu "Cloud Maintenance Options"

        .LINK
        Online version: https://github.com/stefanoscloud

    #>
    param (
        [string]$Title = 'Fermorite Cloud Maintenance Script'
    )
    $ErrorActionPreference = 'Stop'
    Clear-Host
    Write-Host -ForegroundColor "DarkGreen" "================ $Title ================"
    Write-Host -ForegroundColor "Red" "Please ensure that PSRemoting has been enabled on all target servers"
    Write-Host ""

    Write-Host "1: Press '1' for setting Citrix VDA maintenance mode on"
    Write-Host "2: Press '2' for logging off all users from Citrix VDA server(s)"
    Write-Host "3: Press '3' for applying application updates to Citrix VDA server(s)"
    Write-Host "4: Press '4' for rebooting Citrix VDA server(s)"
    Write-Host "5: Press '5' for cleaning up local profiles in Citrix VDA server(s)"
    Write-Host "6: Press '6' for checking Windows service status in Citrix VDA server(s)"
    Write-Host "7: Press '7' for setting Citrix VDA maintenance mode off"
    Write-Host "Q: Press 'Q' to quit this script."
}
function SetMaintenanceMode {
  <#Function documentation
        .SYNOPSIS
        Set the maintenance mode of a Citrix VDA server

        .DESCRIPTION
       Set the maintenance mode of a Citrix VDA server

        .PARAMETER MaintenanceMode
        Maintenace mode, true for enabled and false for disabled.
       
       .PARAMETER DDCHostname
        The hostname of the Citrix Delivery Controller.
       
       .PARAMETER ServerName
        ServerName of which to set maintenance mode.

        .INPUTS
        N/A

        .OUTPUTS
        N/A

        .EXAMPLE
        SetMaintenanceMode -MaintenanceMode $true -DDCHostname "HostnameoftheDDC" -ServerName $InputObject

        .LINK
        Online version: https://github.com/stefanoscloud

    #>
param(
[boolean]$MaintenanceMode,
[string]$DDCHostname,
[string]$ServerName
)

Begin {
  Write-Log -Level INFO -Message "Function SetMaintenanceMode is being initialized"
}

Process {
  Try {
    Write-Log -Level INFO -Message "Function SetMaintenanceMode execution started"
    $ErrorActionPreference = 'Stop'
  
          # Enable or disable Citrix Maintenance Mode for all servers in the csv file.
          $ServerSystemObject = Get-BrokerMachine -MachineName "$sDomainNETBIOS\$ServerName" -AdminAddress $DDCHostname
          Set-BrokerMachineMaintenanceMode -InputObject $ServerSystemObject -MaintenanceMode $MaintenanceMode -AdminAddress $DDCHostname
          Write-Log -Level INFO -Message "Maintenance mode for server $ServerName is set to $MaintenanceMode"
          }
      
      catch {
        Write-Log -Level ERROR -Message 'This is the exception stack of SetMaintenanceMode function: {0}!' -Arguments $_.Exception 
        $PSCmdlet.ThrowTerminatingError($PSItem)
        Break
      }
  

}

End {
  If ($?) {
    Write-Log -Level INFO -Message "Function SetMaintenanceMode execution completed successfully."
  }
}

}
function New-Menu {
<#Function documentation
        .SYNOPSIS
An alternative way to show a Powershell menu
        .DESCRIPTION
An alternative way to show a Powershell menu

        .PARAMETER Title
Title of the mernu       
       .PARAMETER Question
Question with options which the user must act upon       
        .INPUTS
        User input for Yes, No

        .OUTPUTS
        N/A

        .EXAMPLE
N/A
        .LINK
        Online version: https://github.com/stefanoscloud

    #>
  [CmdletBinding()]
  param(
      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$Title,

      [Parameter(Mandatory)]
      [ValidateNotNullOrEmpty()]
      [string]$Question
  )
  
  $Yes = [ChoiceDescription]::new('&Yes', 'Yes, confirm script execution')
  $No = [ChoiceDescription]::new('&No', 'No, stop script execution')

  $options = [ChoiceDescription[]]($Yes, $No)

  $result = $host.ui.PromptForChoice($Title, $Question, $options, 0)

  switch ($result) {
      0 { 'You confirmed script execution. Proceeding...' }
      1 { 'You confirmed that script execution should be stopped. Goodbye!' ; Exit }
  }


}

#endregion Functions




#region MainScript
#-----------------------------------------------------------[Main script]------------------------------------------------------------

#Start Logging
# Start-Log -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion

#Main script Execution goes here
Try {
  $ErrorActionPreference = 'Stop'
  Write-Log -Level INFO -Message "Script version $sScriptVersion"
  Write-Log -Level INFO -Message "Main script execution started. In progress..."
  
  #Run the script main menu in a loop
  do
 {
     Show-Menu
     $selection = Read-Host "Please select an option"
     switch ($selection)
     {
       #Enable maintenance mode for all servers in the csv file
      '1' {
        $ServerListCsvPath = Read-Host "Provide the absolute path to the csv file containing all servers to include. Use pre-formatted csv. Leave blank for default $gVDAServerListCsvFilePath"
        if(!$ServerListCsvPath)
        {
          $ServerListCsvPathExport = Import-Csv $gVDAServerListCsvFilePath
        }
        else {
          $ServerListCsvPathExport = Import-Csv $ServerListCsvPath
        }
        $ServerList = $ServerListCsvPathExport.Servers

        Write-Log -Level INFO -Message "You have chosen to set maintenance mode ON for the following servers:"
        Write-Log -Level INFO -Message "$ServerList"
        Write-Host -ForegroundColor "Yellow" "You have chosen to set maintenance mode ON for the following servers:"
        Write-Host -ForegroundColor "Yellow" "$ServerList"
        New-Menu -Title 'Please confirm servers in the selected CSV file are valid before running this option' -Question 'Proceed with script execution?'

        Write-Log -Level INFO -Message "Setting Citrix maintenance mode to on/enabled..."
        Write-Host -ForegroundColor "Yellow" "Setting Citrix maintenance mode to on/enabled..."
        foreach ($Server in $ServerList)
        {
         SetMaintenanceMode -ServerName $Server -DDCHostname $sDDCHostname -MaintenanceMode $true
         Write-Host -ForegroundColor "Yellow" "Maintenance mode enabled for server $Server"
        }
        Write-Host -ForegroundColor "Yellow" "Maintenance mode enablement completed"
        Write-Log -Level INFO -Message "Maintenance mode enablement completed"
      }
      #Logoff users
      '2' {
        $ServerListCsvPath = Read-Host "Provide the absolute path to the csv file containing all servers to include. Use pre-formatted csv. Leave blank for default $gVDAServerListCsvFilePath"
        if(!$ServerListCsvPath)
        {
          $ServerListCsvPathExport = Import-Csv $gVDAServerListCsvFilePath
        }
        else {
          $ServerListCsvPathExport = Import-Csv $ServerListCsvPath
        }
        $ServerList = $ServerListCsvPathExport.Servers

        Write-Log -Level INFO -Message "You have chosen to logoff all RDP users from the following servers:"
        Write-Log -Level INFO -Message "$ServerList"
        Write-Host -ForegroundColor "Yellow" "You have chosen to logoff all RDP users from the following servers:"
        Write-Host -ForegroundColor "Yellow" "$ServerList"
        New-Menu -Title 'Please confirm servers in the selected CSV file are valid before running this option' -Question 'Proceed with script execution?'

        Write-Log -Level INFO -Message "Getting active sessions per server"
        Write-Host -ForegroundColor "Yellow" "Getting active sessions per server"
        foreach ($Server in $ServerList)
        {
          $ActiveSessionIDs = Get-ActiveSessions -ServerName $Server | Select-Object ID
          Write-Log -Level INFO -Message "Received active sessions of server $Server, now logging off users..."
          Write-Host -ForegroundColor "Yellow" "Received active sessions of server $Server, now logging off users..."
          LogOffVDAUsers -SessionIDs $ActiveSessionIDs.ID -ServerName $Server
          Write-Log -Level INFO -Message "All RDP user sessions in server $Server have been logged off"
          Write-Host -ForegroundColor "DarkGreen" "All RDP user sessions in server $Server have been logged off"
        }
        Write-Log -Level INFO -Message "All RDP user sessions have been logged off"
        Write-Host -ForegroundColor "DarkGreen" "All RDP user sessions have been logged off"
        Write-Host -ForegroundColor "Yellow" "Waiting for all SMB sessions to close for logged off users..."
        Write-Log -Level INFO -Message "Waiting for all SMB sessions to close for logged off users..."
        Start-Sleep -seconds 60        
        Write-Host -ForegroundColor "Red" "Important! Please manually check that all SMB sessions are closed from the Computer Management MMC console before proceeding with next step"
      }
      #Apply application updates to the VDA servers of the csv file, using PatchMyPC tool /s switch
      '3' {
        $ServerListCsvPath = Read-Host "Provide the absolute path to the csv file containing all servers to include. Use pre-formatted csv. Leave blank for default $gVDAServerListCsvFilePath"
        if(!$ServerListCsvPath)
        {
          $ServerListCsvPathExport = Import-Csv $gVDAServerListCsvFilePath
        }
        else {
          $ServerListCsvPathExport = Import-Csv $ServerListCsvPath
        }
        $ServerList = $ServerListCsvPathExport.Servers
        Write-Log -Level INFO -Message "You have chosen to install application updates on the following servers:"
        Write-Log -Level INFO -Message "$ServerList"
        Write-Host -ForegroundColor "Yellow" "This option assumes that PatchMyPC.exe resides in C:\Scripts folder of the target server. You have chosen to install application updates on the following servers:"
        Write-Host -ForegroundColor "Yellow" "$ServerList"
        New-Menu -Title 'Please confirm servers in the selected CSV file are valid before running this option. Also ensure that all app windows are closed on target servers before running PatchMyPC' -Question 'Proceed with script execution?'

        Write-Log -Level INFO -Message "Starting PatchMyPC application updates..."
        Write-Host -ForegroundColor "Yellow" "Starting PatchMyPC application updates..."
        foreach ($Server in $ServerList)
        {
          #Interactive session seems to be required
          $s1 = New-PSSession -computername $Server
          Invoke-Command -Session $s1 -ScriptBlock {Start-Process -FilePath "C:\Scripts\PatchMyPC.exe" -ArgumentList "/s"}
          # Exit-PSSession
          Write-Log -Level INFO -Message "Initiating PatchMyPC for server $Server..."
          Write-Host -ForegroundColor "Yellow" "Initiating PatchMyPC for server $Server..."
        }

        foreach ($Server in $ServerList)
        {
          $s2 = New-PSSession -computername $Server
          $PatchMyPCProcessStatus = Invoke-Command -Session $s2 -ScriptBlock {Get-Process | Where-Object {$_.ProcessName -eq "PatchMyPC"}}
          while($PatchMyPCProcessStatus)
          {
            Start-Sleep 30
            Write-Log -Level INFO -Message "Waiting till PatchMyPC updates are completed for server $Server..."
            Write-Host -ForegroundColor "Yellow" "Waiting till PatchMyPC updates are completed for server $Server..."
            $PatchMyPCProcessStatus = Invoke-Command -Session $s2 -ScriptBlock {Get-Process | Where-Object {$_.ProcessName -eq "PatchMyPC"}}
          }
          Write-Log -Level INFO -Message "PatchMyPC updates for server $Server completed successfully."
          Write-Host -ForegroundColor "DarkGreen" "PatchMyPC updates for server $Server completed successfully."
        }
        
        Write-Log -Level INFO -Message "PatchMyPC updates completed."
        Write-Host -ForegroundColor "DarkGreen" "PatchMyPC updates completed"
        #Close PSSession objects opened on each server for PatchMyPC
        Get-Pssession | Remove-PsSession

      }
      #Reboot VDA servers in the csv file
      '4' {
        $ServerListCsvPath = Read-Host "Provide the absolute path to the csv file containing all servers to include. Use pre-formatted csv. Leave blank for default $gVDAServerListCsvFilePath"
        if(!$ServerListCsvPath)
        {
          $ServerListCsvPathExport = Import-Csv $gVDAServerListCsvFilePath
        }
        else {
          $ServerListCsvPathExport = Import-Csv $ServerListCsvPath
        }
        $ServerList = $ServerListCsvPathExport.Servers

        Write-Log -Level INFO -Message "You have chosen to reboot the following servers:"
        Write-Log -Level INFO -Message "$ServerList"
        Write-Host -ForegroundColor "Yellow" "You have chosen to reboot the following servers:"
        Write-Host -ForegroundColor "Yellow" "$ServerList"
        New-Menu -Title 'Please confirm servers in the selected CSV file are valid before running this option' -Question 'Proceed with script execution?'

        Write-Log -Level INFO -Message "Rebooting servers..."
        Write-Host -ForegroundColor "Yellow" "Rebooting servers..."
        foreach ($Server in $ServerList)
        {
          Restart-Computer -ComputerName $Server -Force
          Write-Log -Level INFO -Message "Rebooting server $Server..."
          Write-Host -ForegroundColor "Yellow" "Rebooting server $Server..."
        }
        Write-Log -Level INFO -Message "Waiting for all rebooted servers to come up..."
        Write-Host -ForegroundColor "Yellow" "Waiting for all rebooted servers to come up..."
   
        foreach ($Server in $ServerList)
        {
        
          Start-Sleep 20
          do 
        {
          $ping = Test-Connection $Server -quiet
          if ($ping -eq $false) {Start-Sleep 30}
        } 
          until($ping -eq $true)
          Write-Log -Level INFO -Message "Server $Server has come up after reboot"
          Write-Host -ForegroundColor "DarkGreen" "Server $Server has come up after reboot"

        }
        Start-Sleep 30
        Write-Log -Level INFO -Message "All rebooted servers have come up"
        Write-Host -ForegroundColor "DarkGreen" "All rebooted servers have come up"


      }
      #Clean up local profiles of the VDA servers in the csv file, using DelProf2 tool  /q switch
      '5' {
        $ServerListCsvPath = Read-Host "Provide the absolute path to the csv file containing all servers to include. Use pre-formatted csv. Leave blank for default $gVDAServerListCsvFilePath"
        if(!$ServerListCsvPath)
        {
          $ServerListCsvPathExport = Import-Csv $gVDAServerListCsvFilePath
        }
        else {
          $ServerListCsvPathExport = Import-Csv $ServerListCsvPath
        }
        $ServerList = $ServerListCsvPathExport.Servers

        Write-Log -Level INFO -Message "You have chosen to cleanup local user profiles on the following servers:"
        Write-Log -Level INFO -Message "$ServerList"
        Write-Host -ForegroundColor "Yellow" "This option assumes that DelProf2.exe resides in C:\Scripts folder of the target server. You have chosen to cleanup local user profiles on the following servers:"
        Write-Host -ForegroundColor "Yellow" "$ServerList"
        New-Menu -Title 'Please confirm servers in the selected CSV file are valid before running this option.' -Question 'Proceed with script execution?'

        Write-Log -Level INFO -Message "Starting local user profile clean up..."
        Write-Host -ForegroundColor "Yellow" "Starting local user profile clean up..."
        foreach ($Server in $ServerList)
        {
          #Interactive session seems to be required
          $s1 = New-PSSession -computername $Server
          Invoke-Command -Session $s1 -ScriptBlock {Start-Process -FilePath "C:\Scripts\DelProf2.exe" -ArgumentList "/q"}
          # Exit-PSSession
          Write-Log -Level INFO -Message "Initiating local user profile clean up for server $Server..."
          Write-Host -ForegroundColor "Yellow" "Initiating local user profile clean up for server $Server..."
        }

        foreach ($Server in $ServerList)
        {
          $s2 = New-PSSession -computername $Server
          $ProfileCleanupProcessStatus = Invoke-Command -Session $s2 -ScriptBlock {Get-Process | Where-Object {$_.ProcessName -eq "DelProf2"}}
          while($ProfileCleanupProcessStatus)
          {
            Start-Sleep 30
            Write-Log -Level INFO -Message "Waiting till local user profile clean up is completed for server $Server..."
            Write-Host -ForegroundColor "Yellow" "Waiting till local user profile clean up is completed for server $Server..."
            $ProfileCleanupProcessStatus = Invoke-Command -Session $s2 -ScriptBlock {Get-Process | Where-Object {$_.ProcessName -eq "DelProf2"}}
          }
          Write-Log -Level INFO -Message "Local user profile clean up for server $Server completed successfully."
          Write-Host -ForegroundColor "DarkGreen" "Local user profile clean up for server $Server completed successfully."
        }
        
        Write-Log -Level INFO -Message "Local user profile clean up completed."
        Write-Host -ForegroundColor "DarkGreen" "Local user profile clean up completed."
        #Close PSSession objects opened on each server for PatchMyPC
        Get-Pssession | Remove-PsSession



      }
      #Check status of automatic Windows Services of the VDA servers in the csv file and start any stopped services
      '6' {
        $ServerListCsvPath = Read-Host "Provide the absolute path to the csv file containing all servers to include. Use pre-formatted csv. Leave blank for default $gVDAServerListCsvFilePath"
        if(!$ServerListCsvPath)
        {
          $ServerListCsvPathExport = Import-Csv $gVDAServerListCsvFilePath
        }
        else {
          $ServerListCsvPathExport = Import-Csv $ServerListCsvPath
        }
        $ServerList = $ServerListCsvPathExport.Servers

        Write-Log -Level INFO -Message "You have chosen to start automatic Windows services for the following servers:"
        Write-Log -Level INFO -Message "$ServerList"
        Write-Host -ForegroundColor "Yellow" "You have chosen to start automatic Windows services for the following servers:"
        Write-Host -ForegroundColor "Yellow" "$ServerList"
        New-Menu -Title 'Please confirm servers in the selected CSV file are valid before running this option' -Question 'Proceed with script execution?'

        Write-Log -Level INFO -Message "Checking status of Windows services..."
        Write-Host -ForegroundColor "Yellow" "Checking status of Windows services..."
        foreach ($Server in $ServerList)
        {
         StartAutomaticWindowsServices -ServerName $Server
         Write-Host -ForegroundColor "DarkGreen" "Windows services status running ok for server $Server"
         Write-Log -Level INFO -Message "Windows services status running ok for server $Server"
        }
        Write-Host -ForegroundColor "DarkGreen" "Windows services status running ok in all servers"
        Write-Log -Level INFO -Message "Windows services status running ok in all servers"


      }
      #Disable maintenance mode for all servers in the csv file
      '7' {
        $ServerListCsvPath = Read-Host "Provide the absolute path to the csv file containing all servers to include. Use pre-formatted csv. Leave blank for default $gVDAServerListCsvFilePath"
        if(!$ServerListCsvPath)
        {
          $ServerListCsvPathExport = Import-Csv $gVDAServerListCsvFilePath
        }
        else {
          $ServerListCsvPathExport = Import-Csv $ServerListCsvPath
        }
        $ServerList = $ServerListCsvPathExport.Servers

        Write-Log -Level INFO -Message "You have chosen to set maintenance mode OFF for the following servers:"
        Write-Log -Level INFO -Message "$ServerList"
        Write-Host -ForegroundColor "Yellow" "You have chosen to set maintenance mode OFF for the following servers:"
        Write-Host -ForegroundColor "Yellow" "$ServerList"
        New-Menu -Title 'Please confirm servers from selected CSV file are valid before running this option' -Question 'Proceed with script execution?'

        Write-Log -Level INFO -Message "Setting Citrix maintenance mode to off/disabled..."
        Write-Host -ForegroundColor "Yellow" "Setting Citrix maintenance mode to off/disabled..."
        foreach ($Server in $ServerList)
        {
         SetMaintenanceMode -ServerName $Server -DDCHostname $sDDCHostname -MaintenanceMode $false
         Write-Host -ForegroundColor "Yellow" "Maintenance mode disabled for server $Server"
        }
        Write-Host -ForegroundColor "Yellow" "Maintenance mode disablement completed"
        Write-Log -Level INFO -Message "Maintenance mode disablement completed"
      }
     }
     pause
 }
 until ($selection -eq 'q')


    }
    Catch {
      Write-Log -Level ERROR -Message 'This is the exception stack of the main script: {0}!' -Arguments $_.Exception       
      $PSCmdlet.ThrowTerminatingError($PSItem)
      Break
    }

Finally {
    Write-Log -Level INFO -Message "Main script execution completed successfully."
}

#Stop Logging
# Stop-Log -LogPath $sLogFile

#endregion MainScript
