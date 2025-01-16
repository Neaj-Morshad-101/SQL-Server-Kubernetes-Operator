use [master]

select name from sys.databases 
go


----------------------------- 

CREATE DATABASE Sales
GO


SELECT * FROM [Sales].[dbo].[CUSTOMER]
GO


SELECT * FROM [Sales].[dbo].[employee]

use [Sales]
select * from employee; 

SELECT * FROM [Sales].[dbo].[employ]




SELECT name, date_modified FROM msdb.dbo.sysjobs order by date_modified desc
