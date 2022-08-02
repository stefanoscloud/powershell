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
  This script automates Windows server weekly reboot schedule
.DESCRIPTION
  The script carries out the following tasks on a weekly basis. It can be triggered via scheduled task or manually by an administrator user. 
  
  The script must be run on a management server in elevated Powershell window with an administrator user who is member of a proper Operations AD security group.
  The script utilizes Windows PowerShell remoting and thus all remote Windows computers must be configured for remote management: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_remote_requirements?view=powershell-7.1
  After the script run is complete, the administrator must check the script execution log under C:\Scripts\Cloud folder to ensure that no errors occured.

.PARAMETER Windows ServerserverList
  Provide name of csv file containing the list of Windows servers to maintain and reboot.
  This .csv file can be chosen by the user via the Powershell menu function during runtime
.INPUTS Csv File
  The script takes a Windows Servers.csv file as input.
.OUTPUTS Log File
  The script execution log file is stored in C:\Scripts\Cloud\CloudMaintenance.log
.NOTES
  Version:        1.0
  Author:         Stefanos Cloud
  Creation Date:  
  Purpose/Change: Initial script development
  External PS repositories:   The script utilizes the following reposities and modules: 
    * Powershell Logging functions from https://github.com/EsOsO/Logging/wiki/Usage.   
    * Get-ActiveSessions Function: https://github.com/ThePoShWolf/Utilities/blob/master/ActiveSessions/Get-ActiveSessions.ps1
    * Powershell menu using .NET objects: https://adamtheautomator.com/powershell-menu/ 
.EXAMPLE
  RunWeeklyMaintenance.ps1 DemoServers.csv
  

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
#Various static variables go here
#endregion StaticVariables

#region Parameters
#---------------------------------------------------------[Script Parameters]------------------------------------------------------
Param (
# [Mandatory]  
# [ValidateNotNullOrEmpty()]
  # [string] $Windows ServerserverList = $gWindows ServerserverListCsvFilePath
  [string] $Windows ServerserverList
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

function FunctionA {
<# Function documentation
        .SYNOPSIS
        Automatically starts specific Windows services on the host machine
        .DESCRIPTION
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


}

#endregion Functions




#region MainScript
#-----------------------------------------------------------[Main script]------------------------------------------------------------

#Start Logging
# Start-Log -LogPath $sLogPath -LogName $sLogName -ScriptVersion $sScriptVersion

#Main script Execution goes here
Try {
  
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
