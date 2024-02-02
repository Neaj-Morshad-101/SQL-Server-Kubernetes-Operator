select @@SERVERNAME as Server_Name

select top (1000)
            [CustomerID],
            [SalesAmount]
from [Sales].[dbo].[CUSTOMER];