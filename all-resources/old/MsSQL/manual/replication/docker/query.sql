declare @IsIntegratedSecurityOnly as sql_variant  
set @IsIntegratedSecurityOnly = (select SERVERPROPERTY('IsIntegratedSecurityOnly'))  
select @IsIntegratedSecurityOnly as IsIntegratedSecurityOnly,  
case @IsIntegratedSecurityOnly  
when 0 then 'Windows and SQL Server Authentication'  
when 1 then ' Integrated security (Windows Authentication)'  
else 'Invalid Input'  
end as 'Integrated Security Type' 