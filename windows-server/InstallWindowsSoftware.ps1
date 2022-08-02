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
  This script automates Windows software installation into multiple machines provided in a csv list
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
$sLogFilename = "WindowsMachineSoftwareInstallation_$sCurrentDate.log"
#Various static variables go here
#endregion StaticVariables

#region Parameters
#---------------------------------------------------------[Script Parameters]------------------------------------------------------
Param (

     [Parameter()]
     [string] $WindowsMachineList,
 
     [Parameter()]
     [string] $GetApp1
)
#endregion Parameters

#region Initializations
#---------------------------------------------------------[Initializations]--------------------------------------------------------
#Set Error Action to Stop
$ErrorActionPreference = 'Stop'
#Import Modules & Snap-ins
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
  #Param ([string]$MachineName)
  Param ([string]$GetApp1)

  Begin {
    Write-Log -Level INFO -Message "Function CheckIfExists is being initialized"
  }

  Process {
    Try 
    {

     if (Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -like "*$GetApp1*"})
     {
      return $true;
     }
     return $false;


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
  Param ([string]$GetApp1)

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
  Param ([string]$GetApp1)

  Begin {
    Write-Log -Level INFO -Message "Function UnInstallSoftware is being initialized"
  }

  Process {
    Try 
    {

     $App1 = Get-WmiObject -Class Win32_Product | Where-Object {$_.Name -like "*$GetApp1*"} | Select Name
     $App1.Uninstall()

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
  
 #Install
 #If (!CheckIfExists($GetApp1))
 #{
 #InstallSoftware($GetApp1)
 #}
 
 #UnInstall
 If (CheckIfExists($GetApp1))
 {
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
Stop-Log -LogPath $sLogFile

#endregion MainScript
