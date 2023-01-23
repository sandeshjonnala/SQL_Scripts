/*
===================================
Performance Analysis v2_6.sql
Purpose: To verify configuration settings and best practices
Version: 2.6
Orig Created: 12/20/2014
Last Modified: 11/16/2020
	v1.0
	- added s.fill_factor to index frag script. -2/8/16 SGR
	v1.1
	- corrected DB I/O comments. -4/15/16 SGR
	- modified 'Version Check' section to provide physical memory values depending on SQL version. -4/25/16 SGR
	- corrected VLF code when dealing with db names that have dashes. -4/26/16 SGR
	- corrected trace flag 1117 status. -4/26/16 SGR 
	- removed the split in script so now all is run in one swoop; you can still toggle index frag portion but other than that...
	  one script for all. -5/19/16 SGR
	v2.0
	- removed the OS checks section. -7/31/16 SGR
	- modified latest versions of SQL. -8/15/16 SGR
	- removed dbcc info msgs. -8/22/16 SGR
	v2.1
	- added risky SPs/CUs messages. -9/12/16 SGR
	- removed extra CRLFs in verifications output. -9/12/16 SGR
	- added SOPHOS~2.DLL. -9/23/16 SGR
	- added nocount for batch scope. -9/25/16 SGR
	- trace flag check not necessary for SQL 2016. -9/25/16 SGR
	v2.2
	- added code to prune duplicate indexes (unique vs non-unique). -11/6/16 SGR
	- 2016 SP1 updates: lock pages in memory and instant file initialization checks. -12/12/16 SGR
			- have to check for the version before checking if these are enabled.
			- 2016 SP1 -> 13.0.4001.0 or 13.1.4001.0
	v2.3
	- version check confirmed -4/15/17 SGR (... not sure what this is ...)
	- OS vs SQL CPU -4/17/17 SGR
	- added code to ignore snapshots when querying sys.databases -4/29/17 SGR
	- is encryption enabled? -4/29/17 SGR
		- there shouldn't be backup compression on these databases (unless at least 2016 RTM CU7, 2016 SP1 CU4)
	- is this a VM? -6/5/17 SGR
	- is this HADR enabled? -6/5/17 SGR
		- what is the health of the AG and who are the replicas? -6/5/17 SGR
	- rearranged Max DOP to make sense logically. -6/24/17 SGR
	- check OS mem vs SQL mem. -6/30/17 SGR
	- minor changes made to handle case sensitive collation. -11/4/17 SGR
	v2.4
	- added versNumber for 2017
	- check for security update to address Meltdown and Spectre vulnerabilities (CVE 2017-5715, 2017-5753, 2017-5754); 
		Update will address SQL performance due to OS patches to address same vulnerabilities
	- changed VLF check to 500 -1/29/18 SGR
	- supported version check 2012 SP4 -1/29/18 SGR
	- supported version check 2017 RTM -1/29/18 SGR
	- added code for Amazon RDS -2/2/18 SGR
		- checks removed:
			- owner of object (dbs and jobs)
			- VLF count
			- last integrity check execution
	v2.4.1
	- added getdate() to Messages tab -2/17/18 SGR
	- added to risky SPs/CUs messages for 2016 (TDE and backup compression)
	- added note to backup compression
	- rearranged version check details -3/4/18 SGR
	- output values for certain server level settings instead of 'VERIFY SETTINGS' -3/5/18 SGR

	v2.5 
	- changed variable size for cost threshold for parallelism -5/20/18 SGR
	- supported version check for 2016 SP2 -5/20/18 SGR
	- SQL Server start time -7/16/2018 SGR
	- add wait types related to newer versions of SQL Server (so far just AlwaysOn)  -11/4/2018 SGR
	    HADR_SYNC_COMMIT
		PARALLEL_REDO_FLOW_CONTROL
        PARALLEL_REDO_TRAN_TURN
	    DIRTY_PAGE_TABLE_LOCK
	- added is_encrypted to DB Settings results -9/24/18 SGR
	- fixed issue with @vmType in servers < 2008R2 -11/4/18 SGR

	v2.5.1
	- added code to ignore errors when executed in Azure SQL Managed Instance (no major changes) -1/12/2019 SGR
	- added code to ignore tempdb on integrity check...checks -1/12/2019 SGR
	- fixed output message for 2012 SP3/SP4 -1/19/19 SGR
	- 2012 SP4 updates: lock pages in memory and instant file initialization checks -1/20/19 SGR
	- 2014 SP3 released 10/30/18; should be Rackspace-supported on 1/30/2019   -1/26/19 SGR
	- changed database count variables to varchar(5) in various locations -1/26/19 SGR
    - increased max values for maxdop, max full-text range, and cost threshold for parallelism   -1/26/19 SGR

	v2.6
	- change trace flag check to >= 2016 instead of = 2016  -2/23/19 SGR
	- extended variable size for total IO dbs -2/17/19 SGR
	- now only checking statistics last update date on each database if index frag levels also being checked (@bFragLevels set at the top, defaulted to 0) -1/20 SGR
	- 2019 RTM released 11/4/2019; should be RS-supported on 2/4/2020 -1/4/20 SGR
		The Modern Servicing Model (MSM): Starting from SQL Server 2017 Service Packs will no longer be released as of Oct 24, 2017 -1/20/2020 SGR 
	- Changed Sophos check as specific loaded DLL wasn't picked up by query  -1/18/20 SGR
	- added 2019 version identification - 2/20 SGR
	- increased memNum decimal size to 15,2 from 5,2 -2/24/20 SGR
	- are full-text indexes being utilized? if not, ignore full-text crawl setting  -3/14/20 SGR
	- note about backup compression and encryption being used together AND below a certain version  -2/14/20 SGR
	- obsolete versions (< 2012) in supported version check -3/15/20 SGR
	- trace flag 3226 & 2371 checks (logging of successful backups in error log & thresholds to update stats, respectively)  -10/10/20 SGR
	- remote admin connections -10/10/20 SGR
	- added more version issues and their fixes  -10/17/20 SGR
	- added to risky SPs/CUs messages for 2017  -10/25/20 SGR


	*** I've decided to use a separate script (hopefully just one) for all Cloud Services (AWS, Azure, Google, etc.) since
	    those changes take longer for me to test which prevents me from getting this standard one out more quickly -11/4/2018 SGR
===================================
*/

set ansi_warnings off
set nocount on
go

declare @bShowSettingsResults bit, @bFragLevels bit, @bIsAmazonRDS bit, @bIsAzureSQLDB bit, @bIsAzureSQLMI bit, @lastSQLRestart datetime

set @bShowSettingsResults = 1	-- THIS PARAMETER WILL SHOW SETTINGS RESULTS IN GRID, MOSTLY FOR TESTING OR VERIFYING RESULTS
set @bFragLevels = 0	--IF SET TO 1, CHECK INDEX FRAGMENTATION ON HIGHEST WRITE DB ONLY and STATISTICS ON EVERY DATABASE; OTHERWISE, DO NOT CHECK INDEX FRAG LEVELS or STATSTICS

set @bIsAmazonRDS = case when DB_ID('rdsadmin') is not null and suser_sname(0x01) = 'rdsa' then 1 else 0 end
set @bIsAzureSQLDB = case when SERVERPROPERTY('EngineEdition') = 5 then 1 else 0 end	--SQL Database
set @bIsAzureSQLMI = case when SERVERPROPERTY('EngineEdition') = 8 then 1 else 0 end	--SQL Managed Instance only
select @lastSQLRestart = sqlserver_start_time FROM sys.dm_os_sys_info;

--Version check
declare @sql2 nvarchar(max)
declare @MemNum Nvarchar(max)
declare @CPU varchar (10)
declare @visibleCPU varchar(10)
declare @vSQLMaxMem int
declare	@fullVersion varchar(15)
declare @buildVersion int
declare @warnMsg nvarchar(max)
declare @version tinyint
declare @count smallint
declare	@supportedMsg nvarchar(max)
declare @obsoleteMsg nvarchar(max)
declare @rtmMsg nvarchar(max)
declare @sql3 nvarchar(max)
declare @vmType varchar(15)
declare @versNum varchar(20)
--time zone
declare @TimeZone nvarchar(50)
declare @sqlZ nvarchar(max)
--server settings
--declare @maxMem int --not really using
declare @minMem int
declare @maxDop sql_variant
declare @maxCrawl sql_variant
declare @costThresh sql_variant
declare @fullTextInstalled bit


--time zone
if @bIsAmazonRDS = 0 and @bIsAzureSQLMI = 0
begin
	set @sqlZ = 'EXEC master.dbo.xp_regread ''HKEY_LOCAL_MACHINE'',
								''SYSTEM\CurrentControlSet\Control\TimeZoneInformation'',
								''TimeZoneKeyName'',
								@TimeZone OUT'
	exec sp_executesql @sqlZ, N'@TimeZone nvarchar(50) OUTPUT', @TimeZone OUTPUT
end
else
	set @TimeZone = NULL								


if CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)), 4) AS INT) > 10 -- >= 2012
begin 
	set @sql2 = N'SELECT  @MemNum = cast(physical_memory_kb/1024.0/1024.0 as decimal(15,2))
	FROM    sys.dm_os_sys_info'
	set @sql3 = N'select @vmType = virtual_machine_type_desc from sys.dm_os_sys_info'
end

else if CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)), 4) AS INT) = 10 -- 2008 or 2008R2
begin	
	set @sql2 = N'SELECT  @MemNum = cast(physical_memory_in_bytes/1024.0/1024.0/1024.0 as decimal (15,2))	
	FROM    sys.dm_os_sys_info'
	if convert(sysname, SERVERPROPERTY ('productversion')) like '10.5%'
		set @sql3 = N'select @vmType = virtual_machine_type_desc from sys.dm_os_sys_info'
	else 
		set @sql3 = N'SELECT  @vmType = NULL FROM sys.dm_os_sys_info'	
end

else
begin		-- < 2008 (not able to test)
	set @sql2 = N'SELECT  @MemNum = NULL FROM sys.dm_os_sys_info'
	set @sql3 = N'SELECT  @vmType = NULL FROM sys.dm_os_sys_info'
end

EXEC sp_executesql @sql2, N'@MemNum NVARCHAR(max) OUTPUT', @MemNum OUTPUT
EXEC sp_executesql @sql3, N'@vmType NVARCHAR(max) OUTPUT', @vmType OUTPUT
 
set @versNum = case
				when convert(sysname, SERVERPROPERTY ('productversion')) like '8.%' then '2000'
				when convert(sysname, SERVERPROPERTY ('productversion')) like '9.%' then '2005'
				when convert(sysname, SERVERPROPERTY ('productversion')) like '10.0%' then '2008'
				when convert(sysname, SERVERPROPERTY ('productversion')) like '10.5%' then '2008 R2'
				when convert(sysname, SERVERPROPERTY ('productversion')) like '11.%' then '2012'
				when convert(sysname, SERVERPROPERTY ('productversion')) like '12.%' then '2014'
				when convert(sysname, SERVERPROPERTY ('productversion')) like '13.%' then '2016'
				when convert(sysname, SERVERPROPERTY ('productversion')) like '14.%' then '2017'
				when convert(sysname, SERVERPROPERTY ('productversion')) like '15.%' then '2019'
			end

SELECT  @@SERVERNAME as [@@ServerName],
			SERVERPROPERTY ('INSTANCENAME') as InstanceName,		/* NULL if Default Instance */
			SERVERPROPERTY ('edition') as Edition,
			SERVERPROPERTY ('productversion') as ProdVersion, 
			@versNum as Version,
			SERVERPROPERTY ('productlevel') as ProdLevel, 
			SERVERPROPERTY ('MACHINENAME') as MachineName,
			SERVERPROPERTY ('ISCLUSTERED') as IsClustered,
			SERVERPROPERTY ('IsHadrEnabled') as IsHadrEnabled,
			@vmType as VirtMachType,
			SERVERPROPERTY ('collation') as SQLServerCollation,
			cpu_count as [CPU Cnt (LogicalCPUs)], --CORES & HYPERTHREADING INCLUDED IN COUNT
			hyperthread_ratio as [HT Ratio],	--HT INCLUDED IN COUNT
			cpu_count / hyperthread_ratio AS [Physical Sockets], -- aka physical cpu sockets
			@MemNum as PhyMemInGB
	FROM    sys.dm_os_sys_info

select @CPU = i.cpu_count, @visibleCPU = count(s.cpu_id)
from sys.dm_os_sys_info i
cross join sys.dm_os_schedulers s
where s.status = 'VISIBLE ONLINE'
group by i.cpu_count

--SQL vs OS memory check
select @vSQLMaxMem = convert(varchar(max), value_in_use) from sys.configurations where name in ('max server memory (MB)')
--set @vSQLMaxMem = convert(numeric, @vSQLMaxMem)/1024.0


print 'Current Date/Time = ' + convert(sysname, getdate()) + ' ' + isnull(@TimeZone, '')
print 'Last SQL Server Restart = ' + convert(sysname, @lastSQLRestart)
print '@@ServerName = ' + @@servername
if @bIsAzureSQLMI = 0
	print 'Machine name = ' + (convert(sysname, SERVERPROPERTY('MACHINENAME')))
if @@servername <> convert(sysname, SERVERPROPERTY('MACHINENAME'))
	print '   *** Verify @@servername and machine name match ***'
print 'Instance name = ' + isnull((convert(sysname, SERVERPROPERTY('INSTANCENAME'))), '<default>')
print 'Edition = ' + (convert(sysname, SERVERPROPERTY('edition')))
print 'Version = ' + (convert(sysname, SERVERPROPERTY('productversion')))
print 'Version Level = ' + @versNum + ' ' + (convert(sysname, SERVERPROPERTY('productlevel')))
print 'Collation = ' + (convert(sysname, SERVERPROPERTY('collation')))
if @bIsAzureSQLMI = 0
	print 'Is clustered = ' + (convert(sysname, SERVERPROPERTY('isclustered')))
print 'Is AlwaysOn Enabled = ' + isnull((convert(sysname, SERVERPROPERTY('IsHadrEnabled'))), 'N/A')
print 'VM Type = ' + isnull(@vmType, 'N/A')
print 'OS CPUs = ' +  @CPU
print 'Visible CPUs = ' + @visibleCPU
if @CPU <> @visibleCPU
	print '   *** OS CPU does NOT match CPUs visible by SQL Server ***'
print 'Physical Mem in GB = ' + isnull(@MemNum, 'N/A')
print 'SQL Max Mem in GB = ' +  convert(varchar(max), cast(@vSQLMaxMem/1024.0 as money), 1)

if ((convert(float, @MemNum)) < (convert(float, @vSQLMaxMem))/1024.0) and (@vSQLMaxMem <> 2147483647)
	print '   *** SQL max mem is GREATER THAN the total size of physical memory available to the OS ***'				

--=================================================================================================

--Total database count and their states
select count(*) as [# of DBs], state_desc from sys.databases
where source_database_id IS NULL
group by state_desc;


--=================================================================================================

--TOP 3 READ DBS
SELECT top 3 name AS 'Database Name'
      ,convert(varchar, cast(SUM(num_of_reads) as money), 1) AS 'Number of Reads', 'TOP 3 READ DBS'
FROM sys.dm_io_virtual_file_stats(NULL, NULL) I
  INNER JOIN sys.databases d  
      ON I.database_id = d.database_id
where d.source_database_id IS NULL
GROUP BY name 
ORDER BY SUM(num_of_reads) DESC;

--TOP 3 WRITES DBS
SELECT top 3 name AS 'Database Name'
      ,convert(varchar, cast(SUM(num_of_writes) as money), 1) AS 'Number of Writes', 'TOP 3 WRITE DBS' 
FROM sys.dm_io_virtual_file_stats(NULL, NULL) I
  INNER JOIN sys.databases d  
      ON I.database_id = d.database_id
where d.source_database_id IS NULL
GROUP BY name 
ORDER BY SUM(num_of_writes) DESC;

--TOP I/O
with     Agg_IO_Stats
as       (select   DB_NAME(database_id) as database_name,
				   cast (SUM(num_of_reads + num_of_writes) / 2. as decimal (20, 2)) as io_avg
          from     sys.dm_io_virtual_file_stats (null, null) as DM_IO_Stats
          group by database_id)
select   top 3 database_name,
		 convert (varchar, cast(io_avg as money), 1) as io_avg,
		 cast (io_avg / SUM(io_avg) over () * 100 as decimal (5, 2)) as pct,
		 'TOP 3 IO DBS'
from     Agg_IO_Stats
order by pct desc;


--TOP I/O by MBs
with     Agg_IO_Stats2
as       (select   DB_NAME(database_id) as database_name,
                   cast (SUM(num_of_bytes_read + num_of_bytes_written) / 1048576. as decimal (20, 2)) as io_in_mb
          from     sys.dm_io_virtual_file_stats (null, null) as DM_IO_Stats
          group by database_id)
select   top 3 database_name,
         convert(varchar, cast(io_in_mb as money), 1) as io_in_mb,
         cast (io_in_mb / SUM(io_in_mb) over () * 100 as decimal (5, 2)) as pct,
		 'TOP 3 IO-MBs'
from     Agg_IO_Stats2
order by pct desc;


--=================================================================================================

--alwaysOn
if CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)), 4) AS INT) > 10 -- >= 2012
begin
	if @bShowSettingsResults = 1
	begin
		SELECT db_name([database_id]) as DbName
			  , ag.name	as AG_Name
			  ,r.replica_server_name
			  ,[is_local]
			  ,[synchronization_state_desc]
			  ,[is_commit_participant]
			  ,[synchronization_health_desc]
			  ,[database_state_desc]
			  ,[is_suspended]
			  ,[suspend_reason_desc]
		  FROM [master].[sys].[dm_hadr_database_replica_states] ds
		  inner join sys.availability_groups ag
			on ds.group_id = ag.group_id
		  inner join sys.availability_replicas r
			on ds.replica_id = r.replica_id
		--where [synchronization_health_desc] <> 'Healthy'
			order by DbName, replica_server_name
	end
	
	if (select count(*) from master.sys.dm_hadr_availability_group_states) > 0
	--begin	--THIS WAS COMMENTED BEFORE
		if (select count(*) from master.sys.dm_hadr_availability_group_states where [synchronization_health_desc] <> 'Healthy') > 0
			print    '     *** AG sync state is NOT HEALTHY ***'
		--else	--THIS WAS COMMENTED BEFORE
			--print '       AG sync state verified'	--THIS WAS COMMENTED BEFORE
	--end	--THIS WAS COMMENTED BEFORE
	--else	--THIS WAS COMMENTED BEFORE
		--print '       Always On is not enabled'	--THIS WAS COMMENTED BEFORE
end
--else	--THIS WAS COMMENTED BEFORE
	--print '       Always On is not an available feature for this version of SQL Server'	--THIS WAS COMMENTED BEFORE

--=================================================================================================
--Start of Version Checks
print '
~~~~~~~~~~~~~ VERSION CHECKS ~~~~~~~~~~~~~'

--version check
set @fullVersion = (convert(sysname, SERVERPROPERTY('productversion')))	--this one is needed, do un-comment
set @supportedMsg = 'SQL version is or surpasses latest SP: ' + @fullVersion
set @obsoleteMsg = '  *** version is also Obsolete & Out of Support ***'
set @rtmMsg = '  *** SQL version is RTM and very likely not the latest CU ***'
set @buildVersion = CAST(PARSENAME(@fullVersion, 2) AS INT)

if @fullVersion like '8.%'
begin
	set @version = 80
	if @buildVersion >= 2039  -- 2000 SP4 (released 5/6/05)
		print @supportedMsg + @obsoleteMsg
	else
		print N'  *** SQL version is not the latest SP of 8.0.2039.0. ***' + @obsoleteMsg
end

else if @fullVersion like '9.%'	-- OBSOLOTE 
begin  
	set @version = 90
	if @buildVersion >= 5000  -- 2005 SP4 (released 12/17/10)
		print @supportedMsg + @obsoleteMsg
	else
		print N'  *** SQL version is not the latest SP of 9.00.5000.00 ***' + @obsoleteMsg
end

else if @fullVersion like '10.0%' or @fullVersion like '10.4%' -- OBSOLETE
begin
	set @version = 100
	if @buildVersion >= 6000  --2008 SP4 (released 9/30/14)
		print @supportedMsg + @obsoleteMsg
	else
		print N'  *** SQL version is not the latest SP of 10.0.6000.29 ***' + @obsoleteMsg
end

else if @fullVersion like '10.5%' -- OBSOLETE
begin
	set @version = 100
	if @buildVersion >= 6000  --2008 R2 SP3 (released 9/26/14)
		print @supportedMsg + @obsoleteMsg
	else
		print N'  *** SQL version is not the latest SP of 10.50.6000.34 ***' + @obsoleteMsg
end

else if @fullVersion like '11.%'
begin
	set @version = 110
	if @buildVersion >= 7001 --2012 SP4 (released 10/5/17)
		print @supportedMsg
	else
		print N'  *** SQL version is not the latest SP of 11.0.7001.0 ***'
end

else if @fullVersion like '12.%'
begin
	set @version = 120
	if @buildVersion >= 6024 --2014 SP3 (released 10/30/18)
		print @supportedMsg
	else
		print N'  *** SQL version is not the latest SP of 12.0.6024.0 ***' 
end

else if @fullVersion like '13.%'
begin
	set @version = 130
	if @buildVersion >= 5026 --2016 SP2 (released 4/24/18)
		print @supportedMsg
	else
		print N'  *** SQL version is not the latest SP of 13.0.5026.0 ***'
end

--SPs will no longer be released 2017+  --3/15/20 SGR
else if @fullVersion like '14.%'
begin
	set @version = 140
	if @buildVersion = 1000 --2017 RTM (released 10/2/17)
		print @rtmMsg
	else if @buildVersion > 1000
		print 'SQL version is at least not RTM - verify if latest CU; Rackspace-supported versions are usually at least 3 months old'
end
else if @fullVersion like '15.%'
begin
	set @version = 150
	if @buildVersion = 2000 --2019 RTM (released 11/19/19)
		print @rtmMsg
	else if @buildVersion > 2000
		print 'SQL version is at least not RTM - verify if latest CU; Rackspace-supported versions are usually at least 3 months old'
end



--determine if the SP/CU poses a risk for the instance
set @warnMsg = NULL
-- up to 2008 SP3 CU7 (10.0.5826.0)
if @fullVersion like '10.0.%'
	if CAST(PARSENAME(@fullVersion, 2) AS INT) >= 5828
		set @warnMsg = null
	else 
		set @warnMsg = '  *** Memory Leak when using AUTO_UPDATE_STATS_ASYNC - fix is available in 2008 SP3 CU8; however, please consider the latest SP/CU to avoid other issues ***'


-- up to 2008 R2 SP2 CU3 or 2008 R2 SP1 CU9  (10.50.2866.0 or 10.50.4266.0) 
if @fullVersion like '10.50.%'
	if CAST(PARSENAME(@fullVersion, 2) AS INT) >= 4270
		set @warnMsg = null
	else if CAST(PARSENAME(@fullVersion, 2) AS INT) >= 4000
	begin
		if CAST(PARSENAME(@fullVersion, 2) AS INT) < 4270
			set @warnMsg = '  *** Memory Leak when using AUTO_UPDATE_STATS_ASYNC - fix is available in 2008 R2 SP2 CU4; however, please consider the latest SP/CU to avoid other issues  ***'
	end
	else if CAST(PARSENAME(@fullVersion, 2) AS INT) >= 2868
		set @warnMsg = null
	else --if CAST(PARSENAME(@fullVersion, 2) AS INT) < 2868
		set @warnMsg = '  *** Memory Leak when using AUTO_UPDATE_STATS_ASYNC - fix is available in 2008 R2 SP1 CU10; however, please consider the latest SP/CU to avoid other issues  ***'


-- up to 2012 RTM CU4 (11.0.2383.0), 2012 SP1 (11.0.3000.0 or 11.1.3000.0), up to 2012 SP1 CU10 (11.0.3431), 2012 SP2 CU3 (11.0.5556.0), 2012 SP2 CU4 (11.0.5569.0)
if @fullVersion like '11.%'
	if CAST(PARSENAME(@fullVersion, 2) AS INT) = 5569 or CAST(PARSENAME(@fullVersion, 2) AS INT) = 5556
		set @warnMsg = '  *** AlwaysOn AG may be reported as NOT SYNCHRONIZING - fix is available in 2012 SP2 CU5; however, please consider the latest SP/CU to avoid other issues  ***'

	else if CAST(PARSENAME(@fullVersion, 2) AS INT) >= 5532 --> 5521
		set @warnMsg = null
	else if CAST(PARSENAME(@fullVersion, 2) AS INT) > 3436
		if CAST(PARSENAME(@fullVersion, 2) AS INT) < 5058
			set @warnMsg = null
		else	-- >= 5058
			set @warnMsg = '  *** Online index rebuilds in parallel can cause corruption - fix is available in 2012 SP2 CU1; however, please consider the latest SP/CU to avoid other issues  ***'
	else if CAST(PARSENAME(@fullVersion, 2) AS INT) < 3436	
		if @fullVersion like '11.0.3000.0' or @fullVersion like '11.1.3000.0'
			set @warnMsg = '  *** msiexec.exe process keeps running after installing SP1 causing 100% CPU - fix is available in 2012 SP1 CU2; however, please consider the latest SP/CU to avoid other issues ***
  *** Online index rebuilds in parallel can cause corruption - fix is available in 2012 SP1 CU11 or 2012 SP2 CU1; however, please consider the latest SP/CU to avoid other issues  ***'
		else if CAST(PARSENAME(@fullVersion, 2) AS INT) < 2384
			set @warnMsg = '  *** Memory Leak when using AUTO_UPDATE_STATS_ASYNC - fix is available in 2012 RTM CU5; however, please consider the latest SP/CU to avoid other issues  ***
  *** Online index rebuilds in parallel can cause corruption - fix is available in 2012 SP1 CU11 or 2012 SP2 CU1; however, please consider the latest SP/CU to avoid other issues  ***'
		else
			set @warnMsg = '  *** Online index rebuilds in parallel can cause corruption - fix is available in 2012 SP1 CU11 or 2012 SP2 CU1; however, please consider the latest SP/CU to avoid other issues  ***'


--up to 2014 RTM CU1 (12.0.2369), 2014 CU5 (12.0.2456.0)
if @fullVersion like '12.%'
	if CAST(PARSENAME(@fullVersion, 2) AS INT) = 2456
		set @warnMsg = '  *** AlwaysOn AG may be reported as NOT SYNCHRONIZING - fix is available in 2014 RTM CU6; however, please consider the latest SP/CU to avoid other issues  ***'
	else if CAST(PARSENAME(@fullVersion, 2) AS INT) > 2369
		set @warnMsg = null
	else	-- <= 2369
		set @warnMsg = '  *** Online index rebuilds in parallel can cause corruption - fix is available in 2014 RTM CU2; however, please consider the latest SP/CU to avoid other issues  ***'
			

-- up to 2016 SP1 CU9 or 2016 SP2 CU2 (13.0.4474.0 or 13.0.5149.0)
if @fullVersion like '13.%'
	if CAST(PARSENAME(@fullVersion, 2) AS INT) >= 5153 
		set @warnMsg = null
	else if CAST(PARSENAME(@fullVersion, 2) AS INT) >= 5026	--SP2
	begin
		if CAST(PARSENAME(@fullVersion, 2) AS INT) < 5153
			set @warnMsg = '  *** Backup compression on TDE-enabled dbs can produce corrupt backups - fix is available in 2016 SP2 CU2; however, please consider the latest SP/CU to avoid other issues  ***'	
	end
	else if CAST(PARSENAME(@fullVersion, 2) AS INT) >= 4502
		set @warnMsg = null
	else	--if CAST(PARSENAME(@fullVersion, 2) AS INT) < 4502
		set @warnMsg = '  *** Backup compression on TDE-enabled dbs can produce corrupt backups - fix is available in 2016 SP1 CU9; however, please consider the latest SP/CU to avoid other issues  ***'


-- up to 2017 RTM CU8 (14.0.3029.16)
if @fullVersion like '14.%'
	if CAST(PARSENAME(@fullVersion, 2) AS INT) > 3029
		set @warnMsg = NULL
	else 
		set @warnMsg = '  *** Backup compression on TDE-enabled dbs can produce corrupt backups - fix is available in 2017 RTM CU9; however, please consider the latest CU to avoid other issues  ***'

if @warnMsg is not null
	print @warnMsg


-- check for Meltdown and Spectre vulnerabilities
declare @SpecMeltPatched varchar(max)
declare @VersionLevel varchar(max)

--set @buildVersion = CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)), 2) AS INT)	--still needed, original code
set @SpecMeltPatched = 'Patch in place to address Spectre and Meltdown side-chainnel vulnerabilities: ' + @fullVersion
set @VersionLevel = @versNum + ' ' + (convert(sysname, SERVERPROPERTY('productlevel')))

if @fullVersion like '10.5%'	-- 2008 R2
begin
	if @buildVersion >= 6560
		print @SpecMeltPatched
	else  
		print N'  *** Security update needed for 2008 R2 SP3 (KB 4057113) to address Spectre and Meltdown vulnerabilities along with relevant OS patches, if not already done. ***'
end

else if @fullVersion like '10.%'	-- 2008
begin
	if @buildVersion >= 6556
		print @SpecMeltPatched
	else 
		print N'  *** Security update needed for 2008 SP4 (KB 4057114) to address Spectre and Meltdown vulnerabilities along with relevant OS patches, if not already done. ***'
end

else if @fullVersion like '11.%'	-- 2012
begin
	if @buildVersion >= 7462
		print @SpecMeltPatched
	else if @buildVersion > 6615
		print N'  *** Security update needed for 2012 SP4 (KB 4057116) to address Spectre and Meltdown vulnerabilities along with OS patches, if not already done. ***'
	else if @buildVersion = 6615
		print @SpecMeltPatched
	else if @buildVersion > 6260
		print N'  *** Security update needed for 2012 SP3 CU (KB 4057121) to address Spectre and Meltdown vulnerabilities along with OS patches, if not already done. ***'
	else if @buildVersion = 6260
		print @SpecMeltPatched
	else
		print N'  *** Security update for 2012 SP3 (KB 4057115) to address spectre and meltdown vulnerabilities along with OS patches, if not already done. ***' 
end

else if @fullVersion like '12.%'	-- 2014
begin
	if @buildVersion >= 5571
		print @SpecMeltPatched
	else if @buildVersion > 5214
		print N'  *** Security update needed for 2014 SP2 CU10 (KB 4057117) to address Spectre and Meltdown vulnerabilities along with OS patches, if not already done. ***'
	else if @buildVersion = 5214
		print @SpecMeltPatched
	else
		print N'  *** Security update needed for 2014 SP2 GDR (KB 4057120) to address Spectre and Meltdown vulnerabilities along with OS patches, if not already done. ***'
end

else if @fullVersion like '13.%'	-- 2016
begin
	if @buildVersion >= 4466
		print @SpecMeltPatched
	else if @buildVersion > 4210
		print N'  *** Security update needed for 2016 SP1 CU7 (KB 4057119) to address Spectre and Meltdown vulnerabilities along with OS patches, if not already done. ***'
	else if @buildVersion = 4210
		print @SpecMeltPatched
	else if @buildVersion > 2218
		print N'  *** Security update needed for 2016 SP1 GDR (KB 4057118) to address Spectre and Meltdown vulnerabilities along with OS patches, if not already done. ***'
	else if @buildVersion = 2218
		print @SpecMeltPatched
	else if @buildVersion > 1745
		print N'  *** Security update needed for 2016 RTM CU (KB 4058559) to address Spectre and Meltdown vulnerabilities along with OS patches, if not already done. ***'
	else if @buildVersion = 1745
		print @SpecMeltPatched
	else
		print N'  *** Security update needed for 2016 RTM GDR (KB 4058560) to address Spectre and Meltdown vulnerabilities along with OS patches, if not already done. ***'
end

else if @fullVersion like '14.%'	-- 2017
begin
	if @buildVersion >= 3015
		print @SpecMeltPatched
	else if @buildVersion > 2000
		print N'  *** Security update needed for 2017 RTM CU3 (KB 4058562) to address Spectre and Meltdown vulnerabilities along with OS patches, if not already done. ***'
	else if @buildVersion = 2000
		print @SpecMeltPatched
	else
		print N'  *** Security update needed for 2017 GDR (KB 4057122) to address Spectre and Meltdown vulnerabilities along with OS patches, if not already done. ***'
end

--End of Version Checks
print '~~~~~~~~~~ END OF VERSION CHECKS ~~~~~~~~~'

--=================================================================================================

print '

     !!!!! VERIFICATIONS !!!!!
  ----------------------------------------'

--config

if @bShowSettingsResults = 1
begin
	SELECT 'CONFIG SETTINGS', configuration_id, name, value, value_in_use, [description] 
	FROM sys.configurations
	where name in ('backup compression default'  -- >= 2k8
				,'clr enabled' 
				,'max degree of parallelism', 'cost threshold for parallelism'
				,'min server memory (MB)', 'max server memory (MB)'
				,'max full-text crawl range'
				,'priority boost'
				,'optimize for ad hoc workloads'  -->2k8
				,'remote admin connections') 
	ORDER BY name OPTION (RECOMPILE);

	select FULLTEXTSERVICEPROPERTY('isfulltextinstalled') as [Is_Full-Text_Installed]
end

--select @maxMem = convert(varchar(max), value_in_use) from sys.configurations where name = 'max server memory (MB)'
select @minMem = convert(varchar(max), value_in_use) from sys.configurations where name = 'min server memory (MB)'
select @maxDop = value_in_use from sys.configurations where name = 'max degree of parallelism'
select @maxCrawl = value_in_use from sys.configurations where name = 'max full-text crawl range'
select @costThresh = value_in_use from sys.configurations where name = 'cost threshold for parallelism'
select @fullTextInstalled = FULLTEXTSERVICEPROPERTY('isfulltextinstalled')

if
(select COUNT(*) from sys.configurations where name = 'max server memory (MB)' and value = 2147483647) > 0
	print '     *** max server memory is NOT SET ***'
ELSE
	print '       max server memory is set to ' + convert(varchar(max), cast(@vSQLMaxMem/1024.00 as money), 1) + ' GB - Sufficient?'								          
if
(select COUNT(*) from sys.configurations where name = 'min server memory (MB)' and value = 0) > 0
	print    '     *** min server memory is NOT SET ***'
ELSE
	print '       min server memory is set to ' + convert(varchar(max), cast(@minMem/1024.00 as money), 1) + ' GB - Sufficient?'

if
(select COUNT(*) from sys.configurations where name = 'backup compression default' and value_in_use = 0) > 0
	print '     *** backup compression is NOT ENABLED ***'
ELSE if (select COUNT(*) from sys.configurations where name = 'backup compression default' and value_in_use = 1) > 0
	print '       backup compression is enabled; verify that backup compression is not being used on ENCRYPTED databases unless at least 2016 SP1 CU9, 2016 SP2 CU2, or 2017 RTM CU9 - best practice'
else
	print '       backup compression is not an available feature for this version and/or edition of SQL Server'

if
(select COUNT(*) from sys.configurations where name = 'optimize for ad hoc workloads' and value_in_use = 0) > 0
	print '     *** optimize for ad hoc workloads IS NOT ENABLED ***'
ELSE if (select COUNT(*) from sys.configurations where name = 'optimize for ad hoc workloads' and value_in_use = 1) > 0
	print '       optimize for ad hoc workloads is enabled - best practice'
else
	print '       optimize for ad hoc workloads is not an available feature for this version of SQL Server'

if
(select COUNT(*) from sys.configurations where name = 'clr enabled' and value_in_use = 1) > 0
	print '     *** clr IS ENABLED ***'
ELSE
	print '       clr is not enabled - best practice'	

if
(select COUNT(*) from sys.configurations where name = 'remote admin connections' and value_in_use = 1) > 0
	print '     *** remote admin connections IS ENABLED ***'
ELSE
	print '       remote admin connections is not enabled - best practice'	

if
(select COUNT(*) from sys.configurations where name = 'priority boost' and value_in_use = 1) > 0
	print '     *** priority boost IS ENABLED ***'
else
	print '       priority boost is not enabled - best practice'

if
(select COUNT(*) from sys.configurations where name = 'max degree of parallelism' and value_in_use = 1) > 0
	print '     *** maxdop IS DISABLED ***'
else if
	(select COUNT(*) from sys.configurations where name = 'max degree of parallelism' and value_in_use = 0) > 0
		print '       maxdop is enabled and set to default of 0'
	ELSE
		print '     *** maxdop is enabled and set to ' + convert(nvarchar(5), @maxDop) + ' - NOT DEFAULT ***'

if
(select COUNT(*) from sys.configurations where name = 'cost threshold for parallelism' and value_in_use = 5) > 0
	print '     *** cost threshold for parallelism is set to default of 5 - BUT SHOULD BE ADJUSTED AS THIS IS TOO LOW ***'
else if @costThresh < 25
	print '     *** cost threshold for parallelism is set to ' + convert(nvarchar(5), @costThresh) + ' - Too Low? ***'
else
	print '       cost threshold for parallelism is set to ' + convert(nvarchar(5), @costThresh) + ' - Sufficient?'

if @fullTextInstalled = 1
begin
	if
	(select COUNT(*) from sys.configurations where name = 'max full-text crawl range' and value_in_use = 4) > 0
		print '       max full-text crawl range is set to default of 4'
	ELSE
		print '     *** max full-text crawl range is set to ' + convert(nvarchar(3), @maxCrawl) + ' - NOT DEFAULT ***'
end
else 
	print '       max full-text crawl range option can be ingored -- FULL-TEXT IS NOT INSTALLED'





--=================================================================================================
--version and settings
if @bShowSettingsResults = 1
begin
	select 'DB SETTINGS', db.[name] as [Database Name],
       db.recovery_model_desc as [Recovery Model],
       db.log_reuse_wait_desc as [Log Reuse Wait Description],
	   db.is_encrypted,
	   db.compatibility_level,
	   [DB Compatibility Level] = 
	   case   db.[compatibility_level] 
	      when 80 then 2000
		  when 90 then 2005
		  when 100 then 2008
		  when 105 then '2008R2' --designation but not an actual value; 105 is not an actual value so this will never come up
		  when 110 then 2012
		  when 120 then 2014
		  when 130 then 2016 	
		  when 140 then 2017
		  when 150 then 2019
		  else db.[compatibility_level]	
	   end,
       db.page_verify_option_desc as [Page Verify Option],
	   db.is_encrypted,
       db.is_auto_close_on,
       db.is_auto_shrink_on,
       db.is_auto_create_stats_on,
       db.is_auto_update_stats_on,
       db.is_auto_update_stats_async_on,
       db.is_parameterization_forced,
       db.snapshot_isolation_state_desc,
       db.is_read_committed_snapshot_on
from   sys.databases as db
where source_database_id IS NULL
order by name
option (recompile);
end


----------------------------------------------------------------------------------------------


--settings
if
(select COUNT(*) from sys.databases where is_encrypted = 1 and source_database_id IS NULL) > 0
	begin
		set @count = (select COUNT(*) from sys.databases where is_encrypted = 1 and source_database_id IS NULL)   
		print N'     *** Encryption is enabled on ' + cast(@count as varchar(5)) + ' database(s); verify that BACKUP COMPRESSION is not being used for these databases unless at least 2016 SP1 CU9, 2016 SP2 CU2, or 2017 RTM CU9 - AND -  ***'
	end
else
	print '       Encryption verified'

if
(select COUNT(*) from sys.databases where compatibility_level < @version and source_database_id IS NULL) > 0
	begin
		set @count = (select COUNT(*) from sys.databases where compatibility_level < @version and source_database_id IS NULL)
		print N'     *** Compatibility level does not match instance version on ' + cast(@count as varchar(5)) + ' database(s) ***'
	end
else
	print '       Compatibility level verified'

if
(select COUNT(*) from sys.databases where page_verify_option_desc not in ('CHECKSUM') and source_database_id IS NULL) > 0
	begin
		set @count = (select COUNT(*) from sys.databases where page_verify_option_desc not in ('CHECKSUM') and source_database_id IS NULL)
		print N'     *** Page verify option not set to CHECKSUM on ' + cast(@count as varchar(5)) + ' database(s) ***'
	end
else
	print '       Page verify option verified'

if
(select COUNT(*) from sys.databases where is_auto_close_on = 1 and source_database_id IS NULL) > 0
	begin
		set @count = (select COUNT(*) from sys.databases where is_auto_close_on = 1 and source_database_id IS NULL)
		print N'     *** Auto Close is enabled on ' + cast(@count as varchar(5)) + ' database(s) ***'
	end
else
	print '       Auto Close verified'

if
(select COUNT(*) from sys.databases where is_auto_shrink_on = 1 and source_database_id IS NULL) > 0
	begin
		set @count = (select COUNT(*) from sys.databases where is_auto_shrink_on = 1 and source_database_id IS NULL)
		print N'     *** Auto Shrink is enabled on ' + cast(@count as varchar(5)) + ' database(s) ***'
	end
else
	print '       Auto Shrink verified'

if
(select COUNT(*) from sys.databases where is_auto_update_stats_on = 0 and source_database_id IS NULL) > 0
	begin
		set @count = (select COUNT(*) from sys.databases where is_auto_update_stats_on = 0 and source_database_id IS NULL)
		print N'     *** Auto Update Stats is NOT ENABLED on ' + cast(@count as varchar(5)) + ' database(s) ***'
	end
else
	print '       Auto Update Stats verified'




--=================================================================================================
--owner of objects
if @bShowSettingsResults = 1 and @bIsAmazonRDS = 0 and @bIsAzureSQLDB = 0
begin
	--databases
	select 'DB OWNERS', name as DBOwner, suser_sname(owner_sid) as db_owner 
		from sys.databases
		where (suser_sname(owner_sid) is null
		or suser_sname(owner_sid) not in ('sa'))
		and source_database_id IS NULL

	--jobs
	select 'JOB OWNER', name as JobName, enabled, suser_sname(owner_sid) as JobOwner
		from msdb.dbo.sysjobs
		where SUSER_SNAME(owner_sid) not in ('sa')

	--pkgs/maintenance plans
	if (convert(sysname, SERVERPROPERTY ('productversion'))) like '9%'
		begin
		/*********** 2005 ***********/
		--Maintenance plan/package
			SELECT 'PKG OWNERS', name as PkgName, description, suser_sname(ownersid) as PkgOwner
			FROM msdb.dbo.sysdtspackages90			-- 2005
			WHERE suser_sname(ownersid) not in ('sa')
		
		end
	else
		begin
			/*********** 2008 and above ***********/
		--Maintenace plan/package
			SELECT 'PKG OWNERS', name as PkgName, suser_sname(ownersid) as PkgOwner
			FROM msdb.dbo.sysssispackages	
			WHERE SUSER_SNAME(ownersid) not in ('sa')
		end
end

----------------------------------
if @bIsAmazonRDS = 0 and @bIsAzureSQLDB = 0
begin
	declare @sCount smallint;

	set @sCount = 0
	--databases
	if (select count(*)  
		from sys.databases
		where (suser_sname(owner_sid) is null
		or suser_sname(owner_sid) not in ('sa')) and source_database_id IS NULL) > 0
	begin
		set @sCount = (select count(*)  
						from sys.databases
						where (suser_sname(owner_sid) is null
						or suser_sname(owner_sid) not in ('sa')) and source_database_id IS NULL)
		print N'     *** Owner not set to ''sa'' on ' + cast(@sCount as varchar(5)) + ' database(s) ***'
	end
	else
		print '       DB Owners verified'


	set @sCount = 0
	--jobs
	if (select count(*)
		from msdb.dbo.sysjobs
		where SUSER_SNAME(owner_sid) not in ('sa')) > 0
	begin
		set @sCount = (select count(*)
						from msdb.dbo.sysjobs
						where SUSER_SNAME(owner_sid) not in ('sa'))
		print N'     *** Owner not set to ''sa'' on ' + cast(@sCount as varchar(5)) + ' job(s) ***'
	end
	else
		print '       Job Owners verified'

	set @sCount = 0
	--pkgs/maintenance plans
	if (convert(sysname, SERVERPROPERTY ('productversion'))) like '9%'
		begin
		-- 2005 Maintenance plan/package
			if (select count(*)
				FROM msdb.dbo.sysdtspackages90			-- 2005
				WHERE suser_sname(ownersid) not in ('sa')) > 0
			begin
				set @sCount = (select count(*)
								FROM msdb.dbo.sysdtspackages90			-- 2005
								WHERE suser_sname(ownersid) not in ('sa'))
				print N'     *** Owner not set to ''sa'' on ' + cast(@sCount as varchar(5)) + ' package(s) ***'
 			end
			else
				print '       Package Owners verified'
		end
	else
		begin
		--2008 and above Maintenace plan/package
			if (select count(*)
				FROM msdb.dbo.sysssispackages			-- 2005
				WHERE suser_sname(ownersid) not in ('sa')) > 0
			begin
				set @sCount = (select count(*)
								FROM msdb.dbo.sysssispackages		-- 2005
								WHERE suser_sname(ownersid) not in ('sa'))
				print N'     *** Owner not set to ''sa'' on ' + cast(@sCount as varchar(5)) + ' package(s) ***'
 			end
			else
				print '       Package Owners verified'
		end
end

--=================================================================================================
--growth rates
declare @countFil smallint;
if @bShowSettingsResults = 1
begin
	SELECT 'DB GROWTH', DB_NAME([database_id])AS [Database Name], /*[file_id],*/ 
	--name, 
	physical_name,
					  'Type'=     case TYPE_DESC          
					  when 'ROWS' then 'Data'                         
					  when 'log' then 'Log'  
					  ELSE type_desc                         
					  end,                          
	cast(cast(size as float) / 128 as decimal(18, 2)) AS [Total *INITIAL* MB],                           
					  'Growth Increment'= CASE                            
					  WHEN IS_PERCENT_GROWTH = 1 THEN STR(GROWTH) + '  %'                            
					  ELSE STR((GROWTH * 8) / 1024)+ ' mb'                        
					  end, 
	--growth, max_size, 
	"MaxSize" = 
		case 
			when max_size = 0 or growth = 0 then '*** No growth allowed ***' 
			when max_size = -1 and growth > 0 then 'File will grow until disk full' --unlimited
			when max_size = 268435456 and growth > 0 then 'File will grow to max size of 2TB' --might as well be unlimited
			when max_size > 0 and growth > 0 then '*** File growth limited to fixed size ***' 
			end ,          
	state_desc As [StateDesc]
	FROM sys.master_files
	ORDER BY DB_NAME([database_id]) OPTION (RECOMPILE);
end

if 
(select count(*) from sys.master_files where (max_size = 0 or growth = 0)) > 0
	begin
		set @countFil = (select COUNT(*) from sys.master_files where (max_size = 0 or growth = 0))
		print N'     *** No growth allowed on ' + cast(@countFil as varchar(5)) + ' file(s) ***'
	end

else if 
(select count(*) from sys.master_files where (max_size > 0 and max_size < 268435456 and growth > 0)) > 0
	begin
		set @countFil = (select COUNT(*) from sys.master_files where (max_size > 0 and max_size < 268435456 and growth > 0))
		print N'     *** File growth limited to fixed size on ' + cast(@countFil as varchar(5)) + ' file(s) ***'
	end

else
	print '       Max file size verified'

if
(select COUNT(*) from sys.master_files where (GROWTH * 8 / 1024 = 1 and is_percent_growth = 0)) > 0
	begin
		set @countFil = (select COUNT(*) from sys.master_files where (GROWTH * 8 / 1024 = 1 and is_percent_growth = 0))
		print N'     *** Growth increment set to 1MB on ' + cast(@countFil as varchar(5)) + ' file(s) ***'
	end
else
	print '       File growth verified'
	 
--=================================================================================================
-- tempdb
if @bShowSettingsResults = 1
begin
	SELECT 'TEMPDB SETTINGS', DB_NAME([database_id])AS [Database Name], /*[file_id], name,*/ physical_name,
					  'Type'=     case TYPE_DESC          
					  when 'ROWS' then 'Data'                         
					  when 'log' then 'Log'                           
					  end,                          
	cast(cast(size as float) / 128 as decimal(18, 2)) AS [Total *INITIAL* MB],   
	--is_percent_growth, growth,                        
					  'Growth'= CASE                            
					  WHEN IS_PERCENT_GROWTH = 1 THEN STR(GROWTH) + '  %'                            
					  ELSE STR((GROWTH * 8) / 1024)+ ' mb'                        
					  end,
	state_desc As [StateDesc]
	FROM sys.master_files
	WHERE database_id = 2
end

if
(select COUNT(*) from sys.master_files where database_id = 2) = 2
		print '     *** Only 1 tempdb data file set ***'
else
begin
	set @countFil = (select COUNT(*) from sys.master_files where database_id = 2 and type = 0)
	print '       tempdb DATA file count = ' + cast(@countFil as varchar(5))
end


--initial size of multiple files not the same && growth rate of multiple files not the same
declare @firstdbname sysname, @firstType tinyint, @firstInitSize int, @firstGrowth int;
declare @dbname sysname, @type tinyint, @initialSize int, @growthIncr int;
declare @fail1 bit, @fail2 bit;

declare @tdbSizeCursor as CURSOR;

set @fail1 = 0;
set @fail2 = 0;

set @tdbSizeCursor = cursor for
select DB_NAME([database_id])AS [Database Name], type, size, growth
	from sys.master_files
	where database_id = 2;

open @tdbSizeCursor;

fetch next from @tdbSizeCursor into 
	@firstdbname, @firstType, @firstInitSize, @firstGrowth

while @@fetch_status = 0
begin
	fetch next from @tdbSizeCursor into
		@dbname, @type, @initialSize, @growthIncr
		if @fail1 = 0
		begin
			if @firstInitSize <> @initialSize and @firstType = @type
			begin
				print '     *** Tempdb initial file size not the same ***'
				set @fail1 = 1
			end
		end
		if @fail2 = 0
		begin
			if @firstGrowth <> @growthIncr and @firstType = @type
			begin 
				print '     *** Tempdb growth increments not the same ***'
				set @fail2 = 1
			end
		end
end
if @fail1 = 0
	print '       Tempdb initial file size verified'
if @fail2 = 0
	print '       Tempdb growth increments verified'

close @tdbSizeCursor
deallocate @tdbSizeCursor

--=================================================================================================

--trace flag checks
CREATE TABLE #FlagStatus (
        TrFlag           VARCHAR(5)
        , Stat             bit
		, Glob		bit
		, Sess		bit
    )   

INSERT INTO #FlagStatus EXECUTE ('DBCC TRACESTATUS(1117, -1) with no_infomsgs')
INSERT INTO #FlagStatus EXECUTE ('DBCC TRACESTATUS(1118, -1) with no_infomsgs')
INSERT INTO #FlagStatus EXECUTE ('DBCC TRACESTATUS(3226, -1) with no_infomsgs')
INSERT INTO #FlagStatus EXECUTE ('DBCC TRACESTATUS(2371, -1) with no_infomsgs')

-- 1117/1118 (tempdb) check not necessary if SQL Server version is >= 2016
if CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)), 4) AS INT) >= 13 -- >= 2016
	print '       Trace flag 1117 & 1118 check not necessary due to version of SQL Server'
else
begin
	if (select count(*) from #FlagStatus where TrFlag = '1117' and Glob = 1) > 0
	begin
		print '       Trace flag 1117 is enabled globally'
	end
	else
	begin
		print '     *** Trace flag 1117 is NOT ENABLED globally ***'
	end

	if (select count(*) from #FlagStatus where TrFlag = '1118' and Glob = 1) > 0
	begin
		print '       Trace flag 1118 is enabled globally'
	end
	else
	begin
		print '     *** Trace flag 1118 is NOT ENABLED globally ***'
	end
end

-- 3226 (successful backup logging) check for all versions
if (select count(*) from #FlagStatus where TrFlag = '3226' and Glob = 1) > 0
begin
	print '       Trace flag 3226 is enabled globally'
end
else
begin
	print '     *** Trace flag 3226 is NOT ENABLED globally ***'
end

-- 2371 (update stats threshold) check only for < 2016 and compatibility level < 130
if CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)), 4) AS INT) >= 13 -- >= 2016
begin
	if
	(select COUNT(*) from sys.databases where compatibility_level < 130 and source_database_id IS NULL) = 0
		begin
			print '       Trace flag 2371 check not necessary due to version of SQL Server and compatibility level of databases'
		end
	
	else
	begin
		if (select count(*) from #FlagStatus where TrFlag = '2371' and Glob = 1) > 0
		begin
			print '       Trace flag 2371 is enabled globally - at least one database is not at compatibiltiy level 130'
		end
		else
		begin
			print '     *** Trace flag 2371 is NOT ENABLED globally - at least one database is below compatibility level 130 ***'
		end
	end
end
else	-- < 2016
begin
	if (select count(*) from #FlagStatus where TrFlag = '2371' and Glob = 1) > 0
	begin
		print '       Trace flag 2371 is enabled globally'
	end
	else
	begin
		print '     *** Trace flag 2371 is NOT ENABLED globally ***'
	end
end

drop table #FlagStatus;

--=================================================================================================
--lock pages in memory & instant file initialization checks
if CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)), 4) AS INT) > 13	-- >2016	--1/27/19 SGR
or 
   (CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)), 4) AS INT) = 13 and		-- =2016 	--1/27/19 SGR
	CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)), 2) AS INT) >= 4001)		-- >=SP1
begin
	create table #v2k16sp1stage1 (
		svcName sysname,
		insta_file_init_enabled char(1)
	);
	create table #v2k16sp1stage2 (
		sql_mem_mod tinyint,
		sql_mem_mod_desc sysname
	);
		
	insert into #v2k16sp1stage1
	exec sp_executesql N'insert into #v2k16sp1stage1
	select servicename, instant_file_initialization_enabled
			FROM sys.dm_server_services 
			where instant_file_initialization_enabled is not null;'

	insert into #v2k16sp1stage2
	exec sp_executesql N'select sql_memory_model, sql_memory_model_desc
			FROM sys.dm_os_sys_info;'
		
	if @bShowSettingsResults = 1	
	begin
		SELECT 'INSTANT FILE INITIALIZATION', svcName, insta_file_init_enabled
			FROM #v2k16sp1stage1;

		SELECT 'LOCK PAGES IN MEM', sql_mem_mod, sql_mem_mod_desc
			FROM #v2k16sp1stage2;
	end
	if (select insta_file_init_enabled from #v2k16sp1stage1 where svcName like 'SQL Server (%') = 'Y'	--SGR 1/20/2019
		print '       Instant file initialization is enabled for the service account'
	else
		print '     *** Instant file initialization is NOT ENABLED for the service account ***'

	if (SELECT sql_mem_mod from #v2k16sp1stage2) = 2
		print '       Lock pages in memory is enabled for the service account'
	else
		print '     *** Lock pages in memory is NOT ENABLED for the service account ***'
		
	drop table #v2k16sp1stage1;
	drop table #v2k16sp1stage2;
end
else if CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)), 4) AS INT) = 11	  -- =2012	--1/20/19 SGR
	and CAST(PARSENAME(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(128)), 2) AS INT) >= 7001	-- >=SP4
begin
	create table #v2k12sp4stage1 (
		svcName sysname,
		insta_file_init_enabled char(1)
	);
	create table #v2k12sp4stage2 (
		sql_mem_mod tinyint,
		sql_mem_mod_desc sysname
	);
		
	insert into #v2k12sp4stage1
	exec sp_executesql N'insert into #v2k12sp4stage1
	select servicename, instant_file_initialization_enabled
			FROM sys.dm_server_services 
			where instant_file_initialization_enabled is not null;'

	insert into #v2k12sp4stage2
	exec sp_executesql N'select sql_memory_model, sql_memory_model_desc
			FROM sys.dm_os_sys_info;'
		
	if @bShowSettingsResults = 1	
	begin
		SELECT 'INSTANT FILE INITIALIZATION', svcName, insta_file_init_enabled
			FROM #v2k12sp4stage1;

		SELECT 'LOCK PAGES IN MEM', sql_mem_mod, sql_mem_mod_desc
			FROM #v2k12sp4stage2;
	end
	if (select insta_file_init_enabled from #v2k12sp4stage1 where svcName like 'SQL Server (%') = 'Y'	--SGR 1/20/2019
		print '       Instant file initialization is enabled for the service account'
	else
		print '     *** Instant file initialization is NOT ENABLED for the service account ***'

	if (SELECT sql_mem_mod from #v2k12sp4stage2) = 2
		print '       Lock pages in memory is enabled for the service account'
	else
		print '     *** Lock pages in memory is NOT ENABLED for the service account ***'
		
	drop table #v2k12sp4stage1;
	drop table #v2k12sp4stage2;
end
else
begin
	print '       Lock pages in mem not verifiable via DMVs - NEED TO CHECK OS'
	print '       Instant file initialization not verifiable via DMVs - NEED TO CHECK OS'	
end


--=================================================================================================
--msdb too large
if @bIsAzureSQLDB = 0
begin
	if (select COUNT(*) from msdb.sys.database_files where (size*8)/1024 > 2048) > 0  -- 2048 is 2GB
		begin
			print N'     *** msdb has at least one file greater than 2GB ***'
		end
	else
		begin
			print '       msdb size verified'
		end
end

--=================================================================================================
--VLF count
--declare @sCount smallint;
DECLARE @MajorVersion smallint ; 
SELECT  @MajorVersion = CAST(substring(CAST(SERVERPROPERTY('productversion') AS VARCHAR), 0, 
						Charindex('.', CAST(SERVERPROPERTY('productversion') AS VARCHAR))) AS smallint); 

if @bIsAmazonRDS = 0
begin
	if @MajorVersion > 10
	begin
		create Table #vstage (
			RecoveryUnitID int
		  , FileID      int
		  , FileSize    bigint
		  , StartOffset bigint
		  , FSeqNo      bigint
		  , [Status]    bigint
		  , Parity      bigint
		  , CreateLSN   numeric(38)
		)

		Create Table #vresults(
			Database_Name   sysname
		  , VLF_count       int 
		);
 
		Exec sp_MSforeachdb N'Use [?]; 
					Insert Into #vstage 
					Exec sp_executesql N''DBCC LogInfo([?]) with no_infomsgs''; 
 
					Insert Into #vresults 
					Select DB_Name(), Count(*) 
					From #vstage; 
 
					Truncate Table #vstage;'
		if @bShowSettingsResults = 1
		begin
			Select 'VLF COUNTS', * 
			From #vresults
			Order By VLF_count Desc;
		end

		if (select count(*) from #vresults where VLF_count > 500) > 0
			begin
				set @sCount = (select count(*) from #vresults where VLF_count > 500) 
				print N'     *** VLF count is greater than 500 on ' + cast (@sCount as varchar(5)) + ' log file(s) ***'	
			end
		else
			begin
				print '       VLF count verified'
			end

		Drop Table #vstage;
		Drop Table #vresults;
	end
	else
	begin
		create Table #vstage2(
			FileID      int
		  , FileSize    bigint
		  , StartOffset bigint
		  , FSeqNo      bigint
		  , [Status]    bigint
		  , Parity      bigint
		  , CreateLSN   numeric(38)
		)
		Create Table #vresults2(
			Database_Name   sysname
		  , VLF_count       int 
		);
 
		Exec sp_msforeachdb N'Use [?]; 
					Insert Into #vstage2 
					Exec sp_executesql N''DBCC LogInfo([?]) with no_infomsgs''; 
 
					Insert Into #vresults2
					Select DB_Name(), Count(*) 
					From #vstage2; 
 
					Truncate Table #vstage2;'
		if @bShowSettingsResults = 1
		begin
			Select 'VLF COUNTS', * 
			From #vresults2
			Order By VLF_count Desc;
		end

		if (select count(*) from #vresults2 where VLF_count > 500) > 0
			begin
				set @sCount = (select count(*) from #vresults2 where VLF_count > 500) 
				print N'     *** VLF count is greater than 500 on ' + cast (@sCount as varchar(5)) + ' log file(s) ***'	
			end
		else
			begin
				print '       VLF count verified'
			end

		Drop Table #vstage2;
		Drop Table #vresults2;
	end
end
--=================================================================================================
------------------- RECOVERY MODELS AND LOG BACKUPS
if @bShowSettingsResults = 1
begin
	--RECOVERY MODELS
	select 'RECOVERY MODELS', name as [DB Name], recovery_model_desc as [RecoveryModel]
	from sys.databases
	where source_database_id IS NULL
	order by name	
end

--this might need an if statement
set @sCount = (select count(*) from sys.databases where recovery_model_desc = 'full' and source_database_id IS NULL) 
Print N'       ' + cast (@sCount as varchar(5)) + ' database(s) using the FULL recovery model'	
	
--======================================================


--FULL RECOVERY WITH NO LOG BACKUPS
if @bIsAzureSQLDB = 0
begin
	if
	(select COUNT(*)
	FROM master.sys.databases d
	LEFT OUTER JOIN msdb.dbo.backupset b 
		ON d.name = b.database_name 
			AND b.type = 'L'		-- L ==> Tlog
	WHERE (d.database_id NOT IN (2, 3) and d.recovery_model IN (1, 2))
	and (b.recovery_model is null or b.backup_finish_date is null) and d.source_database_id IS NULL) > 0
		begin 
			set @sCount = (select COUNT(*)
							FROM master.sys.databases d
							LEFT OUTER JOIN msdb.dbo.backupset b 
								ON d.name = b.database_name 
									AND b.type = 'L'		-- L ==> Tlog
							WHERE (d.database_id NOT IN (2, 3) and d.recovery_model IN (1, 2))
							and (b.recovery_model is null or b.backup_finish_date is null) and d.source_database_id IS NULL)
			print N'     *** No LOG backup taken on ' + cast(@sCount as varchar(5)) + ' database(s) ***'
		end
end

--======================================================
--FULL RECOVERY WITH LOG BACKUPS OLDER THAN 1 DAY
create table #old (
	name sysname,
	last_log_bu datetime,
	age_day int
);

insert into #old
	SELECT  d.name
		,max(b.backup_finish_date) AS last_TLOG_backup_finish_date
		, datediff(d, max(b.backup_finish_date), getdate()) as days
	FROM master.sys.databases d
	LEFT OUTER JOIN msdb.dbo.backupset b 
		ON d.name = b.database_name 
			AND b.type = 'L'		-- L ==> Tlog
	WHERE (d.database_id NOT IN (2, 3)		-- 2 = tempdb; 3 = model
		and d.recovery_model IN (1, 2))		-- 1 = Full; 2 = Bulk-logged; 3 = Simple
		and d.source_database_id IS NULL
	GROUP BY d.name
	having datediff(d, max(b.backup_finish_date), getdate()) > 1

if @bShowSettingsResults = 1
begin
	--LOG BACKUPS
	select 'LOG BACKUPS', * from #old
end

set @sCount = 0;
if (select count (*) from #old) > 0
	begin 
		set @sCount = (select count(*) from #old)
		print N'     *** Most recent LOG backup on ' + cast(@sCount as varchar(5)) + ' database(s) is older than 1 day ***'
	end
drop table #old

--======================================================
--NO FULL BACKUPS
if @bShowSettingsResults = 1
begin
	--SELECT 'FULL BACKUPS'
	SELECT 'FULL BACKUPS', d.name
		,MAX(b.backup_finish_date) AS Last_full_bu
	FROM master.sys.databases d
	LEFT OUTER JOIN msdb.dbo.backupset b 
		ON d.name = b.database_name 
			AND b.type = 'D'	
	WHERE (d.database_id NOT IN (2, 3))-- and  b.backup_finish_date is null)
	and d.source_database_id IS NULL
	group by d.name
end

set @sCount = 0;
if (SELECT count(*)
FROM master.sys.databases d
LEFT OUTER JOIN msdb.dbo.backupset b 
	ON d.name = b.database_name 
		AND b.type = 'D'	
WHERE d.database_id NOT IN (2, 3) and b.backup_finish_date is null and d.source_database_id IS NULL) > 0
	begin
		set @sCount = (SELECT count(*)
						FROM master.sys.databases d
						LEFT OUTER JOIN msdb.dbo.backupset b 
							ON d.name = b.database_name 
								AND b.type = 'D'	
						WHERE d.database_id NOT IN (2, 3) and b.backup_finish_date is null and d.source_database_id IS NULL)
		print N'     *** No FULL backup taken on ' + cast(@sCount as varchar(5)) + ' database(s) ***'
	end


--=================================================================================================



--THIS ONLY WORKS IF THE DEFAULT TRACE FILE DOES NOT HAVE A FUNKY FILE NAME!!!
--find autogrowth events
--SELECT 'AUTOGROWTH EVENTS'
DECLARE @filename NVARCHAR(1000);
DECLARE @bc INT;
DECLARE @ec INT;
DECLARE @bfn VARCHAR(1000);
DECLARE @efn VARCHAR(10);

-- Get the name of the current default trace
SELECT @filename = CAST(value AS NVARCHAR(1000))
FROM ::fn_trace_getinfo(DEFAULT)
WHERE traceid = 1 AND property = 2;

-- rip apart file name into pieces
SET @filename = REVERSE(@filename);
SET @bc = CHARINDEX('.',@filename);
SET @ec = CHARINDEX('_',@filename)+1;
SET @efn = REVERSE(SUBSTRING(@filename,1,@bc));
SET @bfn = REVERSE(SUBSTRING(@filename,@ec,LEN(@filename)));

-- set filename without rollover number
SET @filename = @bfn + @efn	

SELECT 'DEFAULT TRACE', 
  min(ftg.StartTime) MinDate, max(ftg.starttime) as MaxDate,
  @filename as DefaultTrace_Filename
FROM ::fn_trace_gettable(@filename, DEFAULT) AS ftg
INNER JOIN sys.trace_events AS te ON ftg.EventClass = te.trace_event_id  

-- process all trace files
SELECT 'AUTOGROWTH EVENTS',
  ftg.StartTime
,ftg.EndTime
,ftg.TextData
,te.name AS EventName
,DB_NAME(ftg.databaseid) AS DatabaseName  
,ftg.Filename
,(ftg.IntegerData*8)/1024.0 AS GrowthMB
,(ftg.duration/1000)AS DurMS
FROM ::fn_trace_gettable(@filename, DEFAULT) AS ftg
INNER JOIN sys.trace_events AS te ON ftg.EventClass = te.trace_event_id  
WHERE 1=1
   and (
		ftg.EventClass = 92	-- Date File Auto-grow
		or ftg.EventClass = 94	-- Data File Auto-shrink
		or ftg.EventClass = 93  -- Log File Auto-grow
		or ftg.EventClass = 95	-- Log File Auto-shrink
		)
ORDER BY ftg.StartTime






--=================================================================================================
--integrity
------------------- INTEGRITY
if @bIsAmazonRDS = 0
begin
	CREATE TABLE #temp (          
		   ParentObject     VARCHAR(255)
		   , [Object]       VARCHAR(255)
		   , Field          VARCHAR(255)
		   , [Value]        VARCHAR(255)   
	   )   
   
	CREATE TABLE #DBCCResults (
			ServerName           VARCHAR(255)
			, DBName             VARCHAR(255)
			, LastCleanDBCCDate  DATETIME   
		)   
    
	EXEC master.dbo.sp_MSforeachdb       
			   @command1 = 'USE [?] INSERT INTO #temp EXECUTE (''DBCC DBINFO WITH TABLERESULTS, no_infomsgs'')'
			   , @command2 = 'INSERT INTO #DBCCResults SELECT @@SERVERNAME, ''?'', Value FROM #temp WHERE Field = ''dbi_dbccLastKnownGood'''
			   , @command3 = 'TRUNCATE TABLE #temp'   
   
	   --Delete duplicates due to a bug in SQL Server 2008
   
		;WITH DBCC_CTE AS
	   (
		   SELECT ROW_NUMBER() OVER (PARTITION BY ServerName, DBName, LastCleanDBCCDate ORDER BY LastCleanDBCCDate) RowID
		   FROM #DBCCResults
	   )
	   DELETE FROM DBCC_CTE WHERE RowID > 1;

	   if @bShowSettingsResults = 1
	   begin   
		   --SELECT 'INTEGRITY CHECK'
		   SELECT 'INTEGRITY CHECK',       
			   ServerName       
			   , DBName   
			   , CASE LastCleanDBCCDate			
				   WHEN '1900-01-01 00:00:00.000' THEN 'Never ran DBCC CHECKDB' 
				   ELSE CAST(LastCleanDBCCDate AS VARCHAR) END AS LastCleanDBCCDate    
		   FROM #DBCCResults 
		   WHERE DBName <> 'tempdb'  
		   ORDER BY 3
	   end

	   set @sCount = 0;
	   if (SELECT count(*)
			FROM #DBCCResults
			WHERE LastCleanDBCCDate = '1900-01-01 00:00:00.000' and DBName <> 'tempdb') > 0 
			begin
				set @sCount = (SELECT count(*)
								FROM #DBCCResults
								WHERE LastCleanDBCCDate = '1900-01-01 00:00:00.000' and DBName <> 'tempdb')
				--print ''
				print N'     *** No integrity check has been run on ' + cast(@sCount as varchar(5)) + ' database(s) ***'
			end
			else
				print N'       Integrity Checks verified'

		create table #oldDBCC (
			dbNam sysname,
			LastCleanDBCC datetime,
			ageDay int
			)

		insert into #oldDBCC
			SELECT  DBName       
					, LastCleanDBCCDate
					, datediff(d, LastCleanDBCCDate, getdate()) 
			   FROM #DBCCResults
			   where LastCleanDBCCDate > '1900-01-01' and DBName <> 'tempdb'
			   group by DBName, LastCleanDBCCDate
			   having datediff(d, LastCleanDBCCDate, getdate()) > 7

		if @bShowSettingsResults = 1
		begin
			--select 'INTEGRITY CHECK - AGED'
			select 'INTEGRITY CHECK - AGED', dbNam AS DBName, LastCleanDBCC as LastCleanDBCCDate, ageDay as DaysOld
				from #oldDBCC
		end

		set @sCount = 0;
		if (select count (*) from #oldDBCC) > 0
			begin 
				set @sCount = (select count(*) from #oldDBCC)
				print N'     *** Most recent integrity check on ' + cast(@sCount as varchar(5)) + ' database(s) is older than 1 week ***'
			end
			--else
			--	print N'       AGED Integrity Checks verified'
		drop table #oldDBCC

	 
	   DROP TABLE #temp, #DBCCResults;

end
--=================================================================================================
--SOPHOS CHECK
if @bShowSettingsResults = 1
begin 
	Select 'SOPHOS CHECK', * from sys.dm_os_loaded_modules 
	where (name like '%SOPHOS%.DLL' or name like  '%SWI_IFSLSP_64.dll' or name like '%SWI_IFSLSP.dll')
end

if
(select COUNT(*) from sys.dm_os_loaded_modules 
where (name like '%SOPHOS%.DLL' or name like  '%SWI_IFSLSP_64.dll' or name like '%SWI_IFSLSP.dll')) > 0
	begin
		print '     *** Sophos DLLs are loaded into SQL Server Memory Process ***'
	end
ELSE
	begin
		print '       Sophos DLLs verified - currently not loaded into SQL Server Memory Process'
	end

/*
	To check exclusions  default exclusions already in place. Engine, SSRS, SSAS and FT not excluded so extra exclusions will be needed if they use more than the engine.
	o	Bring up Sophos Endpoint Security and Control > Configure anti-virus and HIPS > On-demand extensions and exclusions > Exclusions tab
	To check SQL Server Process Memory Space
	o	 Select * from sys.dm_os_loaded_modules where (name like '%SOPHOS_DETOURED.DLL' or name like  '%SOPHOS_DETOURED_x64.DLL' or name like  '%SWI_IFSLSP_64.dll')
	       CHANGED TO Select 'SOPHOS CHECK', * from sys.dm_os_loaded_modules where (name like '%SOPHOS%.DLL' or name like  '%SWI_IFSLSP_64.dll')   -- SGR 1/18/2020
	o	Any records returned indicates that Sophos DLLs are loaded inside SQL Server Memory Process.

	https://one.rackspace.com/display/SegSup/Domain+Controller%2C+MS+SQL+and+SharePoint+Server+Considerations+for+Sophos+Endpoint?searchId=TM47W0QCP

*/



--=================================================================================================
--WAIT STATS
SET NOCOUNT ON;
/* Top 10 Wait Stats Issues Reporter*/
/* Created by Rudy Panigas http://www.sqlservercentral.com/scripts/94439/ */
/* https://blogs.msdn.microsoft.com/sql_server_team/troubleshooting-high-hadr_sync_commit-wait-type-with-always-on-availability-groups/ */
/* https://blogs.msdn.microsoft.com/sql_server_team/sql-server-20162017-availability-group-secondary-replica-redo-model-and-performance/ */

--CURSOR VARIABLE
declare @wait varchar(50)
declare @percentage decimal(4,2)
set @sCount = 0

/* Create Temporary Tables for processing */
create table #results
( wait_type nvarchar(60)
, waiting_tasks_count bigint
, WaitS decimal(18,2)
, ResourceS decimal(18,2)
, SignalS decimal(18,2)
, Percentage decimal(4,2)
, RowNum int
, Comment varchar(max)
)

/* Insert Wait State information into temporary tables */

insert #results
( wait_type
, waiting_tasks_count
, WaitS
, ResourceS
, SignalS
, Percentage
, RowNum
)

(SELECT top 10
	   wait_type,
       waiting_tasks_count AS WaitCount,
	   wait_time_ms / 1000.0 AS Wait_S,
       (wait_time_ms - signal_wait_time_ms) / 1000.0 AS Resource_S,
       signal_wait_time_ms / 1000.0 AS Signal_S,
		100.0 * wait_time_ms / SUM (wait_time_ms) OVER() AS Percentage,
		ROW_NUMBER() OVER(ORDER BY wait_time_ms DESC) AS RowNum

	FROM   sys.dm_os_wait_stats

	where 
	   wait_type = 'CXPACKET' 

	/* CPU Issues */
	OR wait_type = 'SOS_SCHEDULER_YIELD'
	/* Network Issues */
	OR wait_type = 'ASYNC_NETWORK_IO' 
	/* Locking Issues */
	OR wait_type = 'LCK_M_BU' 
	OR wait_type = 'LCK_M_IS' 
	OR wait_type = 'LCK_M_IU' 
	OR wait_type = 'LCK_M_IX' 
	OR wait_type = 'LCK_M_RIn_NL'
	OR wait_type = 'LCK_M_RIn_S'
	OR wait_type = 'LCK_M_RIn_U'
	OR wait_type = 'LCK_M_RIn_X'
	OR wait_type = 'LCK_M_RS_S' 
	OR wait_type = 'LCK_M_RS_U' 
	OR wait_type = 'LCK_M_RX_S' 
	OR wait_type = 'LCK_M_RX_U' 
	OR wait_type = 'LCK_M_RX_X' 
	OR wait_type = 'LCK_M_S'    
	OR wait_type = 'LCK_M_SCH_M' 
	OR wait_type = 'LCK_M_SCH_S' 
	OR wait_type = 'LCK_M_SIU'   
	OR wait_type = 'LCK_M_SIX'   
	OR wait_type = 'LCK_M_U'     
	OR wait_type = 'LCK_M_UIX'   
	OR wait_type = 'LCK_M_X'     
	OR wait_type = 'LATCH_DT'    
	OR wait_type = 'LATCH_EX'    
	OR wait_type = 'LATCH_KP'    
	OR wait_type = 'LATCH_SH'    
	OR wait_type = 'LATCH_UP'    
	--
	/* Memory Issues */
	OR wait_type = 'RESOURCE_SEMAPHORE' 
	OR wait_type = 'RESOURCE_SEMAPHORE_MUTEX'
	OR wait_type = 'RESOURCE_SEMAPHORE_QUERY_COMPILE'
	OR wait_type = 'RESOURCE_SEMAPHORE_SMALL_QUERY' 
	OR wait_type = 'WRITELOG'

	/* Disk or Disk Subsystem Issues */
	OR wait_type = 'PAGEIOLATCH_DT' 
	OR wait_type = 'PAGEIOLATCH_EX' 
	OR wait_type = 'PAGEIOLATCH_KP' 
	OR wait_type = 'PAGEIOLATCH_SH' 
	OR wait_type = 'PAGEIOLATCH_UP' 
	OR wait_type = 'PAGELATCH_DT' 
	OR wait_type = 'PAGELATCH_EX' 
	OR wait_type = 'PAGELATCH_KP' 
	OR wait_type = 'PAGELATCH_SH' 
	OR wait_type = 'PAGELATCH_UP' 
	OR wait_type = 'LOGBUFFER'
	OR wait_type = 'ASYNC_IO_COMPLETION'
	OR wait_type = 'IO_COMPLETION' 

	/* Always On Issues */
	or wait_type = 'HADR_SYNC_COMMIT'
	or wait_type = 'PARALLEL_REDO_FLOW_CONTROL'
	or wait_type = 'PARALLEL_REDO_TRAN_TURN'
	or wait_type = 'DIRTY_PAGE_TABLE_LOCK'
	or wait_type = 'DPT_ENTRY_LOCK'
	)

DECLARE Waits_Cursor CURSOR 
	FOR SELECT [wait_type] AS WAITER, Percentage FROM [dbo].[#results] 
OPEN Waits_Cursor
FETCH NEXT FROM Waits_Cursor
	into @wait, @percentage

print '       Top 3 Wait Stats:'

WHILE @@FETCH_STATUS = 0
BEGIN
	UPDATE [dbo].[#results] SET [Comment] = 'CPU - Execute this script: SELECT scheduler_id, current_tasks_count, runnable_tasks_count FROM sys.dm_os_schedulers WHERE scheduler_id < 255; --If runnable tasks count > zero, CPU issues if double digits for any length of time, extreme CPU concern' WHERE  dbo.[#results].[wait_type] = 'SOS_SCHEDULER_YIELD'
	UPDATE [dbo].[#results] SET [Comment] = 'SETTINGS OR CODE - Wait stats shows more than 5% of your waits are on CXPackets, you may want to test lower (or non-zero) values of max degree of parallelism. Never set value great than # of CPUs' WHERE  dbo.[#results].[wait_type] = 'CXPACKET'
	UPDATE [dbo].[#results] SET [Comment] = 'NETWORK - Occurs on network writes when the task is blocked behind the network' WHERE  dbo.[#results].[wait_type] = 'ASYNC_NETWORK_IO'
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire a Bulk Update (BU) lock' WHERE  dbo.[#results].[wait_type] = 'LCK_M_BU'
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire an Intent Shared (IS) lock' WHERE  dbo.[#results].[wait_type] = 'LCK_M_IS'
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire an Intent Update (IU) lock ' WHERE  dbo.[#results].[wait_type] = 'LCK_M_IU'
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire an Intent Exclusive (IX) lock' WHERE  dbo.[#results].[wait_type] = 'LCK_M_IX'
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire a NULL lock on the current key value and an Insert Range lock between the current and previous key' WHERE  dbo.[#results].[wait_type] = 'LCK_M_RIn_NL'
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire a shared lock on the current key value and an Insert Range lock between the current and previous key' WHERE  dbo.[#results].[wait_type] = 'LCK_M_RIn_S' 
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire an Update lock on the current key value, and an Insert Range lock between the current and previous key' WHERE  dbo.[#results].[wait_type] = 'LCK_M_RIn_U' 
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire an Exclusive lock on the current key value, and an Insert Range lock between the current and previous key' WHERE  dbo.[#results].[wait_type] = 'LCK_M_RIn_X' 
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire a Shared lock on the current key value, and a Shared Range lock between the current and previous' WHERE  dbo.[#results].[wait_type] = 'LCK_M_RS_S'  
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire an Update lock on the current key value, and an Update Range lock between the current and previous key' WHERE  dbo.[#results].[wait_type] = 'LCK_M_RS_U'  
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire a Shared lock on the current key value, and an Exclusive Range lock between the current and previous key' WHERE  dbo.[#results].[wait_type] = 'LCK_M_RX_S'  
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire an Update lock on the current key value, and an Exclusive range lock between the current and previous key' WHERE  dbo.[#results].[wait_type] = 'LCK_M_RX_U'  
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire an Exclusive lock on the current key value, and an Exclusive Range lock between the current and previous key' WHERE  dbo.[#results].[wait_type] = 'LCK_M_RX_X'  
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire a Shared lock' WHERE  dbo.[#results].[wait_type] = 'LCK_M_S'     
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire a Schema Modify lock' WHERE  dbo.[#results].[wait_type] = 'LCK_M_SCH_M' 
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire a Schema Modify lock' WHERE  dbo.[#results].[wait_type] = 'LCK_M_SCH_S' 
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire a Shared With Intent Update lock' WHERE  dbo.[#results].[wait_type] = 'LCK_M_SIU'   
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire a Shared With Intent Exclusive lock' WHERE  dbo.[#results].[wait_type] = 'LCK_M_SIX'   
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire an Update lock' WHERE  dbo.[#results].[wait_type] = 'LCK_M_U'     
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire an Update With Intent Exclusive lock' WHERE  dbo.[#results].[wait_type] = 'LCK_M_UIX'   
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting to acquire an Exclusive lock' WHERE  dbo.[#results].[wait_type] = 'LCK_M_X'     
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting for a DT (destroy) latch. This does not include buffer latches or transaction mark latches' WHERE  dbo.[#results].[wait_type] = 'LATCH_DT'    
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting for an EX (exclusive) latch. This does not include buffer latches or transaction mark latches' WHERE  dbo.[#results].[wait_type] = 'LATCH_EX'    
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting for a KP (keep) latch. This does not include buffer latches or transaction mark latches' WHERE  dbo.[#results].[wait_type] = 'LATCH_KP'    
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting for an SH (share) latch. This does not include buffer latches or transaction mark latches' WHERE  dbo.[#results].[wait_type] = 'LATCH_SH'    
	UPDATE [dbo].[#results] SET [Comment] = 'LOCK - Waiting for an UP (update) latch. This does not include buffer latches or transaction mark latches' WHERE  dbo.[#results].[wait_type] = 'LATCH_UP'
	UPDATE [dbo].[#results] SET [Comment] = 'MEMORY - Query memory request cannot be granted immediately due to other concurrent queries. High waits and wait times may indicate excessive number of concurrent queries, or excessive memory request amounts' WHERE  dbo.[#results].[wait_type] = 'RESOURCE_SEMAPHORE'
	UPDATE [dbo].[#results] SET [Comment] = 'MEMORY - Query waits for its request for a thread reservation to be fulfilled. It also occurs when synchronizing query compile and memory grant requests' WHERE  dbo.[#results].[wait_type] = 'RESOURCE_SEMAPHORE_MUTEX'
	UPDATE [dbo].[#results] SET [Comment] = 'MEMORY - Number of concurrent query compilations reaches a throttling limit. High waits and wait times may indicate excessive compilations, recompiles, or uncachable plans' WHERE  dbo.[#results].[wait_type] = 'RESOURCE_SEMAPHORE_QUERY_COMPILE'
	UPDATE [dbo].[#results] SET [Comment] = 'MEMORY - Memory request by a small query cannot be granted immediately due to other concurrent queries. Wait time should not exceed more than a few seconds. High waits may indicate an excessive number of concurrent small queries while the main memory pool is blocked by waiting queries' WHERE  dbo.[#results].[wait_type] = 'RESOURCE_SEMAPHORE_SMALL_QUERY'
	UPDATE [dbo].[#results] SET [Comment] = 'MEMORY - Waiting for a log flush to complete. Common operations that cause log flushes are checkpoints and transaction commits' WHERE  dbo.[#results].[wait_type] = 'WRITELOG'
	UPDATE [dbo].[#results] SET [Comment] = 'DISK - Waiting on a latch for a buffer that is in an I/O request. The latch request is in Destroy mode. Long waits may indicate problems with the disk subsystem' WHERE  dbo.[#results].[wait_type] = 'PAGEIOLATCH_DT' 
	UPDATE [dbo].[#results] SET [Comment] = 'DISK - Waiting on a latch for a buffer that is in an I/O request. The latch request is in Exclusive mode. Long waits may indicate problems with the disk subsystem' WHERE  dbo.[#results].[wait_type] = 'PAGEIOLATCH_EX' 
	UPDATE [dbo].[#results] SET [Comment] = 'DISK - Waiting on a latch for a buffer that is in an I/O request. The latch request is in Keep mode. Long waits may indicate problems with the disk subsystem' WHERE  dbo.[#results].[wait_type] = 'PAGEIOLATCH_KP' 
	UPDATE [dbo].[#results] SET [Comment] = 'DISK - Waiting on a latch for a buffer that is in an I/O request. The latch request is in Share mode. Long waits may indicate problems with the disk subsystem' WHERE  dbo.[#results].[wait_type] = 'PAGEIOLATCH_SH' 
	UPDATE [dbo].[#results] SET [Comment] = 'DISK - Waiting on a latch for a buffer that is in an I/O request. The latch request is in Update mode. Long waits may indicate problems with the disk subsystem' WHERE  dbo.[#results].[wait_type] = 'PAGEIOLATCH_UP' 
	UPDATE [dbo].[#results] SET [Comment] = 'DISK - Waiting on a latch for a buffer that is not in an I/O request. The latch request is in Destroy mode' WHERE  dbo.[#results].[wait_type] = 'PAGELATCH_DT' 
	UPDATE [dbo].[#results] SET [Comment] = 'DISK - Waiting on a latch for a buffer that is not in an I/O request. The latch request is in Exclusive mode' WHERE  dbo.[#results].[wait_type] = 'PAGELATCH_EX' 
	UPDATE [dbo].[#results] SET [Comment] = 'DISK - Waiting on a latch for a buffer that is not in an I/O request. The latch request is in Keep mode' WHERE  dbo.[#results].[wait_type] = 'PAGELATCH_KP' 
	UPDATE [dbo].[#results] SET [Comment] = 'DISK - Waiting on a latch for a buffer that is not in an I/O request. The latch request is in Shared mode' WHERE  dbo.[#results].[wait_type] = 'PAGELATCH_SH' 
	UPDATE [dbo].[#results] SET [Comment] = 'DISK - Waiting on a latch for a buffer that is not in an I/O request. The latch request is in Update mode' WHERE  dbo.[#results].[wait_type] = 'PAGELATCH_UP' 
	UPDATE [dbo].[#results] SET [Comment] = 'DISK - Waiting for space in the log buffer to store a log record. Consistently high values may indicate that the log devices cannot keep up with the amount of log being generated by the server' WHERE  dbo.[#results].[wait_type] = 'LOGBUFFER' 
	UPDATE [dbo].[#results] SET [Comment] = 'DISK - Waiting for I/Os to finish' WHERE  dbo.[#results].[wait_type] = 'ASYNC_IO_COMPLETION' 
	UPDATE [dbo].[#results] SET [Comment] = 'DISK - Waiting for I/O operations to complete. This wait type generally represents non-data page I/Os. Data page I/O completion waits appear as PAGEIOLATCH_* waits' WHERE  dbo.[#results].[wait_type] = 'IO_COMPLETION' 
	update dbo.[#results] set [Comment] = 'This is SQL Server waiting for an extended stored-proc to finish. This could indicate a problem in your XP code' where dbo.[#results].wait_type = 'MSQL_XP'
	update dbo.[#results] set [Comment] = 'This says that there are not enough worker threads on the system to satisfy demand. You might consider raising the max worker threads setting' where dbo.[#results].wait_type = 'THREADPOOL'
	update dbo.[#results] set [Comment] = 'PR: It is SQL Server switching to pre-emptive scheduling mode to call out to Windows for something. Added in 2K8 and undocumented' where dbo.[#results].wait_type like 'PREEMPTIVE_OS' 
	update dbo.[#results] set [Comment] = 'AOAG - There is some performance issue in at least one Primary-Secondary replica data movement flow, or at least one secondary replica is slow in log hardening.' where dbo.[#results].wait_type like 'HADR_SYNC_COMMIT'
	update dbo.[#results] set [Comment] = 'AOAG - Indicates that one or more parallel redo worker threads cannot keep up with main redo thread transaction log dispatching speed or are blocked by some resources such as other type of waits.' where dbo.[#results].wait_type like 'PARALLEL_REDO_FLOW_CONTROL'
	update dbo.[#results] set [Comment] = 'AOAG - Only happens in a readable secondary replica when new insert triggers page-split system transaction, or record update in a heap table generates a forwarded record' where dbo.[#results].wait_type like 'PARALLEL_REDO_TRAN_TURN'
	update dbo.[#results] set [Comment] = 'AOAG - There is a wait on a lock that control access to dirty page table. This wait will not be generated anymore after the performance fix for concurrent read-only query and log redo is released.' where dbo.[#results].wait_type like 'DIRTY_PAGE_TABLE_LOCK'
	update dbo.[#results] set [Comment] = 'AOAG - Only occurs when parallel redo worker thread and a user query thread concurrently process redo operations for the same dirty page entry.' where dbo.[#results].wait_type like 'DPT_ENTRY_LOCK'


	if @sCount < 3
	begin
		print '         ' + cast(@percentage as varchar(5)) +'%	for ' +  @wait 
		set @sCount = @sCount + 1
	end
	
	FETCH NEXT FROM Waits_Cursor
		into @wait, @percentage
END
		   
CLOSE Waits_Cursor
DEALLOCATE Waits_Cursor

/* View Final Results */
if @bShowSettingsResults = 1
begin
	--SELECT 'WAIT STATS'
	SELECT 'WAIT STATS', 
	   wait_type AS 'Wait_Type'
	 , waiting_tasks_count AS 'Waiting_Tasks_Count'
	 , WaitS 'Wait_sec'
	 , ResourceS AS 'Resource_sec'
	 --, MAX_WAIT_TIME_MS AS 'MAX TIME WAITING (MS)'
	 , SignalS 'Signal_sec'
	 , Percentage as '%'
	 --, RowNum
	 , Comment AS 'POSSIBLE ISSUES'
	 FROM #results
	 WHERE waiting_tasks_count <> 0
	 ORDER BY WaitS DESC
 end

 /* Clean Up */
DROP TABLE #results;
--GO






print '   
  ----------------------------------------
     !!!!! VERIFICATIONS COMPLETE !!!!!
	 

' 




--=================================================================================================
--indexes
------------------- INDEX FRAGMENTATION

if @bFragLevels = 1
begin
	SELECT 'INDEX FRAGMENTATION'
	declare @sql nvarchar(max)
	declare @dbnm varchar(30)
	;with     Agg_IO_Stats3
	as       (select   top 1 DB_NAME(d.database_id) as database_name,
					   convert(varchar, cast(SUM(num_of_writes) as money), 1) AS 'Number of Writes'
			  from     sys.dm_io_virtual_file_stats (null, null) as s
			  inner join sys.databases d
				on s.database_id = d.database_id
			  where    s.database_id > 4
				and d.state = 0
				and d.source_database_id IS NULL
			  group by s.database_id, d.database_id
			  ORDER BY SUM(num_of_writes) DESC)
	select @dbnm =  database_name
	from     Agg_IO_Stats3
	--select @dbnm = 'changeDBNameHere_ifNecessary'	--if you want the index defrag script to run against a particular database, change that here


	select @sql='--In case you want to run this against another database without running the whole script again
	USE ['+ @dbnm + ']		--change db name here if you want to run against a different db
	SELECT  DB_NAME(d.database_id) as [DbName],
				--d.OBJECT_ID,
				OBJECT_SCHEMA_NAME(d.object_id, d.database_id) as [Schema],
				OBJECT_NAME(d.object_id, d.database_id) as [TblName],
				s.name AS IdxName,
				index_type_desc [Idx Desc],
				alloc_unit_type_desc [Alloc Unit Type], 
				index_depth [Idx Depth], --0 FOR INDEX LEAF LEVELS, HEAPS AND LOB_DATA OR ROW_OVERFLOW_DATA; > 0 FOR NONLEAF INDEX LEVELS; INDEX_LVL WILL BE THE HIGHEST AT THE ROOT LVL OF AN INDEX
				s.fill_factor,
				avg_fragmentation_in_percent as [Fragmentation %],
				page_count [Page Count],	-- indexes with page count < 1000 are skipped, by default, in Ola''s script
				fragment_count as [Frag Count], -- # OF FRAGMENTS IN THE LEAF LEVEL OF AN IN_ROW_DATA ALLOC UNIT
				avg_fragment_size_in_pages as [Fragment in Pages], -- AVG # OF PAGES IN ONE FRAGMENT IN THE LEAF LEVEL IN AN IN_ROW_DATA ALLOC UNIT
				avg_page_space_used_in_percent [Avg Pg Space Used %], --INDICATES PAGE FULLNESS; SHOULD BE CLOSE TO 100% BUT TO REDUCE PAGE SPLITS SHOULD ALSO BE LOWER THAN 100%
				record_count [Rcd Count] -- TOTAL # OF RECORDS
				,compressed_page_count  --ONLY FOR SQL 2008	
	FROM sys.dm_db_index_physical_stats (DB_ID(), NULL, NULL, NULL, NULL) d  -- NULL = LIMITED    **If any databases are offline or restoring, the 1st parameter will need to be changed as that is the db_id
			INNER JOIN sys.indexes s   
			ON d.object_id = s.object_id 
			AND d.index_id = s.index_id  
	where page_count >= 1000 and index_type_desc <> ''Heap''
	order by [Fragmentation %] desc
	--order by [Schema], [TblName]'
	print(@sql)	--in case you want to run it against another database without running the whole script again
	exec(@sql)
end



--=================================================================================================
--stats
------------------- STATISTICS
if @bFragLevels = 1
begin
	EXEC master.dbo.sp_MSforeachdb '
	use [?]
	IF ''?'' <> ''master'' AND ''?'' <> ''model'' AND ''?'' <> ''msdb'' AND ''?'' <> ''tempdb''
	BEGIN
	use [?]
	SELECT ''STATISTICS'', ''?'' as DBName, OBJECT_NAME(object_id) AS [ObjectName]
		  ,[name] AS [StatisticName]
		  ,STATS_DATE([object_id], [stats_id]) AS [StatisticUpdateDate]
	FROM sys.stats
	order by [StatisticUpdateDate] desc
	end
	'
end


--=================================================================================================

-- MISSING

SELECT 'MISSING INDEXES DMV', @lastSQLRestart as [LastSQLRestart]
DECLARE @runtime datetime
SET @runtime = GETDATE()
SELECT 'MISSING INDEXES DMV', CONVERT (varchar, @runtime, 126) AS Runtime,
convert(varchar, cast(migs.avg_total_user_cost * migs.avg_user_impact/100 * (migs.user_seeks + migs.user_scans) as money), 1)  AS improvement_measure,
mid.statement as 'Database.Schema.Table',  
migs.Avg_Total_User_Cost, 
migs.Avg_User_Impact, 
migs.User_Seeks, 
migs.User_Scans, 
mid.Database_ID, 
mid.[Object_ID], 
'CREATE INDEX IX_MI_' + object_name(mid.object_id, mid.database_id) + '_' + CONVERT (varchar, mig.index_group_handle) + '_' + CONVERT (varchar, mid.index_handle)  + ' ON ' + mid.statement + ' (' + ISNULL (mid.equality_columns,'')  + CASE WHEN mid.equality_columns IS NOT NULL AND mid.inequality_columns IS NOT NULL THEN ',' ELSE '' END + ISNULL (mid.inequality_columns, '') + ')' + ISNULL (' INCLUDE (' + mid.included_columns + ')', '') AS create_index_statement
FROM sys.dm_db_missing_index_groups mig  with (nolock)
                INNER JOIN sys.dm_db_missing_index_group_stats migs  with (nolock) ON migs.group_handle = mig.index_group_handle
                INNER JOIN sys.dm_db_missing_index_details mid  with (nolock) ON mig.index_handle = mid.index_handle
WHERE migs.avg_total_user_cost * (migs.avg_user_impact / 100.0) * (migs.user_seeks + migs.user_scans) > 10000
ORDER BY migs.avg_total_user_cost * migs.avg_user_impact * (migs.user_seeks + migs.user_scans) DESC



-- or MISSING FROM PLAN CACHE w QUERIES
/*
	These values will be slightly different because they come from the plan cache. If the plan has aged out of the plan cache, the missing index information goes with it. 
*/
SELECT 'MISSING INDEXES PLAN CACHE'                                                       
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

set ansi_warnings on
;WITH     XMLNAMESPACES (DEFAULT 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'),
         PlanMissingIndexes
AS       (SELECT query_plan,
                 usecounts
          FROM   sys.dm_exec_cached_plans AS cp CROSS APPLY sys.dm_exec_query_plan (cp.plan_handle) AS qp
          WHERE  qp.query_plan.exist('//MissingIndexes') = 1),
         MissingIndexes
AS       (SELECT stmt_xml.value('(QueryPlan/MissingIndexes/MissingIndexGroup/MissingIndex/@Database)[1]', 'sysname') AS DatabaseName,
                 stmt_xml.value('(QueryPlan/MissingIndexes/MissingIndexGroup/MissingIndex/@Schema)[1]', 'sysname') AS SchemaName,
                 stmt_xml.value('(QueryPlan/MissingIndexes/MissingIndexGroup/MissingIndex/@Table)[1]', 'sysname') AS TableName,
                 stmt_xml.value('(QueryPlan/MissingIndexes/MissingIndexGroup/@Impact)[1]', 'float') AS impact,
        --         stmt_xml.value('(@StatementSubTreeCost)[1]', 'VARCHAR(128)')
			     --   * ISNULL(stmt_xml.value('(./QueryPlan/MissingIndexes/MissingIndexGroup/@Impact)[1]','float'), 0)
				    --* pmi.usecounts AS Improvement ,
                 pmi.usecounts,
                 STUFF((SELECT DISTINCT ', ' + c.value('(@Name)[1]', 'sysname')
                        FROM   stmt_xml.nodes ('//ColumnGroup') AS t(cg) CROSS APPLY cg.nodes ('Column') AS r(c)
                        WHERE  cg.value('(@Usage)[1]', 'sysname') = 'EQUALITY'
                        FOR    XML PATH ('')), 1, 2, '') AS equality_columns,
                 STUFF((SELECT DISTINCT ', ' + c.value('(@Name)[1]', 'sysname')
                        FROM   stmt_xml.nodes ('//ColumnGroup') AS t(cg) CROSS APPLY cg.nodes ('Column') AS r(c)
                        WHERE  cg.value('(@Usage)[1]', 'sysname') = 'INEQUALITY'
                        FOR    XML PATH ('')), 1, 2, '') AS inequality_columns,
                 STUFF((SELECT DISTINCT ', ' + c.value('(@Name)[1]', 'sysname')
                        FROM   stmt_xml.nodes ('//ColumnGroup') AS t(cg) CROSS APPLY cg.nodes ('Column') AS r(c)
                        WHERE  cg.value('(@Usage)[1]', 'sysname') = 'INCLUDE'
                        FOR    XML PATH ('')), 1, 2, '') AS include_columns,
                 query_plan,
                 stmt_xml.value('(@StatementText)[1]', 'varchar(4000)') AS sql_text
          FROM   PlanMissingIndexes AS pmi CROSS APPLY query_plan.nodes ('//StmtSimple') AS stmt(stmt_xml)
          WHERE  stmt_xml.exist('QueryPlan/MissingIndexes') = 1)
SELECT   'MISSING INDEXES PLAN CACHE'
		 DatabaseName,
         SchemaName,
         TableName,
         equality_columns,
         inequality_columns,
         include_columns,
         --improvement as improvement_measure,
         usecounts,
         impact as [impact %],	-- expected to improve performance by this %; perhaps recommend if impact % is >= 85%
         query_plan,
         CAST ('<?query --' + CHAR(13) + sql_text + CHAR(13) + ' --?>' AS XML) AS SQLText,
         'CREATE NONCLUSTERED INDEX IX_' + REPLACE(REPLACE(REPLACE(SchemaName, '_', ''), '[', ''), ']', '') + '_' + REPLACE(REPLACE(REPLACE(TableName, '_', ''), '[', ''), ']', '') + '_' + COALESCE (REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(equality_columns, '_', ''), '[', ''), ']', ''), ',', ''), ' ', ''), '') + COALESCE (REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(COALESCE (inequality_columns, ''), '_', ''), '[', ''), ']', ''), ',', ''), ' ', ''), '') + ' ON ' + SchemaName + '.' + TableName + '(' + STUFF(COALESCE (',' + equality_columns, '') + COALESCE (',' + inequality_columns, ''), 1, 1, '') + ')' + COALESCE (' INCLUDE (' + include_columns + ')', '')  AS PotentialDDL
FROM     MissingIndexes
WHERE    usecounts > 100
ORDER BY usecounts DESC, DatabaseName, SUM(usecounts) OVER (PARTITION BY DatabaseName, SchemaName, TableName) DESC, SUM(usecounts) OVER (PARTITION BY TableName, equality_columns, inequality_columns) DESC






--=================================================================================================

-- UNUSED/EXTRANEOUS

SELECT 'UNUSED INDEXES'
DECLARE @dbid int 
set @dbid = db_id()

SELECT  'UNUSED INDEXES', db_name(db_id()) as DBName, 
		object_name(s.object_id) AS [object],
        s.object_id,
        i.name AS [index name],
        i.index_id, 
        s.user_seeks, 
        s.user_scans, 
        s.user_lookups, 
        s.user_updates,
        'DROP INDEX ' + object_schema_name(s.object_id) + '.' + object_name(s.object_id) + '.' + i.name + ';' AS [Delete Statement]
FROM  sys.dm_db_index_usage_stats s
JOIN  sys.indexes i
  ON  i.object_id = s.object_id
  AND i.index_id = s.index_id
  AND i.name is not null
  AND i.is_primary_key = 0
  AND i.is_unique_constraint = 0
WHERE s.database_id = @dbid
  AND objectproperty(s.object_id,'IsUserTable') = 1
  AND i.type_desc <> 'CLUSTERED'
  AND ((s.user_seeks + s.user_scans + s.user_lookups) = 0)
  --and i.name like 'IX_MI_ETIX_DOWNLOADER_TICKETS_SEATS_Combine01'   -- name of the index
  --and object_name(s.object_id) like 'ETIX_DOWNLOADER_TICKETS_SEATS'	-- name of the table
ORDER BY user_updates desc



--=================================================================================================

-- DUPLICATE
-- THIS DOES NOT FACTOR IN THE ORDER OF THE SORT (ASC VS DESC), and WILL ALSO REPORT A UNIQUE PRIMARY KEY AS IDENTICAL TO A NON-UNIQUE, NONCLUSTERED INDEX IF THEY HAVE THE SAME COLUMNS

SELECT 'DUPLICATE INDEXES';
EXEC master.dbo.sp_MSforeachdb '
use [?]
IF ''?'' <> ''master'' AND ''?'' <> ''model'' AND ''?'' <> ''msdb'' AND ''?'' <> ''tempdb''
BEGIN
use [?]
;WITH indexcols AS
(
	SELECT object_id AS id, index_id as indid, name,is_unique,
		(SELECT CASE keyno WHEN 0 THEN NULL ELSE colid END AS [data()]
			FROM sys.sysindexkeys AS k
			WHERE k.id = i.object_id
			AND k.indid = i.index_id
			ORDER BY keyno, colid
			FOR XML PATH('''')) AS cols,
		(SELECT CASE keyno WHEN 0 THEN colid ELSE NULL END AS [data()]
			FROM sys.sysindexkeys AS k
			WHERE k.id = i.object_id
			AND k.indid = i.index_id
			ORDER BY colid
			FOR XML PATH('''')) AS inc
	FROM sys.indexes AS i
	where is_hypothetical = 0		-- ADDED THIS JUST RECENTLY AS GETTING RID OF HYPOTHETICALS WILL ELIMINATE MANY OF THESE
)
SELECT ''?'' as DBName,
	object_schema_name(c1.id) + ''.'' + object_name(c1.id) as ''table'',
	c1.name AS ''index'',
	c2.name AS ''exactduplicate''
FROM indexcols AS c1
	JOIN indexcols AS c2
ON c1.id = c2.id
	AND c1.indid < c2.indid
	AND c1.cols = c2.cols
	AND c1.inc = c2.inc
	AND c1.is_unique = c2.is_unique;
end
'




--=================================================================================================
-- HYPOTHETICAL INDEXES
SELECT 'HYPOTHETICAL INDEXES'
-- Set database context
USE master
-- Drop temporary table if exists
IF OBJECT_ID('tempDB.dbo.#HypotheticalIndexDropScript') IS NOT NULL
    DROP TABLE #HypotheticalIndexDropScript;
    
-- Create Temporary Table
CREATE TABLE #HypotheticalIndexDropScript
    (
      DatabaseName VARCHAR(255) ,
	  HypotheticalIndexes varchar(4000),
	  TableName varchar(150),
      HypotheticalIndexesScript VARCHAR(4000)
    );

INSERT  INTO #HypotheticalIndexDropScript
        EXEC sp_MSforeachdb 'USE [?]; SELECT  DB_NAME(DB_ID()), 
	    i.name  AS HypotheticalIndexes,
		''['' + SCHEMA_NAME(o.[schema_id]) + ''].'' + ''['' + OBJECT_NAME(o.[object_id]) + '']'' as TableName,
		''USE '' + ''['' + DB_NAME(DB_ID()) + ''];'' + '' IF  EXISTS (SELECT 1 FROM sys.indexes  AS i WHERE i.[object_id] = '' + ''object_id('' + + '''''''' + ''['' + SCHEMA_NAME(o.[schema_id]) + ''].'' + ''['' +  OBJECT_NAME(i.[object_id]) + '']'' + '''''''' + '')'' + '' AND name = '' + '''''''' + i.NAME + '''''''' + '') ''    
       + '' DROP INDEX '' + ''['' + i.name + '']'' + '' ON '' + ''['' + SCHEMA_NAME(o.[schema_id]) + ''].'' + ''['' + OBJECT_NAME(o.[object_id]) + ''];'' AS HypotheticalIndexesScript

FROM    sys.indexes i
        INNER JOIN sys.objects o ON o.[object_id] = i.[object_id]
WHERE is_hypothetical = 1'


select 'HYPOTHETICAL INDEXES', * from #HypotheticalIndexDropScript
drop table #HypotheticalIndexDropScript




--=================================================================================================
-- SP that consumes the most CPU resources
--SELECT 'MOST CPU RESOURCES'
SELECT 'MOST CPU RESOURCES', DB_NAME(st.dbid) DBName
      ,OBJECT_SCHEMA_NAME(st.objectid,dbid) SchemaName
      ,OBJECT_NAME(st.objectid,dbid) StoredProcedure
      ,max(cp.usecounts) Execution_count
      ,sum(qs.total_worker_time) total_cpu_time
      ,sum(qs.total_worker_time) / (max(cp.usecounts) * 1.0)  avg_cpu_time
 FROM sys.dm_exec_cached_plans cp join sys.dm_exec_query_stats qs on cp.plan_handle = qs.plan_handle
      CROSS APPLY sys.dm_exec_sql_text(cp.plan_handle) st
 where DB_NAME(st.dbid) is not null and cp.objtype = 'proc'
 group by DB_NAME(st.dbid),OBJECT_SCHEMA_NAME(objectid,st.dbid), OBJECT_NAME(objectid,st.dbid) 
 order by sum(qs.total_worker_time) desc 
-----------------------------------------------------------------------------
--SP that has executed the most I/O requests

--SELECT 'MOST I/O REQUESTS'
SELECT 'MOST I/O REQUESTS', DB_NAME(st.dbid) DBName
      ,OBJECT_SCHEMA_NAME(objectid,st.dbid) SchemaName
      ,OBJECT_NAME(objectid,st.dbid) StoredProcedure
      ,max(cp.usecounts) execution_count
      ,sum(qs.total_physical_reads + qs.total_logical_reads + qs.total_logical_writes) total_IO
      ,sum(qs.total_physical_reads + qs.total_logical_reads + qs.total_logical_writes) / (max(cp.usecounts)) avg_total_IO
      ,sum(qs.total_physical_reads) total_physical_reads
      ,sum(qs.total_physical_reads) / (max(cp.usecounts) * 1.0) avg_physical_read    
      ,sum(qs.total_logical_reads) total_logical_reads
      ,sum(qs.total_logical_reads) / (max(cp.usecounts) * 1.0) avg_logical_read  
      ,sum(qs.total_logical_writes) total_logical_writes
      ,sum(qs.total_logical_writes) / (max(cp.usecounts) * 1.0) avg_logical_writes  
 FROM sys.dm_exec_query_stats qs CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) st
   join sys.dm_exec_cached_plans cp on qs.plan_handle = cp.plan_handle
  where DB_NAME(st.dbid) is not null and cp.objtype = 'proc'
 group by DB_NAME(st.dbid),OBJECT_SCHEMA_NAME(objectid,st.dbid), OBJECT_NAME(objectid,st.dbid) 
 order by sum(qs.total_physical_reads + qs.total_logical_reads + qs.total_logical_writes) desc

-----------------------------------------------------------------------------
--SPs take the longest time to execute

--SELECT 'LONGEST TIME TO EXECUTE'
SELECT 'LONGEST TIME TO EXECUTE', DB_NAME(st.dbid) DBName
      ,OBJECT_SCHEMA_NAME(objectid,st.dbid) SchemaName
      ,OBJECT_NAME(objectid,st.dbid) StoredProcedure
      ,max(cp.usecounts) execution_count
      ,sum(qs.total_elapsed_time) total_elapsed_time
      ,sum(qs.total_elapsed_time) / max(cp.usecounts) avg_elapsed_time
 FROM sys.dm_exec_query_stats qs CROSS APPLY sys.dm_exec_sql_text(qs.plan_handle) st
   join sys.dm_exec_cached_plans cp on qs.plan_handle = cp.plan_handle
  where DB_NAME(st.dbid) is not null and cp.objtype = 'proc'
 group by DB_NAME(st.dbid),OBJECT_SCHEMA_NAME(objectid,st.dbid), OBJECT_NAME(objectid,st.dbid) 
 order by sum(qs.total_elapsed_time) desc

 --=================================================================================================
