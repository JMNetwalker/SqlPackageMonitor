# SqlPackageMonitor
Inform about SQLPackage operations

We used to have cases where our customer asked what is current of SqlPackage, do I need more resources in my database to import the data?, etc.. In this article you we are going to give some insights about it. 

- **I developed this small PowerShell Script to run some queries using some DMVs to obtain the current status of SQLPackage Import process:**

  + Check the rows, space used, allocated and numbers of tables per schema.
  + Check the number of connections and current status of sessions established by SQLPackage.
  + Show the number of requests and wait stats.
  + Show the number of indexes and constrains disabled or not.
  + Show the performance counters of the database.

Basically we need to configure the parameters:

## Connectivity

- **$server** = "xxxxx.database.windows.net" // Azure SQL Server name
- **$user** = "xxxxxx" // User Name
- **$passwordSecure** = "xxxxxx" // Password
- **$Db** = "xxxxxx"      // Database Name, if you type the value ALL, all databases will be checked.
- **$Folder** = $true     // Folder where the log file will be generated with all the issues found.

## Outcome

- **PerfSqlPackage.Log** = Contains all the data collected found.

Enjoy!
