USE [master]
GO
CREATE LOGIN [pacemakerLogin] with PASSWORD= N'ComplexP@$$w0rd!';

ALTER SERVER ROLE [sysadmin] ADD MEMBER [pacemakerLogin];