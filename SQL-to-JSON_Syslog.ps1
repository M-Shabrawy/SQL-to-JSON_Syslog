#PowerShell script to read data from SQL DB, Convert to JSON and send it to Syslog server

Param(
    [Parameter()]
    [ValidateSet('SSPI','UP','DSN')]
    [string]$Mode,        #SSPI,UP,DSN    
	[string]$DBServer,    #DB Server Name including Instance name
    [string]$DBName,      #DB Name
    [string]$Query,       #SQL Query That will be converted to JSON
    [string]$LogServer,   #Log Server name or IP
    [int]$LogServerPort,  #Log Server Port
    [string]$DSN,         #System Data Source Name
    [switch]$CreateCred   #Will ask for credentials and store it in a secure file on the same location as the script
	)

#Log file
$MaxLogFileSizeBytes = 10 * 1000 * 1000
$logfile = "$PSScriptRoot\SQLJSON.log"
if (Test-Path $logFile) {

    # Check if the log file is larger than the Max allowable log file size
    if ((Get-Item $logFile).Length -ge $MaxLogFileSizeBytes) {

        # If so, clear the log file to start fresh
        Clear-Content $logFile
        Write-Debug ("Log File " + $logFile + " exceeded " + $MaxLogFileSizeBytes.ToString() + " bytes; truncating.")
        Write-Log -Message ("Log File " + $logFile + " exceeded " + $MaxLogFileSizeBytes.ToString() + " bytes; truncating.") -Severity Information
    }
}

#State file
$StateFile = "$PSScriptRoot\SQLJSON.pos"

#Check for Credentials file if mmode is Username and Password "UP"
Function Get-Credentials{
    Param(
            [Parameter()]
            [ValidateNotNullOrEmpty()]
            [string]$CredentialsFile
            )
    
    # Check if the credentials file exists
    if (Test-Path $CredentialsFile) {
        Write-Debug ("Credentials file found: " + $CredentialsFile)
        Write-Log -Message ("Credentials file found: " + $CredentialsFile) -Severity Information
        try {
            $Credentials = Import-Clixml -Path $CredentialsFile
            $Username = $Credentials.Username
            $Password = $Credentials.GetNetworkCredential().Password
        }
        catch {
            Write-Error ("The credentials within the credentials file are corrupt. Please recreate the file: " + $CredentialsFile)
            Write-Log -Message ("The credentials within the credentials file are corrupt. Please recreate the file: " + $CredentialsFile) -Severity Error
            exit
        }
    }
    else {
        Write-Error ("Could not find credentials file: " + $CredentialsFile + ". Please Use -CreateCed.\n Exiting...")
        Write-Log -Message ("Could not find credentials file: " + $CredentialsFile + ". Please Use -CreateCed. Exiting") -Severity Error
        Exit
    }
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('Information', 'Warning', 'Error')]
        [string]$Severity = 'Information',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Message
    )

    [pscustomobject]@{
        Time     = (Get-Date -Format "dd-MMM-yyyy HH:mm:ss.fff")
        Severity = $Severity
        Message  = $Message
    } | Export-Csv -Path $logfile -Append -NoTypeInformation
}

if($CreatCred)
{
    
    Get-Credential | Export-Clixml -Path "$PSScriptRoot\${env:USERNAME}_cred.xml"
}



Switch ($Mode)
{
    "UP"   {$ConnectionString = "Server=$DBServer;Database=$DBName;Uid=$Username;Pwd=$Password;"}
    "DSN"  {$ConnectionString ="DSN=Web";}
    "SSPI" {$ConnectionString = "Server=$DBServer;Database=$DBName;Integrated Security=true;"}
}


function Get-Data {
    [CmdletBinding()]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ConnectionString = 'Information',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Query
    )

    $DS = Invoke-Sqlcmd -ConnectionString $ConnectionString -Query $Query
    $JSON = $DS | ConvertTo-Json -Depth 1
    Write-Host $JSON
    
}