#----------------------------------------------------------------
# Application: SQLPackage Monitor
# Propose: Inform about SQLPackage operations
# Checks:
#    1) Check the rows, space used, allocated and numbers of tables per schema. 
#    2) Check the number of connections and current status of sessions established by SQLPackage. 
#    3) Show the number of requests and wait stats 
#    4) Show the numbers of indexes and constrains disabled or not. 
#    5) Show the performance counters of the database
# Outcomes: 
#    In the folder specified in $Folder variable we are going to have a file called PerfSqlPackage.Log that contains all the data collected.
#----------------------------------------------------------------

#----------------------------------------------------------------
#Parameters 
#----------------------------------------------------------------
param($server = "", #ServerName parameter to connect,for example, myserver.database.windows.net
      $user = "", #UserName parameter  to connect
      $passwordSecure = "", #Password Parameter  to connect
      $Db = "", #DBName Parameter  to connect
      $Folder = "c:\PerfSqlPackage") #Folder Parameter to save the log and solution files, for example, c:\PerfSqlPackage


#-------------------------------------------------------------------------------
# Check the rows, space used, allocated and numbers of tables per schema. 
#-------------------------------------------------------------------------------
function CheckStatusPerSchema($connection)
{
 try
 {
   logMsg( "---- Checking Status per Schema ---- " ) (1) -ShowDate $false

   $Found = $false

   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 60
   $command.Connection=$connection
   $command.CommandText = "SELECT s.Name,
                            COUNT(*) AS Total,  
	                        sum(case when p.rows = 0 then 1 else 0 end) NonSalesCount,
                            sum(case when p.rows <> 0 then 1 else 0 end) SalesCount,
                             SUM(p.rows) AS RowCounts,
                             SUM(a.total_pages) * 8 AS TotalSpaceKB, 
                             SUM(a.used_pages) * 8 AS UsedSpaceKB, 
                             (SUM(a.total_pages) - SUM(a.used_pages)) * 8 AS UnusedSpaceKB
                        FROM 
                            sys.tables t
                        INNER JOIN      
                            sys.indexes i ON t.OBJECT_ID = i.object_id
                        INNER JOIN 
                            sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
                        INNER JOIN 
                            sys.allocation_units a ON p.partition_id = a.container_id
                        LEFT OUTER JOIN 
                            sys.schemas s ON t.schema_id = s.schema_id
                        WHERE t.is_ms_shipped = 0
                            AND i.OBJECT_ID > 255 
                        GROUP BY 
                            s.Name"
  $Reader = $command.ExecuteReader(); 
  $StringReport = "Schema      "
  $StringReport = $StringReport + "Total      "
  $StringReport = $StringReport + "To Process         "
  $StringReport = $StringReport + "Processed          "  
  $StringReport = $StringReport + "Rows                        "                   
  $StringReport = $StringReport + "Space                       "                  
  $StringReport = $StringReport + "Used                        "                   
  logMsg($StringReport) -ShowDate $false
  
  while($Reader.Read())
   {

    $lTotal = $Reader.GetValue(1)
    $lTotal0 = $Reader.GetValue(2)
    $lTotal1 = $Reader.GetValue(3)
    $lTotalRows = $Reader.GetValue(4)
    $lTotalSpace = $Reader.GetValue(5)
    $lTotalUsed = $Reader.GetValue(6)
    $lTotalUnUsed = $Reader.GetValue(7)

    $Found=$false
    $Number=0

     for ($i=0; $i -lt $IPControlSchema.Count; $i++)
     {
       if( $IPControlSchema[$i].Schema -eq $Reader.GetValue(0))
       {
          $Found=$true
          $Number=$i
          break
       }
     }

    
    $StringReport = $Reader.GetValue(0).ToString().PadRight(10).Substring(0,9) + " "
    $StringReport = $StringReport + $lTotal.ToString('N0').PadLeft(10) + " "
    $StringReport = $StringReport + $lTotal0.ToString('N0').PadLeft(10) + "-" + ($lTotal0*100/$lTotal).ToString('N1').PadLeft(6) + "% "
    $StringReport = $StringReport + $lTotal1.ToString('N0').PadLeft(10) + "-" + ($lTotal1*100/$lTotal).ToString('N1').PadLeft(6) + "% " 

    if($Found -eq $true -and $lTotalRows -ne 0)
     {
        $TotalRowsOld = $lTotalRows - $IPControlSchema[$Number].Rows
        $TotalSpaceOld = $lTotalSpace - $IPControlSchema[$Number].Space
        $TotalUsedOld = $lTotalUsed - $IPControlSchema[$Number].Used

        $StringReport = $StringReport + $lTotalRows.ToString('N0').PadLeft(20) + "-" + ($TotalRowsOld*100/$lTotalRows).ToString('N1').PadLeft(6) + "% "
        $StringReport = $StringReport + $lTotalSpace.ToString('N0').PadLeft(20) + "-" + ($TotalSpaceOld*100/$lTotalSpace).ToString('N1').PadLeft(6) + "% "
        $StringReport = $StringReport + $lTotalUsed.ToString('N0').PadLeft(20) + "-" + ($TotalUsedOld*100/$lTotalUsed).ToString('N1').PadLeft(6) + "% "
     }
    else
    {
     $StringReport = $StringReport + $lTotalRows.ToString('N0').PadLeft(20) + " " 
     $StringReport = $StringReport + $lTotalSpace.ToString('N0').PadLeft(20)  + " "
     $StringReport = $StringReport + $lTotalUsed.ToString('N0').PadLeft(20)  
    }
     if($Found -eq $false)
     {
        $Tmp = [TotalPerSchema]::new()
        $TMP.Schema = $Reader.GetValue(0)
        $TMP.Total= $lTotal
        $TMP.ToProcess= $lTotal0
        $TMP.Processed=$lTotal1
        $TMP.Rows=$lTotalRows
        $TMP.Space= $lTotalSpace
        $TMP.Used=$lTotalUsed
        $TMP.UnUsed=$lTotalUnUsed
        $IPControlSchema.Add($TMP) | Out-Null
        $Number=$IPControlSchema.Count-1
     }
     else
     {
        $IPControlSchema[$Number].Total= $lTotal
        $IPControlSchema[$Number].ToProcess= $lTotal0
        $IPControlSchema[$Number].Processed=$lTotal1
        $IPControlSchema[$Number].Rows=$lTotalRows
        $IPControlSchema[$Number].Space= $lTotalSpace
        $IPControlSchema[$Number].Used=$lTotalUsed
        $IPControlSchema[$Number].UnUsed=$lTotalUnUsed
     }

    logMsg($StringReport) -ShowDate $false
   }

   $Reader.Close();
  }
  catch
   {
    $Reader.Close();
    logMsg("Not able to run Checking Status per Schema..." + $Error[0].Exception) (2)
   } 

}

#-------------------------------------------------------------------------------
# Check the number of connections and current status of sessions established by SQLPackage. 
#-------------------------------------------------------------------------------
function CheckStatusConnections($connection)
{
 try
 {
   logMsg( "---- Checking Status per connections  ---- " ) (1) -ShowDate $false
   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 60
   $command.Connection=$connection
   $command.CommandText = "select sess.session_id, status, host_name, host_process_id, login_time, SUBSTRING(client_net_address,1,6)
                           from sys.dm_exec_connections conns
                           inner join sys.dm_exec_sessions sess on conns.session_id= sess.session_id
                           where program_name ='DacFx Deploy'"
  $Reader = $command.ExecuteReader(); 
  $StringReport =                 "Session ID           "
  $StringReport = $StringReport + "Status               "
  $StringReport = $StringReport + "HostName             "
  $StringReport = $StringReport + "ProcessID            "              
  $StringReport = $StringReport + "IPAddress            "                  
  $StringReport = $StringReport + "Login Time"                   
  logMsg($StringReport) -ShowDate $false

  while($Reader.Read())
   {
    $StringReport = $Reader.GetValue(0).ToString().PadLeft(20) + " "
    $StringReport = $StringReport + $Reader.GetValue(1).ToString().PadLeft(20) + " "
    $StringReport = $StringReport + $Reader.GetValue(2).ToString().PadLeft(20) + " "
    $StringReport = $StringReport + $Reader.GetValue(3).ToString().PadLeft(20) + " "
    $StringReport = $StringReport + $Reader.GetValue(5).ToString().PadLeft(20) + " "
    $StringReport = $StringReport + $Reader.GetValue(4).ToString().PadLeft(20) + " "
    logMsg($StringReport) -ShowDate $false
   }

   $Reader.Close();
  }
  catch
   {
    logMsg("Not able to run Checking Status per connections..." + $Error[0].Exception) (2)
   } 

}

#-------------------------------------------------------------------------------
# Show the number of requests and wait stats 
#-------------------------------------------------------------------------------

function CheckStatusPerRequest($connection)
{
 try
 {
   logMsg( "---- Checking Status per Requests ---- " ) (1) -ShowDate $false
   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 60
   $command.Connection=$connection
   $command.CommandText = "select sess.session_id, request.status, last_wait_type, request.cpu_time, request.total_elapsed_time, substring
                        (REPLACE
                        (REPLACE
                        (SUBSTRING
                        (ST.text
                        , (request.statement_start_offset/2) + 1
                        , (
                        (CASE statement_end_offset
                        WHEN -1
                        THEN DATALENGTH(ST.text)
                        ELSE request.statement_end_offset
                        END
                        - request.statement_start_offset)/2) + 1)
                        , CHAR(10), ' '), CHAR(13), ' '), 1, 512) AS statement_text
                        from sys.dm_exec_connections conns
                        inner join sys.dm_exec_sessions sess on conns.session_id= sess.session_id
                        inner join sys.dm_exec_requests request on request.session_id= sess.session_id
                        CROSS APPLY sys.dm_exec_sql_text(request.sql_handle) as ST
                        where program_name ='DacFx Deploy'"
  $Reader = $command.ExecuteReader(); 
  $StringReport =                 "Session ID "
  $StringReport = $StringReport + "Status     "  
  $StringReport = $StringReport + "Last Wait Type                 "  
  $StringReport = $StringReport + "CPU      "  
  $StringReport = $StringReport + "Elapsed  "  
  $StringReport = $StringReport + "Query"  
                  
  logMsg($StringReport) -ShowDate $false
  while($Reader.Read())
   {
    $StringReport = $Reader.GetValue(0).ToString().PadLeft(10) + " "
    $StringReport = $StringReport + $Reader.GetValue(1).ToString().PadRight(10) + " "
    $StringReport = $StringReport + $Reader.GetValue(2).ToString().PadRight(30) + " "
    $StringReport = $StringReport + $Reader.GetValue(3).ToString().PadLeft(8) + " "
    $StringReport = $StringReport + $Reader.GetValue(4).ToString().PadLeft(8) + " "
    $StringReport = $StringReport + $Reader.GetValue(5).ToString().Substring(0,60) 
    logMsg($StringReport) -ShowDate $false
   }

   $Reader.Close();
  }
  catch
   {
    logMsg("Not able to run Checking Status per Requests..." + $Error[0].Exception) (2)
   } 

}

#-------------------------------------------------------------------------------
# Show the performance counters of the database
#-------------------------------------------------------------------------------

function CheckStatusPerResource($connection)
{
 try
 {
   logMsg( "---- Checking Status per Resources ---- " ) (1) -ShowDate $false
   $command = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $command.CommandTimeout = 60
   $command.Connection=$connection
   $command.CommandText = "select top 10 end_time, avg_cpu_percent, avg_data_io_percent, avg_log_write_percent, avg_memory_usage_percent, max_worker_percent from sys.dm_db_resource_stats order by end_time desc"

  $Reader = $command.ExecuteReader(); 
  $StringReport = "Time                 "
  $StringReport = $StringReport + "Avg_Cpu    "
  $StringReport = $StringReport + "Avg_DataIO "
  $StringReport = $StringReport + "Avg_Log    "              
  $StringReport = $StringReport + "Avg_Memory "                   
  $StringReport = $StringReport + "Max_Workers"                  

  logMsg($StringReport) -ShowDate $false
  while($Reader.Read())
   {
    $lTotalCPU = $Reader.GetValue(1)
    $lTotalDataIO = $Reader.GetValue(2)
    $lTotalLog = $Reader.GetValue(3)
    $lTotalMemory = $Reader.GetValue(4)
    $lTotalWorkers = $Reader.GetValue(5)
    $StringReport = $Reader.GetValue(0).ToString().PadLeft(20) + " "
    $StringReport = $StringReport + $lTotalCPU.ToString('N2').PadLeft(10) + " "
    $StringReport = $StringReport + $lTotalDataIO.ToString('N2').PadLeft(10) 
    $StringReport = $StringReport + $lTotalLog.ToString('N2').PadLeft(10) 
    $StringReport = $StringReport + $lTotalMemory.ToString('N2').PadLeft(10) 
    $StringReport = $StringReport + $lTotalWorkers.ToString('N2').PadLeft(10) 
    ##$StringReport = $StringReport + " - NonUsed:"            + $lTotalUnUsed.ToString('N0')  
    logMsg($StringReport) -ShowDate $false
   }

   $Reader.Close();
  }
  catch
   {
    logMsg("Not able to run Checking Status per Resources..." + $Error[0].Exception) (2)
   } 

}

#-------------------------------------------------------------------------------
# Show the numbers of indexes and constrains disabled or not. 
#-------------------------------------------------------------------------------

function CheckStatusIndixesContrainstsDisabled($connection)
{
 try
 {
   logMsg( "---- Checking Status per Indexes/Constraints disabled  ---- " ) (1) -ShowDate $false
   $commandIndx = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $commandIndx.CommandTimeout = 60
   $commandIndx.Connection=$connection
   $commandIndx.CommandText = "select ISNULL(sum(case when is_disabled = 0 then 1 else 0 end),0) NoDisabled,
                                      ISNULL(sum(case when is_disabled = 1 then 1 else 0 end),0) YesDisabled from sys.indexes ind
                                      inner join sys.tables tables on ind.object_id = tables.object_id where tables.is_ms_shipped=0 and ind.index_id>1"

   $commandCons = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $commandCons.CommandTimeout = 60
   $commandCons.Connection=$connection
   $commandCons.CommandText = "select ISNULL(sum(case when is_disabled = 0 then 1 else 0 end),0) NoDisabled,
                                      ISNULL(sum(case when is_disabled = 1 then 1 else 0 end),0) YesDisabled from sys.check_constraints"

   $commandConsFK = New-Object -TypeName System.Data.SqlClient.SqlCommand
   $commandConsFK.CommandTimeout = 60
   $commandConsFK.Connection=$connection
   $commandConsFK.CommandText = "select ISNULL(sum(case when is_disabled = 0 then 1 else 0 end),0) NoDisabled,
                                        ISNULL(sum(case when is_disabled = 1 then 1 else 0 end),0) YesDisabled from sys.foreign_keys"

   $lIndDisableNo = 0
   $lIndDisableYes = 0
   $lConsDisableNo = 0
   $lConsDisableYes = 0
   $lConsDisableFKNo = 0
   $lConsDisableFKYes = 0


  $ReaderIndx = $commandIndx.ExecuteReader(); 

  while($ReaderIndx.Read())
   {
    $lIndDisableNo = $ReaderIndx.GetValue(0)
    $lIndDisableYes = $ReaderIndx.GetValue(1)
   }
   $ReaderIndx.Close()

    $ReaderCons = $commandCons.ExecuteReader(); 
   while($ReaderCons.Read())
   {
    $lConsDisableNo = $ReaderCons.GetValue(0)
    $lConsDisableYes = $ReaderCons.GetValue(1)
   }
   $ReaderCons.Close()

   $ReaderConsFK = $commandConsFK.ExecuteReader(); 
   while($ReaderConsFK.Read())
   {
    $lConsDisableFKNo = $ReaderConsFK.GetValue(0)
    $lConsDisableFKYes = $ReaderConsFK.GetValue(1)
   }
   $ReaderConsFK.Close()


   $StringReport = "Indexes disabled:" + $lIndDisableYes.ToString() + " No Disable: " + $lIndDisableNo.ToString()
   $StringReport = $StringReport + " Constrains disabled:" + $lConsDisableYes.ToString() + " No Disable: " + $lConsDisableNo.ToString()
   $StringReport = $StringReport + " Constrains FK disabled:" + $lConsDisableFKYes.ToString() + " No Disable: " + $lConsDisableFKNo.ToString()

   logMsg($StringReport) -ShowDate $false
  }
  catch
   {
    logMsg("Not able to run Checking Status per Indexes/Constraints disabled  ..." + $Error[0].Exception) (2)
   } 

}

#----------------------------------------------------------------
#Function to connect to the database using a retry-logic
#----------------------------------------------------------------

Function GiveMeConnectionSource()
{ 
  for ($i=1; $i -lt 10; $i++)
  {
   try
    {
      logMsg( "Connecting to the database..." + $Db + ". Attempt #" + $i) (1) -SaveFile $false
      $SQLConnection = New-Object System.Data.SqlClient.SqlConnection 
      $SQLConnection.ConnectionString = "Server="+$server+";Database="+$Db+";User ID="+$user+";Password="+$password+";Connection Timeout=60;Application Name=PerfCollector" 
      $SQLConnection.Open()
      logMsg("Connected to the database.." + $Db) (1) -SaveFile $false
      return $SQLConnection
      break;
    }
  catch
   {
    logMsg("Not able to connect - Retrying the connection..." + $Error[0].Exception) (2) -SaveFile $false
    Start-Sleep -s 5
   }
  }
}

#--------------------------------------------------------------
#Create a folder 
#--------------------------------------------------------------
Function CreateFolder
{ 
  Param( [Parameter(Mandatory)]$Folder ) 
  try
   {
    $FileExists = Test-Path $Folder
    if($FileExists -eq $False)
    {
     $result = New-Item $Folder -type directory 
     if($result -eq $null)
     {
      logMsg("Imposible to create the folder " + $Folder) (2)
      return $false
     }
    }
    return $true
   }
  catch
  {
   return $false
  }
 }

#-------------------------------
#Create a folder 
#-------------------------------
Function DeleteFile{ 
  Param( [Parameter(Mandatory)]$FileName ) 
  try
   {
    $FileExists = Test-Path $FileNAme
    if($FileExists -eq $True)
    {
     Remove-Item -Path $FileName -Force 
    }
    return $true 
   }
  catch
  {
   return $false
  }
 }

#--------------------------------
#Log the operations
#--------------------------------
function logMsg
{
    Param
    (
         [Parameter(Mandatory=$true, Position=0)]
         [string] $msg,
         [Parameter(Mandatory=$false, Position=1)]
         [int] $Color,
         [Parameter(Mandatory=$false, Position=2)]
         [boolean] $Show=$true,
         [Parameter(Mandatory=$false, Position=3)]
         [boolean] $ShowDate=$true,
         [Parameter(Mandatory=$false, Position=4)]
         [boolean] $SaveFile=$true 
 
    )
  try
   {
    if($ShowDate -eq $true)
    {
      $Fecha = Get-Date -format "yyyy-MM-dd HH:mm:ss"
    }
    $msg = $Fecha + " " + $msg
    If($SaveFile -eq $true)
    {
      Write-Output $msg | Out-File -FilePath $LogFile -Append
    }
    $Colores="White"
    $BackGround = 
    If($Color -eq 1 )
     {
      $Colores ="Cyan"
     }
    If($Color -eq 3 )
     {
      $Colores ="Yellow"
     }

     if($Color -eq 2 -And $Show -eq $true)
      {
        Write-Host -ForegroundColor White -BackgroundColor Red $msg 
      } 
     else 
      {
       if($Show -eq $true)
       {
        Write-Host -ForegroundColor $Colores $msg 
       }
      } 


   }
  catch
  {
    Write-Host $msg 
  }
}

#--------------------------------
#The Folder Include "\" or not???
#--------------------------------

function GiveMeFolderName([Parameter(Mandatory)]$FolderSalida)
{
  try
   {
    $Pos = $FolderSalida.Substring($FolderSalida.Length-1,1)
    If( $Pos -ne "\" )
     {return $FolderSalida + "\"}
    else
     {return $FolderSalida}
   }
  catch
  {
    return $FolderSalida
  }
}

#--------------------------------
#Validate Param
#--------------------------------
function TestEmpty($s)
{
if ([string]::IsNullOrWhitespace($s))
  {
    return $true;
  }
else
  {
    return $false;
  }
}

#--------------------------------
#Separator
#--------------------------------

function GiveMeSeparator
{
Param([Parameter(Mandatory=$true)]
      [System.String]$Text,
      [Parameter(Mandatory=$true)]
      [System.String]$Separator)
  try
   {
    [hashtable]$return=@{}
    $Pos = $Text.IndexOf($Separator)
    $return.Text= $Text.substring(0, $Pos) 
    $return.Remaining = $Text.substring( $Pos+1 ) 
    return $Return
   }
  catch
  {
    $return.Text= $Text
    $return.Remaining = ""
    return $Return
  }
}

Function Remove-InvalidFileNameChars {

param([Parameter(Mandatory=$true,
    Position=0,
    ValueFromPipeline=$true,
    ValueFromPipelineByPropertyName=$true)]
    [String]$Name
)

return [RegEx]::Replace($Name, "[{0}]" -f ([RegEx]::Escape([String][System.IO.Path]::GetInvalidFileNameChars())), '')}



try
{
Clear

Class TotalPerSchema 
{
 [string]$Schema = ""
 [string]$OtherIP = ""
 [long]$Total= 0
 [long]$ToProcess= 0
 [long]$Processed=0
 [long]$Rows=0
 [long]$Space=0
 [long]$Used=0
 [long]$UnUsed=0
}

   $TotalPerSchema  = [TotalPerSchema]::new()
   $IPControlSchema = [System.Collections.ArrayList]::new()

#--------------------------------
#Check the parameters.
#--------------------------------

if (TestEmpty($server)) { $server = read-host -Prompt "Please enter a Server Name" }
if (TestEmpty($user))  { $user = read-host -Prompt "Please enter a User Name"   }
if (TestEmpty($passwordSecure))  
    {  
    $passwordSecure = read-host -Prompt "Please enter a password"  -assecurestring  
    $password = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($passwordSecure))
    }
else
    {$password = $passwordSecure} 
if (TestEmpty($Db))  { $Db = read-host -Prompt "Please enter a Database Name, type ALL to check all databases"  }
if (TestEmpty($Folder)) {  $Folder = read-host -Prompt "Please enter a Destination Folder (Don't include the last \) - Example c:\PerfChecker" }

$DbsArray = [System.Collections.ArrayList]::new() 

#--------------------------------
#Run the process
#--------------------------------

logMsg("Creating the folder " + $Folder) (1) -SaveFile $false
   $result = CreateFolder($Folder) #Creating the folder that we are going to have the results, log and zip.
   If( $result -eq $false)
    { 
     logMsg("Was not possible to create the folder") (2)
     exit;
    }
logMsg("Created the folder " + $Folder) (1) -SaveFile $false

$sFolderV = GiveMeFolderName($Folder) #Creating a correct folder adding at the end \.

$LogFile = $sFolderV + "PerfSqlPackage.Log"                  #Logging the operations.

logMsg("Deleting Logs") (1) -SaveFile $false
   $result = DeleteFile($LogFile)         #Delete Log file
logMsg("Deleted Logs") (1) -SaveFile $false

   $SQLConnectionSource = GiveMeConnectionSource #Connecting to the database.
   if($SQLConnectionSource -eq $null)
    { 
     logMsg("It is not possible to connect to the database " + $Db ) (2)
     exit;
    }

    while(1 -eq 1)
    { 
     logMsg("Running the collector.." ) (1) 
      CheckStatusPerSchema($SQLConnectionSource)
      CheckStatusConnections($SQLConnectionSource)
      CheckStatusPerRequest($SQLConnectionSource)
      CheckStatusPerResource($SQLConnectionSource)
      CheckStatusIndixesContrainstsDisabled($SQLConnectionSource)
     logMsg("Waiting for next cycle.." ) (1) -ShowDate $false -SaveFile $false
     Start-Sleep -Seconds 5 | Out-Null
    }   
   $SQLConnectionSource.Close() 

 Remove-Variable password
}
catch
  {
    logMsg("SQLPackage Collector Script was executed incorrectly ..: " + $Error[0].Exception) (2)
  }
finally
{
   logMsg("SQLPackage Collector Script finished - Check the previous status line to know if it was success or not") (2)
} 