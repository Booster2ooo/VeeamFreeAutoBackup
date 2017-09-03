# VeeamFreeAutoBackup
PowerShell script for Veeam Backup Free Edition automation with email notifications.

## Note
This script is still very basic and only works with VMWare hosts.

If you need to work with Microsoft Hyper-V, look for cmdlet starting with VBRVi and replace it with VBRHv.

For instance, replace:
```powershell
$vbrVms = Find-VBRViEntity -Server $vbrServer -Name $backupVms becomes
````
with: 
```powershell
$vbrVms = Find-VBRHvEntity -Server $vbrServer -Name $backupVms becomes
````
Have a look at https://helpcenter.veeam.com/docs/backup/powershell/understanding_veeam_cmdlets.html if you want to know more.

## How to ?
Start by configuring VeeamFreeAutoBackupConfig.json

This is the default structure of the configuration file (DO NO INCLUDE COMMENTS IN YOUR JSON FILE !):
```javascript
{
    "Default": { // Default options, will be used if not provided in the backup set (check https://helpcenter.veeam.com/docs/backup/powershell/start-vbrzip.html for more info)
        "CompressionLevel": "5"
      , "EnableQuiescence": false
      , "EnableEncryption": false
      , "EncryptionKey":    ""
      , "Retention":        "In1Month"
      , "Destination":      "D:\\Backups"
      , "NetCredential":    null // credential name
    }
  , "Hosts": [ // (array)list of servers configured in Veeam
        {
            "Server": "vCenter"     // server name 
          , "BackupSets": [        // (array)list of backup sets to be made on this server
                {          
                    "Alias": "MyFirstBackupSet" // name of the backup set
                  , "Vms": [  // (array)list of the VM names to backup in this set
                        "MyVM 01"
                      , "MyVM 02"
                    ]
                }
              , {
                    "Alias": "MySecondSet"
                  , "Vms": [ 
                        "MyVM 03"
                      , "MyVM 04"
                      , "MyVM 05"
                    ]
                }
            ]
        }
    ]
  , "Mail": { // Mail notification configuration, self explanatory
        "EnableNotifications": true
      , "SmtpHost":            ""
      , "SmtpPost":            587
      , "SmtpUser":            "user"
      , "SmtpPass":            "pass"
      , "EnableSsl":           true
      , "IsHtml":              true
      , "From":                "veeam-backup@indev.be"
      , "To":                  "booster2ooo@indev.be"
      , "Cc":                  [ "admin@indev.be" ]
      , "Templates": { // Will be used to find email templates
            "Success": "Backup_Success"
          , "Failure": "Backup_Failure"
        }
    }
}
```

Once it's set, you can either run VeeamFreeAutoBackup.ps1 or create a scheduled task to execute the script automatically.

A log.txt file is created in the same directory than the script.
