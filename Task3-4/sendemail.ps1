# Create another user for testing 
$splat = @{
    Name = 'Noel John'
    AccountPassword = ("Hello@123" | ConvertTo-SecureString -AsPlainText -Force)
    Enabled = $true
    ChangePasswordAtLogon = $false
    PasswordNeverExpires = $false
    SamAccountName='noelcj'
    OtherAttributes = @{
        'ProxyAddresses'='SMTP:noeljohn9@gmail.com' 
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
