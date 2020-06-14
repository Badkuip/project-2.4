#To create users with this script, a csv file with users must be given as a parameter.
#The csv file with the users must contain the following colloms: GivenName, Surname, Initials, SamAccountName, UserPrincipalName, ADGroupMember, DisplayName, OU, EmployeeNumber
#When a user has multiple ADGroupMembers the groups can be seperated with a ;
#When a user has the same SamAccountName or UserPrincipalName as another user the user will  be skipped.
#An example of what the csv file can look like:
#
#GivenName,Surname,Initials,SamAccountName,UserPrincipalName,ADGroupMember,DisplayName,OU,EmployeeNumber
#Karel,Knaap,K.,K.Knaap,K.Knaap@ZP11G.hanze20,Studenten;Domain Admins,Karel K. Knaap,Studenten,1

$UserFilePath=$args[0]
if (Test-Path $UserFilePath -PathType leaf) {
    #Password will be created
    $Password=(Read-Host -AsSecureString "Password for all accounts")
    $PasswordCheck=(Read-Host -AsSecureString "Repeat the Password")
    #https://stackoverflow.com/questions/38901752/verify-passwords-match-in-windows-powershell
    $passwordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
    $passwordCheckText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($PasswordCheck))

    While ($PasswordText -ne $PasswordCheckText -or $passwordText -eq "") {
        Write-Host "Passwords does not match or they are empty, try again." -ForegroundColor Red
        $Password=(Read-Host -AsSecureString "Password for all accounts")
        $PasswordCheck=(Read-Host -AsSecureString "Repeat the Password")
        $passwordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Password))
        $passwordCheckText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($PasswordCheck))
    }
    $passwordText=$null
    $passwordCheckText=$null
    Write-Host "`n"
    $NumberOfUsers=1
    Import-Csv -path $UserFilePath | Foreach-Object{
       try {
            #User checks will be created.
            $UserCheck=Get-ADUser -LDAPFilter "(SamAccountName=$($_.SamAccountName))"
            $UserCheck2=Get-ADUser -LDAPFilter "(UserPrincipalName=$($_.UserPrincipalName))"
            #User check will be executed.
            if ($UserCheck -eq $null -and $UserCheck2 -eq $null) {
                #All uservariables will be set to a variable.
                $Name=$_.DisplayName
                $GivenName=$_.GivenName
                $Surname=$_.Surname
                $Initials=$_.Initials
                $SamAccountName=$_.SamAccountName
                $UserPrincipalName=$_.UserPrincipalName
                $ADGroupMember=$_.ADGroupMember
                $DisplayName=$_.DisplayName
                $OUName=$_.OU
                $EmployeeNumber=$_.EmployeeNumber
                $DrivePath = "\\ITV2G-W16-3\HomeFolders$\$SamAccountName" 
                $DriveLetter  = "H:"
                $ProfilePath = "\\ITV2G-W16-3\ProfileFolder\$SamAccountName"

                #Drive path will be created.
                $DrivePathCheck=Test-Path $DrivePath
                if ($DrivePathCheck -eq $False) {
                
                    #User and Home directory will be created.
                    New-Item -ItemType Directory -Path $DrivePath
                    icacls $DrivePath /inheritance:d
                    Write-Host "`n"
                    New-ADUser -Name $Name -GivenName $GivenName -Surname $Surname -Initials $Initials -SamAccountName $SamAccountName -UserPrincipalName $UserPrincipalName -DisplayName $DisplayName -HomeDrive $DriveLetter -HomeDirectory $DrivePath -ProfilePath $ProfilePath -EmployeeNumber $EmployeeNumber -Enabled $true -AccountPassword $Password -PasswordNeverExpires $true <#-ChangePasswordAtLogon $true #>
                    #User details are requested.
                    $UserObject=Get-ADUser -LDAPFilter "(SamAccountName=$SamAccountName)"
                
                    Write-Output "User $SamAccountName has been created. Below you will find some details abbout the new creaded user $SamAccountName."
                    Write-Output $UserObject

                    #User premissions will be set to the Home directory.
                    $Acl = Get-Acl -Path $DrivePath
                    $Acl.SetAccessRule($(New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList $SamAccountName, 'Modify', 'ContainerInherit, ObjectInherit', 'None', 'Allow'))
                    $Acl.SetAccessRule($(New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList 'Domain Admins', 'FullControl', 'Allow'))
                    $Acl | Set-Acl $DrivePath

                    #User will be added to usergroups.
                    $($ADGroupMember.split(':', [System.StringSplitOptions]::RemoveEmptyEntries)).foreach{
                        $GroupObject=Get-ADGroup -LDAPFilter "(name=$_)"
                        Add-ADGroupMember -Identity $GroupObject.DistinguishedName -Members $UserObject.DistinguishedName
                        Write-Output "$SamAccountName has been added to the usergroup $_."
                    }
                
                    #A OU will be requested and the user will be placed insite.
                    $OUObject=Get-ADOrganizationalUnit -LDAPFilter "(name=$OUName)"
                    Move-ADObject -TargetPath $OUObject.DistinguishedName -Identity $UserObject.DistinguishedName
    
                    Write-Output "$SamAccountName has been moved to the OU called $OUName."
                    Write-Host "User $SamAccountName has been created." -ForegroundColor Green
                }
                else {
                    Write-Host "The Home folder of user $SamAccountName already exists." -ForegroundColor Red
                }
            }
            else {
                Write-Host "User $NumberOfUsers already exists." -ForegroundColor Yellow
            }
            $NumberOfUsers++
            Write-Output "`n"
        }
        catch {
            Write-Host "There went Something wrong with user number $NumberOfUsers." -ForegroundColor Red
            $NumberOfUsers++
        }
    }
}
else {
        Write-Host "File $UserFilePath does not exist." -ForegroundColor Red
}