<#
Script to be used to migrate databases from a source server to a destination server

Script should: 
1. Read a list of databases from a CSV file
2. For each database within the csv file
    a. Take a backup of the database from the source database
    b. Copy the backup to the destination server
    c. Restore the backup to the destination server
    d. Log the output
#>

# params
# srcSQLServer - the Server we are copying drom
# destSQLServer - the Server we are copying to
# $databaseCSV - a CSV file which contains the databases we wish to migrate

param($srcSQLServer, $destSQLServer, $databaseCSV)

if (-not $srcSQLServer) {
    throw 'You must supply a source SQL Server with the parameter -srcSQLServer'
}

if (-not $destSQLServer) {
    throw 'You must supply a destination SQL Server with the parameter -destSQLServer'
}

if (-not $databaseCSV) {
    throw 'You must supply a CSV file with the databases which you wish to restore -databaseCSV'
}

# Confirmation to ensure we aren't overwriting any data we don't want to
$confirmation = Read-Host "Are you sure you want to restore databases from $srcSQLServer to $destSQLServer ? [y,n]"
while($confirmation -ne "y")
{
    if ($confirmation -eq "n") {
        Write-Output "Exiting......."
        exit
    }
}


"Beginning........"

# Get the current location so that we can switch back to this context after SQL Calls
$workingLocation = Get-Location

# Set up Source and Destination Servers
$backupDir = "\\$srcSQLServer\g$\backup\temp"
$restoreDir = "\\$destSQLServer\g$\backup\temp"


# Check that the temporary backup dir exists, if not create it.
if (! (Test-Path -LiteralPath $backupDir)) {
    try {
        Write-Output "Temp backup folder doesnt exist creating ... "
        New-Item -Path $backupDir -ItemType Directory  -ErrorAction Stop
        Write-Output "Temp backup folder created"
    }
    catch {
        Write-Error -Message "Unable to create directory '$destDir'. Error was: $_" -ErrorAction Stop
    }
} 
else {
    Write-Output "Temp backup folder exists"
}

# check that the restore path exists otherwise create it
if (!(Test-Path -LiteralPath $restoreDir)) {
    try {
        Write-Output "Removing temp dir to allow new files to be created "
        New-Item -Path $restoreDir -ItemType Directory  -ErrorAction Stop
    }
    catch {
        Write-Error -Message "Unable to create directory '$restoreDir'. Error was: $_" -ErrorAction Stop
    }
} 
else {
    Write-Output "Temp restore folder exists"
}



# Define the CSV file that lists the databases

# Check that there is a source and a destination SQL server specified
if(!$srcSQLServer -or !$destSQLServer) {
    Write-Error "No Source or Destination SQL servers provided"
    exit
}

# Check that a file was provided or otherwise quit
if (!$databaseCSV) {
    Write-Error "No database CSV provided"
    exit
}

# Import the CSV file into an array for future use
$databaseArr = Import-CSV $databaseCSV
Write-Output "Import Complete, imported $($databaseArr.Length) databases"

# backup databases to the srcSQL Server \\<srcSQLServer\g$\backup\temp>
ForEach ($i in $databaseArr){
    $database = $i.databases
    
    try{

        Write-Output "Processing $($database)"
        # Creating database backup
        Write-Output "Backing up $($database) on source server - $($srcSQLServer)"
        Invoke-Sqlcmd -ServerInstance $srcSQLServer -Database "master" -Query "BACKUP DATABASE $database TO DISK = '$backupDir\$database.bak' " -Verbose
        Write-Output "Database backed up - $database to '$backupDir\$database.bak'"
        # Copy backup to destination Server
    } 
    catch {
        Write-Error -Message "Unable to backup $database'. Error was: $_" -ErrorAction Stop
    }
        
        # After SQL calls, push back to the previous context (Working Directory)
        Push-Location -path $workingLocation


    try {
         # Move the backups to the destination SQL Server
         Write-Output "Attempting to move backup $database.bak to $restoreDir\$database.bak  to destination SQL server" 
         Copy-Item $backupDir\$database.bak -Destination $restoreDir\$database.bak
         Write-Output "Success"
    }
    catch {
        Write-Error -Message "Unable to move $database'. Error was: $_" -ErrorAction Stop
    }
       
    try {
        # Remove the backups from the source server to tidy things up
        Write-Output "Removing backup $database.bak from the source SQL server "
        Remove-item $backupDir\$database.bak
        Write-Output "$backupDir\$database.bak removed from source SQL Server "
    }
    catch {
        Write-Error -Message "Unable to remove $backupdir\$databse'. Error was: $_" -ErrorAction Stop
    }
    

    #### Restore the databases on the destination server ####

    # First take the database offline
    try {
        Write-Output "Taking $database offline"
        Invoke-Sqlcmd -ServerInstance $destSqlServer -Database "master" -Query "ALTER DATABASE $database set OFFLINE with rollback immediate" -verbose -ErrorAction Stop
    } 
    catch {
        Write-Error -Message "Unable to take $database offline'. Error was: $_" -ErrorAction Stop
    }
    
    # Restore the database with replace - this also brings the database back online 
    try {
        Write-Output "Restoring $database on $destSqlServer"
        Invoke-Sqlcmd -ServerInstance $destSqlServer -Database "master" -Query "RESTORE DATABASE $database FROM DISK= '$restoreDir\$database.bak' WITH REPLACE" -verbose -ErrorAction Stop
    }
    catch {
        Invoke-Sqlcmd -ServerInstance $destSqlServer -Database "master" -Query "ALTER DATABASE $database set ONLINE" -verbose
        Write-Error -Message "Unable to restore database'. Error was: $_" -ErrorAction Stop
    }
}

   #### Tidy up ####
   Push-Location -path $workingLocation
   try {
       # Remove temp folder on source server
       Remove-item $backupDir
       # Remove temp folder on destination server
       Remove-item -Recurse $restoreDir 
   } 
   catch {
       Write-Error -Message "Unable to remove temporary folder'. Error was: $_" -ErrorAction Stop
   }

