SELECT name from sys.databases;
go

Create database standaloneDB;

USE standaloneDB;
GO

CREATE TABLE Persons (
    PersonID int,
    LastName varchar(255),
    FirstName varchar(255),
);



INSERT INTO Persons (PersonID, FirstName, LastName)
VALUES ('1', 'Neaj', 'Morshad'),
       ('2', 'Neaj', 'Morshad');

INSERT INTO Persons (PersonID, FirstName, LastName)
VALUES ('6', 'NeajTest', 'MorshadTest');


DROP TABLE Persons;
GO


USE standaloneDB;
GO
SELECT * from Persons;
GO




USE standaloneDB;
GO
BACKUP DATABASE standaloneDB
TO DISK = '/var/opt/mssql/data/backups/standaloneDB.bak'
   WITH FORMAT,
      MEDIANAME = 'SQLServerBackups',
      NAME = 'Full Backup of standaloneDB';
GO