#Create variables
$Domain = 'ZP11G.hanze20'
$User = 'B.Kuiper'
$Operation = 'AccountMaintenance'
$CmdLets = 'Get-ADUser', 'Set-ADUser'
$DomainControlers = 'ITV2G-W16-21'

#Create files that will define the user restrictions
New-Item -Path "C:\Program Files\WindowsPowerShell\Modules\$Operation" -ItemType Directory
New-ModuleManifest -Path "C:\Program Files\WindowsPowerShell\Modules\$Operation\$Operation.psd1" -RootModule $Operation.psm1
New-Item -Path "C:\Program Files\WindowsPowerShell\Modules\$Operation\$Operation.psm1" -ItemType File
New-Item -Path "C:\Program Files\WindowsPowerShell\Modules\$Operation\RoleCapabilities" -ItemType Directory
New-PSRoleCapabilityFile -Path "C:\Program Files\WindowsPowerShell\Modules\$Operation\RoleCapabilities\$Operation.psrc" -VisibleCmdlets $CmdLets

#Create Directorys
New-Item -Path 'C:\JEA-files' -ItemType Directory
New-Item -Path "C:\JEA-files\Config" -ItemType Directory
New-PSSessionConfigurationFile -Path  'C:\JEA-files\Config\ConfigFile.pssc' -TranscriptDirectory 'C:\JEA-files\Config\Transcripts' -RunAsVirtualAccount -SessionType 'RestrictedRemoteServer' -RoleDefinitions @{"$Domain\$User" = @{ RoleCapabilities = "$Operation" }}

Invoke-Command -ScriptBlock {Register-PSSessionConfiguration -Path "C:\JEA-files\Config\ConfigFile.pssc" -Name $Operation -Force}

Foreach ($Domain in $DomainControlers)
{
    $Session = New-PSSession $Domain
    Copy-Item -Path 'C:\JEA-files' -Destination 'C:\JEA-files' -Recurse -ToSession $Session
    Copy-Item -Path "C:\Program Files\WindowsPowerShell\Modules\$Operation" -Destination "C:\Program Files\WindowsPowerShell\Modules\$Operation" -Recurse -ToSession $Session
    Invoke-Command -ScriptBlock {Register-PSSessionConfiguration -Path "C:\JEA-files\Config\ConfigFile.pssc" -Name $Using:Operation -Force} -Session $Session
}

#Write-Host "The User: $User can start the Created PSSession with the command: Enter-PSSession -ComputerName <A domaincontrollername> -ConfigurationName $Operation"