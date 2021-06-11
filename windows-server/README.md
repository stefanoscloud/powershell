#Windows Server Powershell script collection
##Script list
The following scripts are available in this folder:
Run-WeeklyMaintenance.ps1
### Run-WeeklyMaintenance.ps1
The Run-WeeklyMaintenance.ps1 script executes the following actions: 
1) Put all production RDS session host servers in maintenance mode
2) Logoff all users from session hosts
3) Deploy application updates
4) Reboot session host servers
5) Clean up local user profiles on session hosts
6) CHeck the status of all automatically started Windows services on session hosts
7) Remove maintenance mode
