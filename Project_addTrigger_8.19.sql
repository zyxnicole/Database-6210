-- INFO 6210 Data Mgt and Database Design: SQL DDL statements for implementing the database
-- Group 6： Pei-Ling Chiang, Shuyuan Lyu, Ssu-Yu Ning, Zhehui Yang, Bo-Zhong Zhang, Yuxin Zhang

/* This file is used to compute the project date of team 6. We are using the GROUP6_COVID19_HOSPITAL_DBMS database. It contains:
* 1. Creation of all tables via INSERT(most tables), STORE PROCEDURE(Physician), And Data Import Wizard(Patient, ClinicalSymptom, PatientSymptom)
* 2. DATA ENCRYPTION - Encrypted CurrentCondition column in (MedicalHistory)
* 3. CHECK constraints on some tables
* 4. Computed columns on some tables
* 4. Four views*/


USE GROUP6_COVID19_HOSPITAL_DBMS

--------------------Dropping All Tables-------------------

--DROP TABLE dbo.Patient
--DROP TABLE dbo.Examination
--DROP TABLE dbo.MedicalCondition
--DROP TABLE dbo.ClinicalSymptom
--DROP TABLE dbo.Bed
--DROP TABLE dbo.Address
--DROP TABLE dbo.Physician
--DROP TABLE dbo.Treatment
--DROP TABLE dbo.PatientExamination
--DROP TABLE dbo.Admission
--DROP TABLE dbo.PatientSymptom
--DROP TABLE dbo.MedicalHistory
--DROP TABLE dbo.TreatmentResult
--DROP TABLE dbo.PatientBed
--DROP TABLE dbo.PatientAddress

------------------------Create Patient------------------------

CREATE TABLE dbo.Patient 
(
PatientID INT IDENTITY NOT NULL PRIMARY KEY,
PatientFirstName VARCHAR(50),
PatientLastName VARCHAR(50),
BirthDate DATE,
Sex VARCHAR(10)
);

ALTER TABLE dbo.Patient ADD CONSTRAINT CHK_Age CHECK (datediff(hour,BirthDate,GETDATE())/8766 < 150)
ALTER TABLE dbo.Patient ADD CONSTRAINT CHK_Gender CHECK (Sex IN ('M','F'))

--SET IDENTITY_INSERT dbo.Patient ON
--SET IDENTITY_INSERT dbo.Patient OFF

------------------------Create Examination------------------------

CREATE TABLE dbo.Examination
(ExaminationID INT IDENTITY NOT NULL PRIMARY KEY,
Type VARCHAR(50),
Name VARCHAR(50)
);

------------------------Create MedicalCondition-------------------

CREATE TABLE dbo.MedicalCondition
(MedicalConditionID INT IDENTITY NOT NULL PRIMARY KEY,
Description VARCHAR(250)
);

----------------------Create ClinicalSymptom----------------------

CREATE TABLE dbo.ClinicalSymptom
(
SymptomID INT IDENTITY NOT NULL PRIMARY KEY,
Name VARCHAR(50)
);

--SET IDENTITY_INSERT dbo.ClinicalSymptom ON
--SET IDENTITY_INSERT dbo.ClinicalSymptom OFF

------------------------Create Bed----------------

CREATE TABLE dbo.Bed
(
BedID INT NOT NULL PRIMARY KEY,
CareLevel INT
);

------------------------Create Address----------------

CREATE TABLE dbo.Address
(
AddressID INT IDENTITY NOT NULL PRIMARY KEY,
StreetNumber VARCHAR(100),
City VARCHAR(50),
State VARCHAR(50),
ZipCode INT
);

ALTER TABLE dbo.Address ADD CONSTRAINT CHK_Length CHECK(LEN(ZipCode) = 5)

------------------------Create Physician----------------

CREATE TABLE dbo.Physician
(
PhysicianID INT IDENTITY NOT NULL PRIMARY KEY,
PhysicianFirstName VARCHAR(50),
PhysicianLastName VARCHAR(50),
Specialty VARCHAR(50)
);

------------------------Create Treatment----------------

CREATE TABLE dbo.Treatment
(
TreatmentID INT IDENTITY NOT NULL PRIMARY KEY,
[Type] VARCHAR(100),
Name VARCHAR(200)
);

------------------------Create PatientExamination ----------------

CREATE TABLE dbo.PatientExamination
(
ExaminationID INT NOT NULL FOREIGN KEY
	REFERENCES dbo.Examination(ExaminationID),
PatientID INT NOT NULL FOREIGN KEY
	REFERENCES dbo.Patient(PatientID),
ExamDate DATETIME,
ExamResult VARCHAR(50),
ExamSeverity  VARCHAR(50),
CONSTRAINT PK_PatientExamination PRIMARY KEY CLUSTERED (ExaminationID, PatientID)
);

ALTER TABLE dbo.PatientExamination ADD CONSTRAINT CHK_examresult CHECK(ExamResult IN ('Normal','Abnormal'));
ALTER TABLE dbo.PatientExamination ADD CONSTRAINT CHK_severity CHECK(ExamSeverity IN ('Mild','Moderate','Severe'));

------------------------Create Admission ----------------

CREATE TABLE dbo.Admission
(
AdmissionID INT IDENTITY NOT NULL PRIMARY KEY,
PatientID INT NOT NULL
	REFERENCES Patient(PatientID),
AdmissionDate DATETIME,
DischargeDate DATETIME,
AdmissionType VARCHAR(10),
DischargeType VARCHAR(10),
FrequencyRecord INT
);

ALTER TABLE dbo.Admission ADD CONSTRAINT CHK_admissiontype CHECK(AdmissionType IN ('Regular','Emergency'));
ALTER TABLE dbo.Admission ADD CONSTRAINT CHK_dischargetype CHECK(DischargeType IN ('Recover','Dead','null'));
ALTER TABLE Admission ADD CONSTRAINT BanKids CHECK (dbo.CheckAge(PatientID) >= 12);

------------------------Create PatientSymptom  ----------------

CREATE TABLE dbo.PatientSymptom
(
PatientID INT NOT NULL
 	REFERENCES Patient(PatientID),
SymptomID INT NOT NULL
	REFERENCES ClinicalSymptom(SymptomID),
StartDate DATE,
EndDate DATE,
CONSTRAINT PK_PatientSymptom PRIMARY KEY CLUSTERED(SymptomID, PatientID)
)

------------------------Create MedicalHistory  ----------------

DROP TABLE dbo.MedicalHistory

CREATE TABLE dbo.MedicalHistory
(
MedicalConditionID INT NOT NULL
	REFERENCES MedicalCondition(MedicalConditionID),
PatientID INT NOT NULL
	REFERENCES Patient(PatientID),
StartDate DATE,
EndDate DATE,
CurrentCondition VARBINARY(250),
CONSTRAINT PK_MedicalHistory PRIMARY KEY CLUSTERED(MedicalConditionID, PatientID)
)
ALTER TABLE dbo.MedicalHistory ADD CONSTRAINT CHK_condition CHECK (CurrentCondition IN ('Cured','Continue','null'));

------------------------Create TreatmentResult ----------------

CREATE TABLE dbo.TreatmentResult
(
TreatmentResultID INT IDENTITY NOT NULL PRIMARY KEY,
PhysicianID INT NOT NULL,
TreatmentID INT NOT NULL,
PatientID INT NOT NULL,
StartDate DATETIME,
EndDate DATETIME, 
Result VARCHAR(20)
);

ALTER TABLE TreatmentResult ADD CONSTRAINT FK_Physician FOREIGN KEY(PhysicianID)
	REFERENCES Physician(PhysicianID);
ALTER TABLE TreatmentResult ADD CONSTRAINT FK_Patient FOREIGN KEY(PatientID) 
	REFERENCES Patient(PatientID);
ALTER TABLE TreatmentResult ADD CONSTRAINT FK_Treatment FOREIGN KEY(TreatmentID) 
	REFERENCES Treatment(TreatmentID);
ALTER TABLE dbo.TreatmentResult ADD CONSTRAINT CHK_result CHECK(Result IN ('Effective','Ineffective'));
	
------------------------Create PatientBed----------------

DROP TABLE dbo.PatientBed

CREATE TABLE dbo.PatientBed
(
PatientBedID INT IDENTITY NOT NULL PRIMARY KEY,
BedID INT NOT NULL FOREIGN KEY REFERENCES Bed(BedID),
PatientID INT NOT NULL FOREIGN KEY REFERENCES Patient(PatientID),
StartDate DATETIME,
EndDate DATETIME
);

------------------------ Create PatientAddress ------------------------ 

CREATE TABLE dbo.PatientAddress
(
PatientID INT NOT NULL
	REFERENCES Patient(PatientID),
AddressID INT NOT NULL
	REFERENCES Address(AddressID ),
CONSTRAINT PK_PatientAddress PRIMARY KEY CLUSTERED (PatientID, AddressID)
);

------------------ Computed column LengthOfStay based on function -------------------

DROP FUNCTION fn_CountLengthOfStay

CREATE FUNCTION fn_CountLengthOfStay (@AdmissionID INT)
RETURNS INT
AS BEGIN
	DECLARE @CountDays INT = 
	(SELECT DATEDIFF (DAY, AdmissionDate , COALESCE (DischargeDate, getdate()) )
	 FROM dbo.Admission 
	 WHERE AdmissionID = @AdmissionID)
	SET @CountDays = isnull(@CountDays , 0)
	RETURN @CountDays
END

ALTER TABLE dbo.Admission
ADD LengthOfStay AS (dbo.fn_CountLengthOfStay (AdmissionID))

------------------ Computed column Age based on function ----------------------------

CREATE FUNCTION fn_CountAge (@PatientID INT)
RETURNS INT
AS BEGIN
	DECLARE @CountAge INT = 
	(SELECT DATEDIFF (HOUR, BirthDate , GETDATE())/8766
	 FROM dbo.Patient 
	 WHERE PatientID = @PatientID)
	RETURN @CountAge
END

ALTER TABLE dbo.Patient
ADD Age AS (dbo.fn_CountAge (PatientID))

------------------------  STORED PROCEDURE ------------------------ 

--DROP PROCEDURE dbo.AddPhysician

CREATE PROCEDURE dbo.AddPhysician
	@PhysicianFirstName VARCHAR(50),
	@PhysicianLastName VARCHAR(50),
	@Specialty VARCHAR(50)
AS
BEGIN
	INSERT INTO dbo.Physician(PhysicianFirstName, PhysicianLastName,Specialty)
	VALUES (@PhysicianFirstName, @PhysicianLastName, @Specialty)
END

------------------------ Inserting Data Table Physician------------------------ 

DECLARE @PhysicianFirstName VARCHAR(50) SET @PhysicianFirstName = 'Micheal'
DECLARE	@PhysicianLastName VARCHAR(50) SET @PhysicianLastName ='Smith'
DECLARE	@Specialty VARCHAR(50) SET @Specialty = 'Emergency Medicine'
EXEC dbo.AddPhysician @PhysicianFirstName, @PhysicianLastName, @Specialty

----------

DECLARE @PhysicianFirstName VARCHAR(50) SET @PhysicianFirstName = 'Robert'
DECLARE	@PhysicianLastName VARCHAR(50) SET @PhysicianLastName ='Smith'
DECLARE	@Specialty VARCHAR(50) SET @Specialty = 'Pulmonology'
EXEC dbo.AddPhysician @PhysicianFirstName, @PhysicianLastName, @Specialty

----------

DECLARE @PhysicianFirstName VARCHAR(50) SET @PhysicianFirstName = 'Maria'
DECLARE	@PhysicianLastName VARCHAR(50) SET @PhysicianLastName ='Garcia'
DECLARE	@Specialty VARCHAR(50) SET @Specialty = 'Radiology'
EXEC dbo.AddPhysician @PhysicianFirstName, @PhysicianLastName, @Specialty

----------

DECLARE @PhysicianFirstName VARCHAR(50) SET @PhysicianFirstName = 'Henry'
DECLARE	@PhysicianLastName VARCHAR(50) SET @PhysicianLastName ='Davis'
DECLARE	@Specialty VARCHAR(50) SET @Specialty = 'Anesthesiology'
EXEC dbo.AddPhysician @PhysicianFirstName, @PhysicianLastName, @Specialty

----------

DECLARE @PhysicianFirstName VARCHAR(50) SET @PhysicianFirstName = 'James'
DECLARE	@PhysicianLastName VARCHAR(50) SET @PhysicianLastName ='Smith'
DECLARE	@Specialty VARCHAR(50) SET @Specialty = 'Internal Medicine'
EXEC dbo.AddPhysician @PhysicianFirstName, @PhysicianLastName, @Specialty

----------

DECLARE @PhysicianFirstName VARCHAR(50) SET @PhysicianFirstName = 'Samuel'
DECLARE	@PhysicianLastName VARCHAR(50) SET @PhysicianLastName ='Taylor'
DECLARE	@Specialty VARCHAR(50) SET @Specialty = 'Pulmonology'
EXEC dbo.AddPhysician @PhysicianFirstName, @PhysicianLastName, @Specialty

----------

DECLARE @PhysicianFirstName VARCHAR(50) SET @PhysicianFirstName = 'Sarah'
DECLARE	@PhysicianLastName VARCHAR(50) SET @PhysicianLastName ='Clark'
DECLARE	@Specialty VARCHAR(50) SET @Specialty = 'Emergency Medicine'
EXEC dbo.AddPhysician @PhysicianFirstName, @PhysicianLastName, @Specialty

----------

DECLARE @PhysicianFirstName VARCHAR(50) SET @PhysicianFirstName = 'Jane'
DECLARE	@PhysicianLastName VARCHAR(50) SET @PhysicianLastName ='Wilson'
DECLARE	@Specialty VARCHAR(50) SET @Specialty = 'Infectious Disease'
EXEC dbo.AddPhysician @PhysicianFirstName, @PhysicianLastName, @Specialty

----------

DECLARE @PhysicianFirstName VARCHAR(50) SET @PhysicianFirstName = 'Catherine'
DECLARE	@PhysicianLastName VARCHAR(50) SET @PhysicianLastName ='Wu'
DECLARE	@Specialty VARCHAR(50) SET @Specialty = 'Pediatrics'
EXEC dbo.AddPhysician @PhysicianFirstName, @PhysicianLastName, @Specialty

----------

DECLARE @PhysicianFirstName VARCHAR(50) SET @PhysicianFirstName = 'Ann'
DECLARE	@PhysicianLastName VARCHAR(50) SET @PhysicianLastName ='Rodriguez'
DECLARE	@Specialty VARCHAR(50) SET @Specialty = 'Infectious Disease'
EXEC dbo.AddPhysician @PhysicianFirstName, @PhysicianLastName, @Specialty

----------

DECLARE @PhysicianFirstName VARCHAR(50) SET @PhysicianFirstName = 'Charles'
DECLARE	@PhysicianLastName VARCHAR(50) SET @PhysicianLastName ='Carlos'
DECLARE	@Specialty VARCHAR(50) SET @Specialty = 'Respiratory Therapy'
EXEC dbo.AddPhysician @PhysicianFirstName, @PhysicianLastName, @Specialty

----------

DECLARE @PhysicianFirstName VARCHAR(50) SET @PhysicianFirstName = 'Thomas'
DECLARE	@PhysicianLastName VARCHAR(50) SET @PhysicianLastName ='Lee'
DECLARE	@Specialty VARCHAR(50) SET @Specialty = 'Respiratory Therapy'
EXEC dbo.AddPhysician @PhysicianFirstName, @PhysicianLastName, @Specialty


----Inserting data table Patient, ClinicalSymptom, Patient Symptom with Data Import Wizard---


----------------------------- Inserting Data Table Examination -----------------------------

INSERT INTO dbo.Examination(Type,Name) VALUES ('Radiology','Abdominal Ultrasound');
INSERT INTO dbo.Examination(Type,Name) VALUES ('Radiology','Pulmonary CT');
INSERT INTO dbo.Examination(Type,Name) VALUES ('Radiology','Pulmonary X-ray');
INSERT INTO dbo.Examination(Type,Name) VALUES ('Radiology','Cranial-facial MRI');
INSERT INTO dbo.Examination(Type,Name) VALUES ('Blood test','Comprehensive metabolic panel');
INSERT INTO dbo.Examination(Type,Name) VALUES ('Blood test','Basic metabolic panel');
INSERT INTO dbo.Examination(Type,Name) VALUES ('Blood test','Complete blood count');
INSERT INTO dbo.Examination(Type,Name) VALUES ('Coronavirus test','Molecular test');
INSERT INTO dbo.Examination(Type,Name) VALUES ('Coronavirus test','Antigen test');
INSERT INTO dbo.Examination(Type,Name) VALUES ('Coronavirus test','Antibody test');
INSERT INTO dbo.Examination(Type,Name) VALUES ('Urinalysis','Urine culture');

-------------------------------- Inserting Data Table MedicalCondition -----------

INSERT INTO dbo.MedicalCondition(Description) VALUES ('Hypertension');
INSERT INTO dbo.MedicalCondition(Description) VALUES ('Hyperlipidemia');
INSERT INTO dbo.MedicalCondition(Description) VALUES ('Obesity');
INSERT INTO dbo.MedicalCondition(Description) VALUES ('Diabetes');
INSERT INTO dbo.MedicalCondition(Description) VALUES ('COPD');
INSERT INTO dbo.MedicalCondition(Description) VALUES ('Asthma');
INSERT INTO dbo.MedicalCondition(Description) VALUES ('Cigarette smoking');
INSERT INTO dbo.MedicalCondition(Description) VALUES ('Coronary artery disease');
INSERT INTO dbo.MedicalCondition(Description) VALUES ('Cancer');
INSERT INTO dbo.MedicalCondition(Description) VALUES ('Autoimmune disease');
INSERT INTO dbo.MedicalCondition(Description) VALUES ('Tuberculosis');
INSERT INTO dbo.MedicalCondition(Description) VALUES ('Major surgery');

-------------------------------- Inserting Data Table Bed -----------------------

INSERT INTO dbo.Bed(BedID,CareLevel) VALUES (100, 1);
INSERT INTO dbo.Bed(BedID,CareLevel) VALUES (101, 1);
INSERT INTO dbo.Bed(BedID,CareLevel) VALUES (102, 1);
INSERT INTO dbo.Bed(BedID,CareLevel) VALUES (200, 2);
INSERT INTO dbo.Bed(BedID,CareLevel) VALUES (201, 2);
INSERT INTO dbo.Bed(BedID,CareLevel) VALUES (202, 2);
INSERT INTO dbo.Bed(BedID,CareLevel) VALUES (203, 2);
INSERT INTO dbo.Bed(BedID,CareLevel) VALUES (300, 3);
INSERT INTO dbo.Bed(BedID,CareLevel) VALUES (301, 3);
INSERT INTO dbo.Bed(BedID,CareLevel) VALUES (302, 3);
INSERT INTO dbo.Bed(BedID,CareLevel) VALUES (400, 4);
INSERT INTO dbo.Bed(BedID,CareLevel) VALUES (401, 4);
INSERT INTO dbo.Bed(BedID,CareLevel) VALUES (402, 4);
INSERT INTO dbo.Bed(BedID,CareLevel) VALUES (403, 4);

-------------------------------- Inserting Data Table Address -------------------

INSERT INTO dbo.Address(StreetNumber,City, State, ZipCode) VALUES ('4537 California Ave SW','Seattle','Washington',98116);
INSERT INTO dbo.Address(StreetNumber,City, State, ZipCode) VALUES ('24311 SE 43rd Place','Issaquah','Washington',98029);
INSERT INTO dbo.Address(StreetNumber,City, State, ZipCode) VALUES ('27050 Pacific Hwy','Kent','Washington',98032);
INSERT INTO dbo.Address(StreetNumber,City, State, ZipCode) VALUES ('2999 S Graham Street','Seattle','Washington',98108);
INSERT INTO dbo.Address(StreetNumber,City, State, ZipCode) VALUES ('14040 NE 8th St','Bellevue','Washington',98007);
INSERT INTO dbo.Address(StreetNumber,City, State, ZipCode) VALUES ('4015 Ruston Way','Tacoma','Washington',98402);
INSERT INTO dbo.Address(StreetNumber,City, State, ZipCode) VALUES ('1597 25th Ave NE','Issaquah','Washington',98029);
INSERT INTO dbo.Address(StreetNumber,City, State, ZipCode) VALUES ('9331 NE Colfax St, Ste 203','Portland','Oregon',97220);
INSERT INTO dbo.Address(StreetNumber,City, State, ZipCode) VALUES ('1125 N 100th St','Seattle','Washington',98133);
INSERT INTO dbo.Address(StreetNumber,City, State, ZipCode) VALUES ('22026 20th Ave SE, Suite 101','Bothell','Washington',98021);
INSERT INTO dbo.Address(StreetNumber,City, State, ZipCode) VALUES ('22029 23rd Dr SE','Bothell','Washington',98021);
INSERT INTO dbo.Address(StreetNumber,City, State, ZipCode) VALUES ('4538 Hope Street','Portland','Oregon',97214);

---------------------------------- Inserting Data Table Treatment --------------------------

INSERT INTO dbo.Treatment ([Type] ,Name )
VALUES 
('Steroid','Dexamethasone'),
('Nucleoside analogues','Remdesivir'),
('Antispasmodics','Aminophylline'),
('Immunosuppressant','Cyclosporine'),
('Viral interferon','IFN-α'),
('Respiratory support therapy',' High-flow nasal cannula oxygen therapy'),
('Respiratory support therapy',' Invasive mechanical ventilation'),
('Respiratory support therapy',' Noninvasive ventilation'),
('NSAIDs',' Tylenol'),
('NSAIDs',' Ibuprofen'),
('Antibiotics',' Levofloxacin Hydrochloride'),
('Antibiotics',' Imipenem/cilastatin');

---------------------------------- Inserting Data Table PatientExamination -----------------

INSERT INTO dbo.PatientExamination 
VALUES 
(1,1,'2020/07/21','abnormal','Mild'),
(2,1,'2020/07/21','abnormal','Moderate'),
(4,1,'2020/07/22','Abnormal','Mild'),
(9,1,'2020/07/22','Abnormal','Mild'),
(2,2,'2020/07/25','Abnormal','Mild'),
(6,2,'2020/07/25','Normal',NULL),
(9,3,'2020/07/30','Normal',NULL),
(6,3,'2020/07/30','Abnormal','Mild'),
(2,4,'2020/06/29','Abnormal','Moderate'),
(7,4,'2020/06/29','Abnormal','Mild'),
(9,4,'2020/06/30','Abnormal','Mild'),
(1,5,'2020/08/04','Abnormal','Severe'),
(9,5,'2020/08/04','Abnormal','Moderate'),
(11,5,'2020/08/05','Abnormal','Moderate'),
(3,6,'2020/07/05','Abnormal','Moderate'),
(9,6,'2020/07/05','Abnormal','Moderate'),
(11,6,'2020/07/08','Normal',NULL),
(3,7,'2020/06/30','Abnormal','Mild'),
(5,7,'2020/06/30','Abnormal','Mild'),
(9,7,'2020/06/30','Abnormal','Mild'),
(6,8,'2020/06/18','Abnormal','Moderate'),
(2,8,'2020/06/19','Abnormal','Moderate'),
(9,8,'2020/06/19','Abnormal','Moderate'),
(2,9,'2020/06/13','Abnormal','Severe'),
(4,9,'2020/06/14','Abnormal','Severe'),
(9,9,'2020/06/14','Abnormal','Severe'),
(11,9,'2020/06/16','Abnormal','Moderate'),
(1,10,'2020/06/14','Abnormal','Mild'),
(8,10,'2020/06/14','Abnormal','Mild'),
(9,10,'2020/06/15','Abnormal','Mild'),
(2,11,'2020/06/01','Normal',NULL),
(9,11,'2020/06/01','Normal',NULL),
(2,12,'2020/05/10','Abnormal','Mild'),
(6,12,'2020/05/10','Abnormal','Mild'),
(9,12,'2020/05/11','Abnormal','Mild');

---------------------------------- Inserting Data Table Admission --------------------------

DELETE FROM dbo.Admission 

INSERT INTO dbo.Admission(PatientID, AdmissionDate, DischargeDate, AdmissionType, DischargeType, FrequencyRecord) VALUES (6, '2020-07-01', NULL, 'Regular', NULL, 2);
INSERT INTO dbo.Admission(PatientID, AdmissionDate, DischargeDate, AdmissionType, DischargeType, FrequencyRecord) VALUES (3, '2020-07-22', '2020-07-30', 'Regular', 'Recover', 0);
INSERT INTO dbo.Admission(PatientID, AdmissionDate, DischargeDate, AdmissionType, DischargeType, FrequencyRecord) VALUES (4, '2020-07-30', NULL, 'Regular', NULL, 1);
INSERT INTO dbo.Admission(PatientID, AdmissionDate, DischargeDate, AdmissionType, DischargeType, FrequencyRecord) VALUES (2, '2020-06-28', NULL, 'Regular', NULL, 0);
INSERT INTO dbo.Admission(PatientID, AdmissionDate, DischargeDate, AdmissionType, DischargeType, FrequencyRecord) VALUES (9, '2020-07-24', NULL, 'Regular', NULL, 0);
INSERT INTO dbo.Admission(PatientID, AdmissionDate, DischargeDate, AdmissionType, DischargeType, FrequencyRecord) VALUES (5, '2020-07-02', '2020-07-20', 'Emergency', 'Dead', 0);
INSERT INTO dbo.Admission(PatientID, AdmissionDate, DischargeDate, AdmissionType, DischargeType, FrequencyRecord) VALUES (8, '2020-06-28', '2020-07-08', 'Emergency', 'Recover', 0);
INSERT INTO dbo.Admission(PatientID, AdmissionDate, DischargeDate, AdmissionType, DischargeType, FrequencyRecord) VALUES (10, '2020-06-16', '2020-06-21', 'Regular', 'Recover', 0);
INSERT INTO dbo.Admission(PatientID, AdmissionDate, DischargeDate, AdmissionType, DischargeType, FrequencyRecord) VALUES (12, '2020-06-09', '2020-06-28', 'Regular', 'Recover', 1);
INSERT INTO dbo.Admission(PatientID, AdmissionDate, DischargeDate, AdmissionType, DischargeType, FrequencyRecord) VALUES (11, '2020-06-10', '2020-07-01', 'Regular', 'Recover', 1);
INSERT INTO dbo.Admission(PatientID, AdmissionDate, DischargeDate, AdmissionType, DischargeType, FrequencyRecord) VALUES (7, '2020-07-06', NULL, 'Regular', NULL, 0);
INSERT INTO dbo.Admission(PatientID, AdmissionDate, DischargeDate, AdmissionType, DischargeType, FrequencyRecord) VALUES (1, '2020-06-30', '2020-07-11', 'Emergency', 'Recover', 0);

---------------------------------- Inserting Data Table TreatmentResult ---------------------

INSERT INTO dbo.TreatmentResult(PhysicianID, TreatmentID, PatientID, StartDate ,EndDate ,[Result]) 
VALUES(2,2,1,'2020-07-01', '2020-07-21','Effective'),
(4,5,2,'2020-07-22', '2020-07-30','Effective'),
(11,6,3,'2020-07-30', NULL ,'Effective'),
(12,8,4,'2020-06-28', '2020-07-19','Effective'),
(3,1,5,'2020-07-24', NULL ,'Effective'),
(1,4,6,'2020-07-02', '2020-07-20','Ineffective'),
(5,2,7,'2020-06-28', '2020-07-08','Ineffective'),
(6,10,8,'2020-06-16', '2020-06-21','Effective'),
(8,12,9,'2020-06-09', '2020-06-28','Effective'),
(7,9,10,'2020-06-10', '2020-07-01','Effective'),
(11,7,11,'2020-07-06', '2020-07-30','Ineffective'),
(12,7,12,'2020-06-30', '2020-07-11','Effective');
 
---------------------------------- Inserting Data Table PatientBed --------------------------
DELETE FROM dbo.PatientBed

INSERT INTO dbo.PatientBed(BedID,PatientID,StartDate,EndDate) VALUES (302,1,'2020-07-01',NULL);
INSERT INTO dbo.PatientBed(BedID,PatientID,StartDate,EndDate) VALUES (100,2,'2020-07-22','2020-07-30');
INSERT INTO dbo.PatientBed(BedID,PatientID,StartDate,EndDate) VALUES (101,3,'2020-07-30',NULL);
INSERT INTO dbo.PatientBed(BedID,PatientID,StartDate,EndDate) VALUES (300,4,'2020-06-28',NULL);
INSERT INTO dbo.PatientBed(BedID,PatientID,StartDate,EndDate) VALUES (400,5,'2020-07-24',NULL);
INSERT INTO dbo.PatientBed(BedID,PatientID,StartDate,EndDate) VALUES (102,6,'2020-07-02','2020-07-20');
INSERT INTO dbo.PatientBed(BedID,PatientID,StartDate,EndDate) VALUES (200,7,'2020-06-28','2020-07-08');
INSERT INTO dbo.PatientBed(BedID,PatientID,StartDate,EndDate) VALUES (301,8,'2020-06-16','2020-06-21');
INSERT INTO dbo.PatientBed(BedID,PatientID,StartDate,EndDate) VALUES (401,9,'2020-06-09','2020-06-28');
INSERT INTO dbo.PatientBed(BedID,PatientID,StartDate,EndDate) VALUES (201,10,'2020-06-10','2020-07-01');
INSERT INTO dbo.PatientBed(BedID,PatientID,StartDate,EndDate) VALUES (202,11,'2020-07-06',NULL);
INSERT INTO dbo.PatientBed(BedID,PatientID,StartDate,EndDate) VALUES (203,12,'2020-06-30','2020-07-11');
INSERT INTO dbo.PatientBed(BedID,PatientID,StartDate,EndDate) VALUES (203,12,'2020-07-15',NULL);

---------------------------------- Inserting Data Table PatientAddress -----------------------

INSERT INTO dbo.PatientAddress(PatientID, AddressID) VALUES (1, 2);
INSERT INTO dbo.PatientAddress(PatientID, AddressID) VALUES (3, 3);
INSERT INTO dbo.PatientAddress(PatientID, AddressID) VALUES (4, 9);
INSERT INTO dbo.PatientAddress(PatientID, AddressID) VALUES (7, 11);
INSERT INTO dbo.PatientAddress(PatientID, AddressID) VALUES (2, 4);
INSERT INTO dbo.PatientAddress(PatientID, AddressID) VALUES (8, 12);
INSERT INTO dbo.PatientAddress(PatientID, AddressID) VALUES (9, 5);
INSERT INTO dbo.PatientAddress(PatientID, AddressID) VALUES (10, 6);
INSERT INTO dbo.PatientAddress(PatientID, AddressID) VALUES (5, 1);
INSERT INTO dbo.PatientAddress(PatientID, AddressID) VALUES (6, 10);
INSERT INTO dbo.PatientAddress(PatientID, AddressID) VALUES (11, 7);
INSERT INTO dbo.PatientAddress(PatientID, AddressID) VALUES (12, 8);

---------------------------------- Inserting Data Table MedicalHistory WITH Encrypted CurrentCondition ----------------------
--CLOSE SYMMETRIC KEY TestSymmetric;
--DROP SYMMETRIC KEY TestSymmetric;
--DROP CERTIFICATE CertTest;
--DROP MASTER KEY;

CREATE MASTER KEY 
ENCRYPTION BY PASSWORD ='Pa$$word'

CREATE CERTIFICATE CertTest 
WITH SUBJECT = 'Group Test Certificate',
EXPIRY_DATE = '2026-10-31'

CREATE SYMMETRIC KEY TestSymmetric
    WITH ALGORITHM = AES_128
      ENCRYPTION BY CERTIFICATE CertTest

OPEN SYMMETRIC KEY TestSymmetric
DECRYPTION BY CERTIFICATE CertTest

INSERT
INTO dbo.MedicalHistory 
(PatientID, MedicalConditionID, StartDate, EndDate, CurrentCondition) 
VALUES
(2, 1, '2009-06-09', '2019-09-30', EncryptByKey(Key_GUID(N'TestSymmetric'), CONVERT(VARBINARY(250),'Cured')))

INSERT 
INTO MedicalHistory 
(MedicalConditionID, PatientID, StartDate, CurrentCondition) 
VALUES
(3, 2,'2017-07-13', EncryptByKey(Key_GUID(N'TestSymmetric'), CONVERT(VARBINARY(250),'Continue')))

INSERT 
INTO MedicalHistory 
(MedicalConditionID, PatientID, StartDate, EndDate, CurrentCondition) 
VALUES
(10, 3, '2016-11-12', '2017-12-20', EncryptByKey(Key_GUID(N'TestSymmetric'), CONVERT(VARBINARY(250),'Continue')))

INSERT 
INTO MedicalHistory 
(MedicalConditionID, PatientID, StartDate, CurrentCondition) 
VALUES
(3, 4, '1995-09-17', EncryptByKey(Key_GUID(N'TestSymmetric'), CONVERT(VARBINARY(250),'Continue')))

INSERT 
INTO MedicalHistory 
(MedicalConditionID, PatientID, StartDate, EndDate, CurrentCondition) 
VALUES
(4, 5, '1963-08-30','2000-04-22', EncryptByKey(Key_GUID(N'TestSymmetric'), CONVERT(VARBINARY(250),'Cured')))

INSERT 
INTO MedicalHistory 
(MedicalConditionID, PatientID, StartDate, CurrentCondition) 
VALUES
(7, 6, '2001-10-10', EncryptByKey(Key_GUID(N'TestSymmetric'), CONVERT(VARBINARY(250),'Continue')))

INSERT 
INTO MedicalHistory 
(MedicalConditionID, PatientID, StartDate, CurrentCondition) 
VALUES
(12, 8, '2017-12-25', EncryptByKey(Key_GUID(N'TestSymmetric'), CONVERT(VARBINARY(250),'Continue')))

INSERT 
INTO MedicalHistory 
(MedicalConditionID, PatientID, StartDate, EndDate,CurrentCondition) 
VALUES
(6, 10, '2003-02-24', '2008-02-28', EncryptByKey(Key_GUID(N'TestSymmetric'), CONVERT(VARBINARY(250),'Cured')))

INSERT 
INTO MedicalHistory 
(MedicalConditionID, PatientID, StartDate, CurrentCondition) 
VALUES
(5, 11, '2011-06-18', EncryptByKey(Key_GUID(N'TestSymmetric'), CONVERT(VARBINARY(250),'Continue')))

INSERT 
INTO MedicalHistory 
(MedicalConditionID, PatientID, StartDate, EndDate, CurrentCondition) 
VALUES
(2, 1, '2014-09-07', '2014-09-21', EncryptByKey(Key_GUID(N'TestSymmetric'), CONVERT(VARBINARY(250),'Continue')))

--------------------------   Views   --------------------------

-- The view is to track the geographical distribution of COVID-19 patients to prevent the spread.

CREATE VIEW V_PatientDistribution
AS
SELECT 
p.PatientID, p.sex, p.age , a.City, a.State , a.ZipCode, ad.AdmissionDate
FROM Patient p
JOIN PatientAddress pa ON p.PatientID = pa.PatientID
JOIN Address a ON pa.AddressID = a.AddressID
JOIN Admission ad ON p.PatientID = ad.PatientID

-------

-- The view is to look up for unoccupied beds to effectively arrange a bed for Covid-19 patients.

CREATE VIEW V_UnoccupiedBeds
AS
SELECT t.BedID, CareLevel
FROM 
(
(SELECT DISTINCT BedID FROM BED 
EXCEPT 
SELECT DISTINCT BedID FROM PatientBed )
union
(SELECT DISTINCT BedID FROM PatientBed 
EXCEPT
SELECT DISTINCT BedID FROM PatientBed WHERE EndDate is NULL)
) t
JOIN Bed b
ON t.BedID = b.BedID

SELECT * FROM V_UnoccupiedBeds

-------

-- The view is to observe the relationships between the medical conditions and the patients prognosis.

CREATE VIEW V_PatientMedicalConditionsAndPrognosis
AS
SELECT
p.PatientFirstName, p.PatientLastName
mh.CurrentCondition, mc.Description,
ad.DischargeType
FROM patient p
JOIN MedicalHistory mh ON p.PatientID = mh.PatientID
JOIN MedicalCondition mc ON mh.MedicalConditionID = mc.MedicalConditionID
JOIN Admission ad ON p.PatientID = ad.PatientID;

------

-- The View is to track the physicians’ treatments and the effectiveness.

CREATE VIEW V_PhysicianAndTreatmentEffect
AS
SELECT
ph.PhysicianFirstName, ph.PhysicianLastName, ph.Specialty,
t.name,
tr.result
FROM physician ph
JOIN TreatmentResult tr ON ph.PhysicianID = tr.PhysicianID
JOIN Treatment t ON tr.treatmentID = t.treatmentID;

-------------------------- Table level constraints based on function ----------------

-----Patients < 12 years old are not admitted by the hospital due to the lack of the specific equipments

-- Drop function checkAge;

CREATE FUNCTION CheckAge (@PatientID INT)
RETURNS SMALLINT
AS
BEGIN
	DECLARE @Age SMALLINT = 0;
	SELECT @Age = (SELECT DATEDIFF(hour, BirthDate, GETDATE())/8766 
	               FROM Patient
				   WHERE PatientID = @PatientID)
	RETURN @Age;
END;

---------------------------------------Trigger addDate-----------------------------------------
--DROP TRIGGER addDate

CREATE TRIGGER addDate ON dbo.PatientBed 
AFTER UPDATE 

AS
   IF EXISTS 
      (
       SELECT * 
       FROM Inserted i
       JOIN dbo.PatientBed pb 
          ON i.PatientID = pb.PatientID 
       WHERE pb.EndDate IS NOT NULL
      )
BEGIN

UPDATE dbo.Admission 
SET DischargeDate = i.EndDate  
FROM Inserted i
JOIN dbo.Admission a
	ON i.PatientID = a.PatientID 
END


---------------------------------------Trigger checkBedId-----------------------------------------
--DROP TRIGGER checkBedId

CREATE TRIGGER checkBedId ON GROUP6_COVID19_HOSPITAL_DBMS.dbo.PatientBed 

INSTEAD OF INSERT 

AS
IF NOT EXISTS(SELECT * FROM GROUP6_COVID19_HOSPITAL_DBMS.dbo.Bed b WHERE BedID =(SELECT BedID FROM INSERTED))
  BEGIN
    ROLLBACK TRANSACTION
     RAISERROR('The BedId Is Not Exist!',16,1)
  END
ELSE
  BEGIN
    INSERT INTO GROUP6_COVID19_HOSPITAL_DBMS.dbo.PatientBed(BedID,PatientID,StartDate,EndDate)
    select BedID,PatientID,StartDate,EndDate from inserted
  END

  







