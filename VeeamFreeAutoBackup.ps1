<#
 # Simple ESXi backup automation script
 #	for Veeam Backup Free Edition
 #
 # Author: 	inDev.be
 # Version: 1.0
 # Licence: GPL
 #
 # improvement idea: 
 #	- handle hosts/vm types & adapt commands
 #  - support -BackupRepository for Start-VBRZip cmdlet
 #  - support -RunAsync for Start-VBRZip cmdlet
 #
 #####################################>

### Environement and configuration ###
## Functions
function Send-Mail ($subject, $body, $isHtml = $TRUE)
{
	if($mailConfigValidated) {
		try
		{
			# Creating message
			$message = New-Object System.Net.Mail.MailMessage( $config.Mail.From, $config.Mail.To )
			foreach($cc in $config.Mail.Cc)
			{
				$message.cc.add($cc)
			}
			$message.IsBodyHtml = $isHtml
			$message.Subject = $subject
			$message.Body = $body
			# SMTP connection & send
			$SMTPClient = New-Object System.Net.Mail.SmtpClient( $config.Mail.SmtpHost , $config.Mail.SmtpPort )
			$SMTPClient.EnableSsl = $config.Mail.EnableSsl
			$SMTPClient.Credentials = New-Object System.Net.NetworkCredential( $config.Mail.SmtpUser , $config.Mail.SmtpPass );
			$SMTPClient.Send( $message )
		}
		catch 
		{
			$errorMessage = $_.Exception.Message
			$failedItem = $_.Exception.ItemName
			$message = "Email notification Failed! We failed to send a notification email.`r`n`r`n$failedItem.`r`n The error message was $errorMessage"
			$title = "Email error"
			Log -Title $title -Message $message -Level "warning"
		}
	}
}
function Log ($title, $message, $level = "error", $sendMail = $FALSE)
{
	try {
		switch ($level)
		{
			"success" { Write-Output $message }
			"info" { Write-Output $message }
			"warning" { Write-Warning $message }
			default
			{
				$level = "error"
				Write-Error $message
			}
		}
		$logPath = [IO.Path]::Combine($currentDirectory, "logs.txt")
		"[$level] $title" | Add-Content -Path $logPath
		$message | Add-Content -Path $logPath
		if($sendmail -and $config.Mail.EnableNotifications)
		{
			if($config.Mail.isHtml)
			{
				$message = $message.Replace("`r`n","<br>")
			}
			switch ($level)
			{
				"info"
				{
					$subject = if($mailSuccessSubjectTemplate) { $mailSuccessSubjectTemplate -f $title } else { $title }
					$body = if($mailSuccessBodyTemplate) { $mailSuccessBodyTemplate -f $message } else { $message }
					Send-Mail -Subject $subject -Body $body -IsHtml $config.Mail.isHtml
				}
				"success"
				{
					$subject = if($mailSuccessSubjectTemplate) { $mailSuccessSubjectTemplate -f $title } else { $title }
					$body = if($mailSuccessBodyTemplate) { $mailSuccessBodyTemplate -f $message } else { $message }
					Send-Mail -Subject $subject -Body $body -IsHtml $config.Mail.isHtml
				}
				default
				{
					$subject = if($mailFailureSubjectTemplate) { $mailFailureSubjectTemplate -f $title } else { $title }
					$body = if($mailFailureBodyTemplate) { $mailFailureBodyTemplate -f $message } else { $message }
					Send-Mail -Subject $subject -Body $body -IsHtml $config.Mail.isHtml
				}
			}
		}
	}
	catch
	{
		$errorMessage = $_.Exception.Message
		$failedItem = $_.Exception.ItemName
		$message = "Error.`r`n`r`n$failedItem.`r`n The error message was $errorMessage"
		Write-Error $message
	}
}

## Configuration ##
$currentDirectory = [IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Path)
$configFile = [IO.Path]::Combine($currentDirectory, 'VeeamFreeAutoBackupConfig.json')
$config = $NULL
# Parsing JSON config
try
{
	$config = Get-Content "$configFile" -Raw -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue | ConvertFrom-Json -ErrorAction:SilentlyContinue -WarningAction:SilentlyContinue
}
catch
{
    $errorMessage = $_.Exception.Message
    $failedItem = $_.Exception.ItemName
    Write-Error "Config File Read Failed! We failed to read file.`r`n`r`n $failedItem.`r`nThe error message was $errorMessage"
    Break
}

## Mails ##
$mailConfigValidated = $TRUE
# Const
$mailTemplatePath = [IO.Path]::Combine($currentDirectory, "templates\")
$mailTemplatePrefix = "Mail_"
$mailTemplateSubjectPrefix = "Subject_"
$mailTemplateBodyPrefix = "Body_"
$mailTemplateSubjectSufix = ".txt"
$mailTemplateBodySufix = if ($config.Mail.IsHtml) {".html"} Else {".txt"}
# Templates
$mailSuccessSubjectFile = [IO.Path]::Combine($mailTemplatePath, $mailTemplatePrefix + $mailTemplateSubjectPrefix + $config.Mail.Templates.Success + $mailTemplateSubjectSufix)
$mailSuccessBodyFile = 	  [IO.Path]::Combine($mailTemplatePath, $mailTemplatePrefix + $mailTemplateBodyPrefix + $config.Mail.Templates.Success + $mailTemplateBodySufix)
$mailFailureSubjectFile = [IO.Path]::Combine($mailTemplatePath, $mailTemplatePrefix + $mailTemplateSubjectPrefix + $config.Mail.Templates.Failure + $mailTemplateSubjectSufix)
$mailFailureBodyFile =    [IO.Path]::Combine($mailTemplatePath, $mailTemplatePrefix + $mailTemplateBodyPrefix + $config.Mail.Templates.Failure + $mailTemplateBodySufix)
try
{
	if([IO.File]::Exists($mailSuccessSubjectFile)) { $mailSuccessSubjectTemplate = Get-Content $mailSuccessSubjectFile }
	else {
		$mailConfigValidated = $FALSE
		$title = "Email template missing"
		$message = "mailSuccessSubjectFile file is missing at $mailSuccessSubjectFile"
		Log -Title $title -Message $message -Level "warning"
	}
	if([IO.File]::Exists($mailSuccessBodyFile)) { $mailSuccessBodyTemplate = Get-Content $mailSuccessBodyFile }
	else {
		$mailConfigValidated = $FALSE
		$title = "Email template missing"
		$message = "mailSuccessBodyFile file is missing at $mailSuccessBodyFile"
		Log -Title $title -Message $message -Level "warning"
	}
	if([IO.File]::Exists($mailFailureSubjectFile)) { $mailFailureSubjectTemplate = Get-Content $mailFailureSubjectFile }
	else {
		$mailConfigValidated = $FALSE
		$title = "Email template missing"
		$message = "mailFailureSubjectFile file is missing at $mailFailureSubjectFile"
		Log -Title $title -Message $message -Level "warning"
	}
	if([IO.File]::Exists($mailFailureBodyFile)) { $mailFailureBodyTemplate = Get-Content $mailFailureBodyFile }
	else {
		$mailConfigValidated = $FALSE
		$title = "Email template missing"
		$message = "mailFailureBodyFile file is missing at $mailFailureBodyFile"
		Log -Title $title -Message $message -Level "warning"
	}
}
catch 
{	
	$mailConfigValidated = $FALSE # ?the variable doesn't keep the value outside the catch scope?
	$errorMessage = $_.Exception.Message
	$failedItem = $_.Exception.ItemName
	$title = "Email templates error"
	$message = "An error happened while reading mail notifications templates! Mail notifications disabled.`r`n`r`n$failedItem.`r`n The error message was`r`n $errorMessage"
	Log -Title $title -Message $message -Level "error"
}

$now = [System.DateTime]::Now
$title = "VeeamFreeAutoBackup session started"
$startMsg = "[=== Beginning new VeeamFreeAutoBackup session at $now ===]"
Log -Title $title -Message $startMsg -Level "info"

### Veeam connection ###
# Add the Veeam Backup and Replication Snap-in
Add-PSSnapin VeeamPSSnapin
# Disconnect from Veeam Backup and Replication server in case it is already connected
Disconnect-VBRServer
# Connect to the Veeam Backup and Replication server (localhost)
Connect-VBRServer
# Loop through configured hosts
foreach($targetHost in $config.Hosts) 
{
	$srvName = $targetHost.Server
	try 
	{
		# Get the host server
		$vbrServer = Get-VBRServer -Name $srvName		
		if(!$vbrServer)
		{
			$title = "Host not found"
			$message = "No server named $srvName can be found, skipping this host."
			Log -Title $title -Message $message -Level "warning" -SendMail $TRUE
			continue
		}
		if($vbrServer.IsUnavailable)
		{
			$title = "Host unavailable"
			$message = "The server named $srvName is unavailable, skipping this host."
			Log -Title $title -Message $message -Level "warning" -SendMail $TRUE
			continue
		}
		
		# Loop through configured host's backup sets
		foreach($backupSet in $targetHost.BackupSets)
		{
			try
			{
				# Define variables to use (backup defined or global)
				$backupDestination = if ($backupSet.Destination) {$backupSet.Destination} Else {$config.Default.Destination}
				$backupCompressionLevel = if ($backupSet.CompressionLevel) {$backupSet.CompressionLevel} Else {$config.Default.CompressionLevel}
				$backupEnableQuiescence = if ($backupSet.EnableQuiescence) {$backupSet.EnableQuiescence} Else {$config.Default.EnableQuiescence}
				$backupEnableEncryption = if ($backupSet.EnableEncryption) {$backupSet.EnableEncryption} Else {$config.Default.EnableEncryption}
				$backupEncryptionKey = if ($backupSet.EncryptionKey) {$backupSet.EncryptionKey} Else {$config.Default.EncryptionKey}
				$backupRetention = if ($backupSet.Retention) {$backupSet.Retention} Else {$config.Default.Retention}
				$backupNetCredential = if ($backupSet.NetCredential) {$backupSet.NetCredential} Else {$config.Default.NetCredential}
				# Continue with backup set specific infos
				$backupAlias = $backupSet.Alias
				$backupVms = $backupSet.Vms
			
				# Destination path definition (& creation if doesn't exit)
				$backupDestinationPath = [IO.Path]::Combine($backupDestination, $backupAlias)
				if(![IO.Directory]::Exists($backupDestinationPath))
				{
					New-Item -ItemType Directory -Force -Path $backupDestinationPath
				}
				
				# Get the VMs to backup
				$vbrVms = Find-VBRViEntity -Server $vbrServer -Name $backupVms
				if(!$vbrVms -or $vbrVms.count -eq 0)
				{
					$title = "VMs not found"
					$message = "Vms " + [string]$backupVms + " not found for backup set $backupAlias. Skipping backup set."
					Log -Title $title -Message $message -Level "warning" -SendMail $TRUE
					continue
				}
				
				# Get network credentials if needed
				$vbrCredentials = $NULL
				if($backupNetCredential)
				{
					$vbrCredentials = Get-VBRCredentials -Name $backupNetCredential
				}
				
				# Create VeeamZip session
				if($backupEnableEncryption)
				{
					$vbrEncryptionKey = Get-VBREncryptionKey -Description $backupAlias
					if(!$vbrEncryptionKey)
					{
						$vbrEncryptionKey = Add-VBREncryptionKey -Description $backupAlias -Password (cat $backupEncryptionKey | ConvertTo-SecureString)
					}
					if(!$vbrEncryptionKey)
					{
						$title = "Encryption key not found"
						$message = "Encryption key $backupEncryptionKey not found for backup set $backupAlias. Skipping backup set."
						Log -Title $title -Message $message -Level "warning" -SendMail $TRUE
						continue
					}
					if($vbrCredentials)
					{
						$vbrZipSession = Start-VBRZip -Entity $vbrVms -Folder $backupDestinationPath -Compression $backupCompressionLevel -DisableQuiesce:(!$backupEnableQuiescence) -AutoDelete $backupRetention -EncryptionKey $vbrEncryptionKey -NetworkCredentials $vbrCredentials
					}
					else {
						$vbrZipSession = Start-VBRZip -Entity $vbrVms -Folder $backupDestinationPath -Compression $backupCompressionLevel -DisableQuiesce:(!$backupEnableQuiescence) -AutoDelete $backupRetention -EncryptionKey $vbrEncryptionKey
					}
				}
				else
				{
					if($vbrCredentials)
					{
						$vbrZipSession = Start-VBRZip -Entity $vbrVms -Folder $backupDestinationPath -Compression $backupCompressionLevel -DisableQuiesce:(!$backupEnableQuiescence) -AutoDelete $backupRetention -NetworkCredentials $vbrCredentials
					}
					else
					{
						$vbrZipSession = Start-VBRZip -Entity $vbrVms -Folder $backupDestinationPath -Compression $backupCompressionLevel -DisableQuiesce:(!$backupEnableQuiescence) -AutoDelete $backupRetention
					}
				}
				if(!$vbrZipSession)
				{
					$title = "VeeamZIP session is empty"
					$message = "VeeamZIP session is empty, backup set $backupAlias failed."
					Log -Title $title -Message $message -Level "warning" -SendMail $TRUE
					continue
				}
				# Get tasks status
				$vbrZipTaskSessionsLogs = $vbrZipSession.GetTaskSessions().logger.getlog().updatedrecords
				$failedVbrZipTaskSessions = $vbrZipTaskSessionsLogs | where { $_.status -eq "EWarning" -or $_.Status -eq "EFailed" }
				$message = ""
				if ($failedVbrZipTaskSessions -ne $Null)
				{
					$title = "Backup set $backupAlias failed"
					$message = "Backup $backupAlias failed`r`n" + ($vbrZipSession | Select-Object @{n="Name";e={($_.name).Substring(0, $_.name.LastIndexOf("("))}} ,@{n="Start Time";e={$_.CreationTime}},@{n="End Time";e={$_.EndTime}},Result,@{n="Details";e={$FailedSessions.Title}})
					Log -Title $title -Message $message -Level "error" -SendMail $TRUE
				}
				else
				{
					$title = "Backup set $backupAlias successful"
					$message = "Backup $backupAlias succeeded.`r`n" + ($vbrZipSession | Select-Object @{n="Name";e={($_.name).Substring(0, $_.name.LastIndexOf("("))}} ,@{n="Start Time";e={$_.CreationTime}},@{n="End Time";e={$_.EndTime}},Result,@{n="Details";e={($TaskSessions | sort creationtime -Descending | select -first 1).Title}})
					Log -Title $title -Message $message -Level "success" -SendMail $TRUE
				}
			}
			catch
			{
				$errorMessage = $_.Exception.Message
				$failedItem = $_.Exception.ItemName
				$alias = $backupSet.Alias
				$title = "Backup set $alias failed"
				$message = "Backup set $alias failed.`r`n`r`n$failedItem`r`nThe error message was`r`n$errorMessage"
				Log -Title $title -Message $message -Level "error" -SendMail $TRUE
				continue
			}
		}
	}
	catch
	{
    	$errorMessage = $_.Exception.Message
		$failedItem = $_.Exception.ItemName
		$title = "Backup of host $srvName"
		$message = "Backup of host $srvName failed`r`n`r`n$failedItem`r`nThe error message was`r`n$errorMessage"
		Log -Title $title -Message $message -Level "error" -SendMail $TRUE
		continue
	}
}
# Disconnect from Veeam Backup and Replication server
Disconnect-VBRServer

$now = [System.DateTime]::Now
$title = "VeeamFreeAutoBackup session finished"
$endMsg = "[=== VeeamFreeAutoBackup session finished at $now ===]`r`n`r`n"
Log -Title $title -Message $endMsg -Level "info"
