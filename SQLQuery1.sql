-- Set the active database
USE Hospital_Records;
GO

-- Verify all 5 tables are present
SELECT TABLE_NAME 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_NAME IN ('encounters', 'organizations', 'patients', 'payers', 'procedures');

SELECT 'patients' AS TableName, COUNT(*) AS RecordCount FROM patients
UNION ALL
SELECT 'encounters', COUNT(*) FROM encounters
UNION ALL
SELECT 'procedures', COUNT(*) FROM procedures
UNION ALL
SELECT 'payers', COUNT(*) FROM payers
UNION ALL
SELECT 'organizations', COUNT(*) FROM organizations;

-- Check the overall timeline of hospital activity
SELECT 
    MIN(Start) AS Earliest_Encounter, 
    MAX(Stop) AS Latest_Encounter,
    COUNT(Id) AS Total_Encounters
FROM encounters;

-- Check for seasonality or data gaps by year
SELECT 
    YEAR(Start) AS EncounterYear, 
    COUNT(*) AS Yearly_Volume
FROM encounters
GROUP BY YEAR(Start)
ORDER BY EncounterYear;

-- Checking for missing critical demographics and healthcare data
SELECT 
    (SELECT COUNT(*) FROM patients WHERE Gender IS NULL) AS Missing_Gender,
    (SELECT COUNT(*) FROM patients WHERE Race IS NULL) AS Missing_Race,
    (SELECT COUNT(*) FROM encounters WHERE EncounterClass IS NULL) AS Missing_Class,
    (SELECT COUNT(*) FROM encounters WHERE Total_Claim_Cost IS NULL) AS Missing_Cost;

    -- Explore EncounterClass distribution 
SELECT EncounterClass, COUNT(*) AS Frequency
FROM encounters
GROUP BY EncounterClass
ORDER BY Frequency DESC;

-- Explore Gender and Race demographics
SELECT Gender, Race, COUNT(*) AS PatientCount
FROM patients
GROUP BY Gender, Race;

-- Validate the Admission Definition
SELECT 
    EncounterClass,
    AVG(DATEDIFF(DAY, Start, Stop)) AS Avg_LOS_Days,
    MAX(DATEDIFF(DAY, Start, Stop)) AS Max_LOS_Days,
    SUM(CASE WHEN DATEDIFF(DAY, Start, Stop) >= 1 THEN 1 ELSE 0 END) AS Actual_Overnight_Stays
FROM encounters
GROUP BY EncounterClass;

-- Deep Dive: Finding 'Hidden' Admissions
-- This identifies encounters that ARE NOT labeled 'Inpatient' but lasted overnight.
SELECT 
    EncounterClass, 
    COUNT(*) AS Total_Encounters,
    SUM(CASE WHEN DATEDIFF(hour, Start, Stop) >= 24 THEN 1 ELSE 0 END) AS Stays_Over_24Hrs,
    AVG(Total_Claim_Cost) AS Avg_Cost
FROM encounters
WHERE EncounterClass != 'Inpatient'
GROUP BY EncounterClass
HAVING SUM(CASE WHEN DATEDIFF(hour, Start, Stop) >= 24 THEN 1 ELSE 0 END) > 0;

USE Hospital_Records;
GO

SELECT 
    EncounterClass,
    COUNT(*) AS Total_Encounters,
    SUM(CASE WHEN DATEDIFF(HOUR, Start, Stop) >= 24 THEN 1 ELSE 0 END) AS Actual_Overnight_Stays,
    CAST(SUM(CASE WHEN DATEDIFF(HOUR, Start, Stop) >= 24 THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 AS Pct_Misclassified
FROM encounters
WHERE EncounterClass IN ('Ambulatory', 'Emergency', 'Urgentcare', 'Wellness')
GROUP BY EncounterClass
ORDER BY Actual_Overnight_Stays DESC;

-- Identify patients with encounters starting on the same day another ended
SELECT 
    e1.Patient AS Patient_ID,
    e1.Id AS First_Encounter,
    e2.Id AS Consecutive_Encounter,
    e1.Stop AS First_End,
    e2.Start AS Second_Start
FROM encounters e1
JOIN encounters e2 ON e1.Patient = e2.Patient 
    AND e1.Id <> e2.Id
WHERE CAST(e1.Stop AS DATE) = CAST(e2.Start AS DATE)
ORDER BY e1.Patient;

SELECT 
    p.Name AS Payer_Name,
    COUNT(e.Id) AS Encounter_Count,
    AVG(e.Total_Claim_Cost) AS Avg_Total_Cost,
    AVG(e.Payer_Coverage) AS Avg_Payer_Paid,
    AVG(e.Total_Claim_Cost - e.Payer_Coverage) AS Avg_Patient_Out_of_Pocket,
    AVG((e.Payer_Coverage / NULLIF(e.Total_Claim_Cost, 0)) * 100) AS Avg_Coverage_Pct
FROM encounters e
JOIN payers p ON e.Payer = p.Id
GROUP BY p.Name
ORDER BY Avg_Coverage_Pct ASC;