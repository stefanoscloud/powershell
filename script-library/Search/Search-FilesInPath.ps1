<#   Static variables  #>
#SMB path where search will take place
$searchpath= "C:\Scripts\Powershell"
#Files to be searched are records inside this $importfilepath. This csv file only has a "files" column.
$importfilepath= "C:\Scripts\Powershell\files_in.csv"
#Search results
$exportfilepath= "C:\Scripts\Powershell\files_out.txt"


<#   Execution  #>
$importfile = import-csv -Path $importfilepath  
#Go through the list of files in $importfilepath and search if they are present in the $searchpath. If yes, output the file name and creation date. If not, state that the file does not exist. 

ForEach ($file in $importfile)  { $filestring = $file.files.ToString(); $fileresult = Get-ChildItem -Path $searchpath | Where-object {$_.Name -eq $filestring} ; if ($fileresult -ne $null) { $creationtime = $fileresult.CreationTime.ToString()} ; if ($fileresult -ne $null) {Add-Content -Path $exportfilepath -Value "$filestring,$creationtime"} else { Add-Content -Path $exportfilepath -Value "File $filestring not found" } }
