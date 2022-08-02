#region Namespaces
#----------------------------------------------------------[Namespaces]----------------------------------------------------------
using namespace System.Management.Automation.Host
#endregion Namespaces

#region ScriptRequirements
#----------------------------------------------------------[Script requirements]----------------------------------------------------------
#requires -version 4
#requires -Modules logging
#endregion ScriptRequirements

#region Documentation
#----------------------------------------------------------[Script documentation]----------------------------------------------------------
<#
.SYNOPSIS
  This script automates Windows software uninstallation fom multiple machines provided in a csv list
.DESCRIPTION
  The script installs software components statically specified inside the script into multiple Windows servers or clients provided in a csv file.
.PARAMETER WindowsMachineList
  Provide name of csv file containing the list of Windows servers or clients on which to install software.
  This .csv file can be chosen by the user via the Powershell menu function during runtime
.INPUTS Csv File
  The script takes a WindowsMachineList.csv file as input.
.OUTPUTS Log File
  The script execution log file is stored in C:\Scripts\Cloud\WindowsMachineSoftwareInstallation.log
.NOTES
  Version:        1.0
  Author:         Stefanos Cloud
  Creation Date:  
  Purpose/Change: Initial script development
  External PS repositories:   The script utilizes the following reposities and modules: 
    * Powershell Logging functions from https://github.com/EsOsO/Logging/wiki/Usage.   
.EXAMPLE
  InstallWindowsSoftware.ps1 WindowsMachines.csv
  
#>
#endregion Documentation

#region StaticVariables
#----------------------------------------------------------[Static Variables]----------------------------------------------------------
#Script Version
$sScriptVersion = '1.0'
#Log File Info
$sLogPath = 'C:\Scripts\Cloud\Logs'
$sCurrentDate = (get-date).ToString('ddMMyyyy')
$sLogFilename = "WindowsMachineSoftwareUninstallation_$sCurrentDate.log"
#Various static variables go here
$sDefaultMachineList = 'C:\Scripts\Cloud\DefaultMachineList.csv'
#endregion StaticVariables

#region Parameters
#---------------------------------------------------------[Script Parameters]------------------------------------------------------
<#Param (

     [Parameter()]
     [string] $WindowsMachineList,
 
     [Parameter()]
     [string] $GetApp1
)
#>
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
#All modules' initialization occurs here
#endregion Initializations

#region Functions
#-----------------------------------------------------------[Functions]------------------------------------------------------------
# Use function template below to add all script functions in this region

function CheckIfExists {
<# Function documentation
        .SYNOPSIS
Checks if specific software already exists, i.e. if it is already installed on the Windows machine in question
.DESCRIPTION
        .PARAMETER MachineName
        MachineName on which to check presence of the software.
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
Param ([string]$GetApp1)

  Begin {
    Write-Log -Level INFO -Message "Function CheckIfExists is being initialized"
  }

  Process {
    Try 
    {

    Invoke-Command -ComputerName $ServerName -ScriptBlock 
    {
       if (Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -eq "$GetApp1"})
     {
      return $true;
     }
     return $false;

    }
    


        }

          Catch {
    Write-Log -Level ERROR -Message 'This is the exception stack of CheckIfExists function: {0}!' -Arguments $_.Exception 
    $PSCmdlet.ThrowTerminatingError($PSItem)
    Break
  }

          End {
    If ($?) {
      Write-Log -Level INFO -Message "Function CheckIfExists execution completed successfully."
    }
  }

      }



}



function InstallSoftware {
<# Function documentation
        .SYNOPSIS
       Installs software components into a Windows machine
        .DESCRIPTION
        .PARAMETER MachineName
        MachineName of which to install software components.
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
  #Param ([string]$MachineName)
  #Param ([string]$GetApp1)

  Begin {
    Write-Log -Level INFO -Message "Function InstallSoftware is being initialized"
  }

  Process {
    Try 
    {

        }

         Catch {
    Write-Log -Level ERROR -Message 'This is the exception stack of InstallSoftware function: {0}!' -Arguments $_.Exception 
    $PSCmdlet.ThrowTerminatingError($PSItem)
    Break
  }



      }



  End {
    If ($?) {
      Write-Log -Level INFO -Message "Function InstallSoftware execution completed successfully."
    }
  }

 

}




function UnInstallSoftware {
<# Function documentation
        .SYNOPSIS
       Uninstalls software components from a Windows machine.
        .DESCRIPTION
        .PARAMETER MachineName
        MachineName of which to uninstall software components.
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
  #Param ([string]$MachineName)
  #Param ([string]$GetApp1)

  Begin {
    Write-Log -Level INFO -Message "Function UnInstallSoftware is being initialized"
  }

  Process {



    Try 
    {
#Core commands below for one machine
# $App1 = Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -like "$GetApp1"}
# $App1.Uninstall()


#Remote Powershell invocation as per the machine csv file
        $ServerListCsvPath = Read-Host "Provide the absolute path to the csv file containing all servers to include for software uninstallation. Use pre-formatted csv. Leave blank for default path."
        if(!$ServerListCsvPath)
        {
          $ServerListCsvPathExport = Import-Csv $sDefaultMachineList
        }
        else {
          $ServerListCsvPathExport = Import-Csv $ServerListCsvPath
        }
        $ServerList = $ServerListCsvPathExport.Servers

        Write-Log -Level INFO -Message "You have chosen to uninstall the $GetApp1 software from the following machines:"
        Write-Log -Level INFO -Message "$ServerList"
        Write-Host -ForegroundColor "Yellow" "You have chosen to uninstall the $GetApp1 software from the following machines:"
        Write-Host -ForegroundColor "Yellow" "$ServerList"
        Read-Host "Press Enter to continue..."
        Write-Log -Level INFO -Message "Uninstalling software from machines..."
        Write-Host -ForegroundColor "Yellow" "Uninstalling software from machines..."
        foreach ($Server in $ServerList)
        {
          Invoke-Command -ComputerName $ServerName -ScriptBlock {Start-Process $App1 = Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -like "$GetApp1"}; $App1.Uninstall()}
          Write-Log -Level INFO -Message "Uninstalling software from machine $Server..."
          Write-Host -ForegroundColor "Yellow" "Uninstalling software from machine $Server..."
        }
        Write-Log -Level INFO -Message "Waiting for all machines' uninstallation to complete..."
        Write-Host -ForegroundColor "Yellow" "Waiting for all machines' uninstallation to complete..."
   
        foreach ($Server in $ServerList)
        {
        
          Start-Sleep 20
         while (Invoke-Command -ComputerName $ServerName -ScriptBlock {CheckIfExists($GetApp1)} -eq $true )
        
{

{Start-Sleep 20}
          
}

          Write-Log -Level INFO -Message "Machine $Server software uninstallation completed"
          Write-Host -ForegroundColor "DarkGreen" "Machine $Server software uninstallation completed"

        }
        Start-Sleep 20
        Write-Log -Level INFO -Message "All machines' uninstallations have been completed"
        Write-Host -ForegroundColor "DarkGreen" "All machines' uninstallations have been completed"



        }


  Catch {
    Write-Log -Level ERROR -Message 'This is the exception stack of UnInstallSoftware function: {0}!' -Arguments $_.Exception 
    $PSCmdlet.ThrowTerminatingError($PSItem)
    Break
  }



  

      }

      End {
    If ($?) {
      Write-Log -Level INFO -Message "Function UnInstallSoftware execution completed successfully."
    }
  }


}




#endregion Functions




#region MainScript
#-----------------------------------------------------------[Main script]------------------------------------------------------------

#Start Logging
# Start-Log -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion

#Main script Execution goes here
Try  {

  $GetApp1 = $args[0]
  
 #Install
 #If (!CheckIfExists($GetApp1))
 #{
 #InstallSoftware($GetApp1)
 #}
 
 Write-Host "Checking presence of $GetApp1 software and then uninstalling the software"
 #UnInstall
 If (CheckIfExists($GetApp1))
 {
   Write-Host "Uninstalling $GetApp1..."
 UnInstallSoftware($GetApp1)
 }
  
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
#Stop-Log -LogPath $sLogFile

#endregion MainScript
