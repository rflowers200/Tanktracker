######################################################################################
##						Tanktracker1 Restart Website								##
##						Created by Richard Flowers									##
##							Version 2.0												##
##							Date:  1/3/20											##
######################################################################################
<#
Remote Powershell Setup
https://4sysops.com/archives/enable-powershell-remoting-on-a-standalone-workgroup-computer/

On Remote Computer
Enable-PSRemoting -SkipNetworkProfileCheck -Force
Enable-PSRemoting -Force


On Local Computer
	
Set-Item WSMan:\localhost\Client\TrustedHosts -Value "IP-Address-or-Hostname-0f-Remote-Computer" -Force

Read Trusted Host List
Get-Item WSMan:\localhost\Client\TrustedHosts

Remotely Manage Trusted Host
See script line starting at 160
Enter-PSSession -ComputerName IP-Address-or Hostname -Credential $Credentials
#>



$Date = Get-Date -Format "MM-dd-yyyy-HHmm"
#Bypass Error for Local Testing (Comment out in Production)
#$ErrorActionPreference = 'SilentlyContinue'
Function WebsiteJava {
	#Check Website is up
	# First we create the request.
	$HTTP_Request = [System.Net.WebRequest]::Create('http://localhost:8080/itt/pages/') 

	# We then get a response from the site.
	$HTTP_Response = $HTTP_Request.GetResponse()

	# We then get the HTTP code as an integer.
	$HTTP_Status = [int]$HTTP_Response.StatusCode

	If ($HTTP_Status -eq 200) {
		$webup = "UP"
		#Write-host "Website UP"
	}
	Else {
		$webup = "DOWN"
		#Write-host "Website Down"
	}

	# Finally, we clean up the http request by closing it.
	$HTTP_Response.Close()
	#Check if Mysqld is running as Process

	if ((get-process "java" -ea SilentlyContinue) -eq $Null) { 
		$Javaup = "DOWN" 
		#       Write-host "DOWN"
	}

	else { 
		$Javaup = "UP"
		#write-host "UP"
    
 }
 Return $webup, $Javaup
}
 
 
 
#Send by Email If Down

Function EmailOut {
	Write-host $webup
	write-host $Javaup
	
	If ($webup -eq "DOWN" -or $Javaup -eq "DOWN") {
		Write-host $webup
		write-host $Javaup


	
		###############################################################################
		###########Define Variables########
		$object = gwmi win32_operatingsystem -ComputerName $env:computername | select csname, @{LABEL = 'LastBootUpTime'; EXPRESSION = { $_.ConverttoDateTime($_.lastbootuptime) } }
		$Username = "tanktrackeritt@gmail.com"
		#Secure Password
		$Password = Get-Content "$pwd\EmailPassword.txt" | ConvertTo-SecureString
		$fromaddress = "tanktrackeritt@gmail.com"
		$toaddress = "rflowers@allcovered.com"
		$CCaddress = "rflowers300@gmail.com"
		$Subject = "ITT Website and Java Check from Tanktracker1 $Date"
		$body = "Website is $webup and " + "Java is $Javaup" + "  `n Check website at http://tanktracker.intermodaltank.com:8080/itt/pages/ $object"
		#$attachment = "$ReportFilesZip"
		#Write-host $ReportFiles
		$smtpserver = "smtp.gmail.com"
		####################################
		#Comment
		$message = new-object System.Net.Mail.MailMessage
		$message.From = $fromaddress
		#When Testing Disable $message.to
		$message.To.Add($toaddress)
		$message.CC.Add($CCaddress)
		#$message.Bcc.Add($bccaddress)
		$message.IsBodyHtml = $True
		$message.Subject = $Subject
		#$attach = new-object Net.Mail.Attachment($archive)
		#$message.Attachments.Add($attach)
		$message.body = $body
		$smtp = new-object Net.Mail.SmtpClient($smtpserver, 587)
		$smtp.EnableSSL = $true
		$smtp.Credentials = New-Object System.Net.NetworkCredential($UserName, $Password); 
		$smtp.Send($message)
		#################################################################################
	}
	Else {
		#Everything is OK 
	}
}
#Call Function to Check Website and Java Status
$webup, $Javaup = WebsiteJava
#Counter file
$fileToCheck = "$pwd\count.txt"
#Create Counter file if not detected in directory
if (!(Test-Path $fileToCheck -PathType leaf)) {
	New-Item -path $fileToCheck -value "0"
}
#Reset Counter file if Website and Java is up 
If ($webup -eq "UP" -and $Javaup -eq "UP") {
	$counter = Get-Content "$fileToCheck"
	$AddCounter = [System.Decimal]::Parse($counter)
	#Reset Counter
	If ($AddCounter -gt 0) {
		$AddCounter = 0
		Set-Content "$fileToCheck" $AddCounter
	}
}
If ($webup -eq "DOWN" -or $Javaup -eq "DOWN") {
	#Check CounterFile   
	if (Test-Path $fileToCheck -PathType leaf) {
		$counter = Get-Content "$fileToCheck"
		$AddCounter = [System.Decimal]::Parse($counter)
		$AddCounter++
		Set-Content "$fileToCheck" $AddCounter
		Write-host $AddCounter
		Write-host $pwd
		#Tanktracker Remediation
		If ($AddCounter -eq 2) {
			$Username = "ttadmin"
			#$pwdin = Get-Content "$pwd\TTauthenticationfile.cfg"
			$Password =Get-Content "$pwd\TTauthenticationfile.cfg" | ConvertTo-SecureString
			$Credentials = New-Object System.Management.Automation.PSCredential $Username, $Password
			#Connect to Tanktracker-sql
			$s = New-PSSession -ComputerName 10.37.20.200 -Credential $Credentials -ErrorAction SilentlyContinue
			#check if mysqld is running
			$state = Invoke-Command -Session $s -ScriptBlock { (Get-Process | Where -Property ProcessName -eq mysqld) }  -ErrorAction SilentlyContinue
			If ($state -like "*mysqld*") {
				Write-host "Mysqld is Running"
				# Kill Java on local server
				Stop-Process -Name "Java"
				#Wait
				Start-sleep -s 60
				#Shutdown Tanktracker
				start-process cmd -argument "/c C:\BUREAUEYE\apache-tomcat-6.0.36_64\bin\shutdown.bat" -ErrorAction SilentlyContinue -wait
				Start-sleep -s 60
				#Start Tanktracker
				start-process cmd -argument "/c C:\BUREAUEYE\apache-tomcat-6.0.36_64\bin\startup.bat" -ErrorAction SilentlyContinue
			}
			Else {
				#Mysqld is not running email OutageHouston
				Write-host "Mysqld is Not Running"
				EmailOut($webup, $Javaup)
				Write-host $webup
				Write-host $Javaup
			}

		}
		#Reset counter after 3 checks and email OutageHouston
		If ($AddCounter -eq 3) {
			$AddCounter = 0
			Set-Content "$fileToCheck" $AddCounter
			EmailOut($webup, $Javaup)
		}
	}
		
}
#Write-host $webup
#Write-host $Javaup
 
 
 
 