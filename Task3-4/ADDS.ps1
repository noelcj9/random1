# Windows powershell script for AD DS deployment

[CmdletBinding()]

param 
( 
    [Parameter(ValuefromPipeline=$true,Mandatory=$true)] [string]$Domain_DNSName,
    [Parameter(ValuefromPipeline=$true,Mandatory=$true)] [string]$Domain_NETBIOSName,
    [Parameter(ValuefromPipeline=$true,Mandatory=$true)] [String]$SafeModeAdministratorPassword
)

$SMAP = ConvertTo-SecureString -AsPlainText $SafeModeAdministratorPassword -Force

#install AD DS
Install-windowsFeature -name AD-Domain-Services -includeManagementTools
mkdir C:/sendemail
@'
$Global:ErrorActionPreference = 'SilentlyContinue'
Start-Sleep 120
# Create another user for testing 
$splat = @{
    Name = 'Noel John'
    AccountPassword = ("Hello@123" | ConvertTo-SecureString -AsPlainText -Force)
    Enabled = $true
    ChangePasswordAtLogon = $false
    PasswordNeverExpires = $false
    SamAccountName='noelcj'
    OtherAttributes = @{
        'ProxyAddresses'='SMTP:noelcj9@gmail.com' 
    }
}
New-ADUser @splat



######################## Task 3 automation of email
#Import AD Module
Import-Module ActiveDirectory
 
#Create warning dates for future password expiration
$SevenDayWarnDate = (get-date).adddays(42).ToLongDateString()

#Email Variables
$MailSender = "noelcj9@gmail.com"
$MailSenderPSWD = 'ksxniuwgvqidjrxj'
$Subject = 'FYI - Your account password will expire soon'
$EmailStub1 = 'I am a bot and performed this action automatically. I am here to inform you that the password for'
$EmailStub2 = 'will expire in'
$EmailStub3 = 'days on'
$EmailStub4 = '. Please contact the help desk if you need assistance changing your password. DO NOT REPLY TO THIS EMAIL.'
$SMTPServer = 'smtp.gmail.com'
 
#Find accounts that are enabled and have expiring passwords
$users = Get-ADUser -filter {Enabled -eq $True -and PasswordNeverExpires -eq $False -and PasswordLastSet -gt 0 } `
 -Properties "Name", "ProxyAddresses", "msDS-UserPasswordExpiryTimeComputed" | Select-Object -Property "Name", "ProxyAddresses", `
 @{Name = "PasswordExpiry"; Expression = {[datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed").tolongdatestring() }}
 
#check password expiration date and send email on match
foreach ($user in $users) {
     if ($user.PasswordExpiry -eq $SevenDayWarnDate) {
         $days = 42
         $EmailBody = $EmailStub1, $user.name, $EmailStub2, $days, $EmailStub3, $SevenDayWarnDate, $EmailStub4 -join ' '
         $Global:ErrorActionPreference = 'SilentlyContinue'
         $MailArgs = @{
            From       = $MailSender
            To         = ($user.ProxyAddresses.Trim("SMTP:"))
            Subject    = $Subject
            Body       = $EmailBody
            SmtpServer = $SMTPServer
            Port       = 587
            UseSsl     = $true
            Credential = New-Object pscredential $MailSender,$($MailSenderPSWD |ConvertTo-SecureString -AsPlainText -Force)
        }
        $MailArgs
        Send-MailMessage @MailArgs
        $MailArgs = $null
     }
 }

 $Global:Error | Out-File "C:/sendemail/log.txt" -Force
'@ | Out-File "C:\\sendemail\\sendemail.ps1"

schtasks.exe /create /f /tn "sendemail" /ru SYSTEM /sc ONSTART /tr "powershell.exe -file 'C:\\sendemail\\sendemail.ps1'"

#promote the server to a domain controller
Import-Module ADDSDeployment

Install-ADDSForest -CreateDnsDelegation:$false `
-DatabasePath "C:\Windows\NTDS" `
-DomainMode "WinThreshold" `
-DomainName $Domain_DNSName `
-DomainNetbiosName $Domain_NETBIOSName `
-ForestMode "WinThreshold" `
-InstallDns:$true `
-LogPath "C:\Windows\NTDS" `
-NoRebootOnCompletion:$false `
-SysvolPath "C:\Windows\SYSVOL" `
-Force:$true `
-SkipPreChecks `
-SafeModeAdministratorPassword $SMAP

