######################################################################################
##						Tanktracker1 Restart Website								##
##						Created by Richard Flowers									##
##							Version 2.0												##
##							Date:  1/2/20											##
######################################################################################
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
		$Password = "2mS0b5u6ypKGtvrFnL"
		#$File = $pbd + "\EmailPassword.txt"
		$fromaddress = "tanktrackeritt@gmail.com"
		#$toaddress = "rflowers@allcovered.com"
		$CCaddress = "rflowers300@gmail.com"
		$Subject = "ITT Website and Java Check from Tanktracker1 $Date"
		$body = "Website is $webup and " + "Java is $Javaup" +"  `n Check website at http://tanktracker.intermodaltank.com:8080/itt/pages/ $object"
		#$attachment = "$ReportFilesZip"
		#Write-host $ReportFiles
		$smtpserver = "smtp.gmail.com"
		####################################
		#Comment
		$message = new-object System.Net.Mail.MailMessage
		$message.From = $fromaddress
		#When Testing Disable $message.to
		#$message.To.Add($toaddress)
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
$webup, $Javaup = WebsiteJava
$fileToCheck = "$pwd\count.txt"
if (!(Test-Path $fileToCheck -PathType leaf)) {
	New-Item -path $fileToCheck -value "0"
}
If ($webup -eq "UP" -and $Javaup -eq "UP") {
		$AddCounter = 0
		Set-Content "$fileToCheck" $AddCounter
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
				If ($AddCounter -eq 2) {
					$Username = "ttadmin"
					$pwdin = Get-Content "$pwd\TTauthenticationfile.cfg"
					$Password = $pwdin | ConvertTo-SecureString
					$Credentials = New-Object System.Management.Automation.PSCredential $Username, $Password
					$s = New-PSSession -ComputerName 10.37.20.200 -Credential $Credentials -ErrorAction SilentlyContinue

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
						Write-host "Mysqld is Not Running"
						EmailOut($webup, $Javaup)
						Write-host $webup
						Write-host $Javaup
					}

				}
				If ($AddCounter -eq 3) {
				
					$AddCounter = 0
					Set-Content "$fileToCheck" $AddCounter
					EmailOut($webup, $Javaup)
				}
			}
		
		}
		#Write-host $webup
		#Write-host $Javaup
 
 
 
 