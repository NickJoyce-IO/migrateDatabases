# migrateDatabases
A tool to migrate 1 or more SQL databases. Database names are read from a CSV file, the databases are then migrated from the source server to the destination server. 

This may be useful if you need to migrate SQL databases between Non-Production environments. It also may be useful if you need to copy back Production SQL databases to Non-Production environment.

Steps for use:

1. Rename the databasesSample.csv file to databases.csv
2. Populate the file with the names of the databases you wish to copy (the databases must already exist on both servers)
3. Update the script with the following vars and save
``` powershell
# Set up Source and Destination Servers, you may have different extensions always use temp as the temporary folder, if you use your
# root backup folder the script will remove the dir at the end. So best avoided.
$srcSQLServer = "<SQL Server name>"
$destSQLServer = "<SQL Server name>"
$backupDir = "\\$srcSQLServer\g$\backup\temp"
$restoreDir = "\\$destSQLServer\g$\backup\temp"
```
4. Run the script