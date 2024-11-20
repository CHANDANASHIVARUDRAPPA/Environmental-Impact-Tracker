CREATE DATABASE EnvironmentalImpactTracker;
USE EnvironmentalImpactTracker;

-- Create User table
CREATE TABLE User (
    User_ID INT AUTO_INCREMENT PRIMARY KEY,
    Name VARCHAR(50),
    Email VARCHAR(50),
    Location VARCHAR(50),
    Password VARCHAR(50),
    RoleRank VARCHAR(20)
);

-- Create Electricity Logs table
CREATE TABLE Electricity_Logs (
    Log_ID INT AUTO_INCREMENT PRIMARY KEY,
    User_ID INT,
    Month VARCHAR(20),
    Electricity_Usage DECIMAL(10, 2),
    Electricity_Cost DECIMAL(10, 2),
    Log_Date DATE,
    FOREIGN KEY (User_ID) REFERENCES User(User_ID)
);

-- Create Water Logs table
CREATE TABLE Water_Logs (
    Log_ID INT AUTO_INCREMENT PRIMARY KEY,
    User_ID INT,
    Month VARCHAR(20),
    Water_Usage DECIMAL(10, 2),
    Water_Cost DECIMAL(10, 2),
    Log_Date DATE,
    FOREIGN KEY (User_ID) REFERENCES User(User_ID)
);

-- Create Rankings table
CREATE TABLE Rankings (
    Ranking_ID INT AUTO_INCREMENT PRIMARY KEY,
    User_ID INT,
    Month VARCHAR(20),
    Total_Consumption DECIMAL(10, 2),
    Rank_Position INT,
    FOREIGN KEY (User_ID) REFERENCES User(User_ID)
);

-- Create Suggestions table
CREATE TABLE Suggestions (
    Suggestion_ID INT AUTO_INCREMENT PRIMARY KEY,
    User_ID INT,
    Resource_Type VARCHAR(20),
    Suggestion_Text TEXT,
    Threshold_Exceeded BOOLEAN,
    FOREIGN KEY (User_ID) REFERENCES User(User_ID)
);

-- Create Reports table
CREATE TABLE Reports (
    Report_ID INT AUTO_INCREMENT PRIMARY KEY,
    User_ID INT,
    Report_Content TEXT,
    Generated_Date DATE,
    FOREIGN KEY (User_ID) REFERENCES User(User_ID)
);

-- Create Admin table
CREATE TABLE Admin (
    Admin_ID INT AUTO_INCREMENT PRIMARY KEY,
    User_ID INT,
    Permissions VARCHAR(50),
    FOREIGN KEY (User_ID) REFERENCES User(User_ID)
);

-- Create Threshold table
CREATE TABLE Threshold (
    Threshold_ID INT AUTO_INCREMENT PRIMARY KEY,
    Resource_Type VARCHAR(20),
    Threshold_Value DECIMAL(10, 2),
    Set_Date DATE
);

--insertion
INSERT INTO reports (User_ID, Report_Content, Generated_Date, Created_At)
VALUES (1, 'This is the first environmental impact report. It focuses on the usage of electricity and water.', '2024-11-12', NOW());
INSERT INTO reports (User_ID, Report_Content, Generated_Date, Created_At)
VALUES (2, 'This report contains insights into water usage trends and suggestions for reduction in the next quarter.', '2024-11-11', NOW());
INSERT INTO reports (User_ID, Report_Content, Generated_Date, Created_At)
VALUES (3, 'The electricity consumption analysis for the last year has been generated. Recommendations are made to reduce the usage further.', '2024-10-30', NOW());
INSERT INTO reports (User_ID, Report_Content, Generated_Date, Created_At)
VALUES (4, 'This report details the energy-saving efforts and their environmental impact over the past six months.', '2024-09-15', NOW());
INSERT INTO reports (User_ID, Report_Content, Generated_Date, Created_At)
VALUES (5, 'An analysis of the last quarter, focusing on water-saving measures and their effects on reducing the carbon footprint.', '2024-08-20', NOW());

Insert initial users
INSERT INTO User (Name, Email, Password, Location, RoleRank)
VALUES ('John Doe', 'john@example.com', 'password123', 'New York', 'User'),
       ('Jane Smith', 'jane@example.com', 'password456', 'Los Angeles', 'User'),
       ('Admin User', 'admin@example.com', 'adminpass', 'New York', 'Admin');

Insert initial admin
INSERT INTO Admin (User_ID, Permissions)
VALUES ((SELECT User_ID FROM User WHERE Email = 'admin@example.com'), 'ALL');

Insert initial water logs
INSERT INTO Water_Logs (User_ID, Month, Water_Usage, Water_Cost, Log_Date)
VALUES ((SELECT User_ID FROM User WHERE Email = 'john@example.com'), 'January', 100, 30, '2024-01-15'),
       ((SELECT User_ID FROM User WHERE Email = 'jane@example.com'), 'January', 150, 45, '2024-01-20');

Insert initial electricity logs
INSERT INTO Electricity_Logs (User_ID, Month, Electricity_Usage, Electricity_Cost, Log_Date)
VALUES ((SELECT User_ID FROM User WHERE Email = 'john@example.com'), 'January', 200, 50, '2024-01-10'),
       ((SELECT User_ID FROM User WHERE Email = 'jane@example.com'), 'January', 250, 60, '2024-01-25');

Insert initial thresholds
INSERT INTO Threshold (Resource_Type, Threshold_Value, Set_Date)
VALUES ('Electricity', 500, '2024-01-01'),
       ('Water', 300, '2024-01-01');

--procedures
DELIMITER $$
CREATE PROCEDURE CheckThreshold(IN user_id INT, IN resource_type VARCHAR(255))
BEGIN
DECLARE total_usage FLOAT DEFAULT 0;
DECLARE threshold_value FLOAT DEFAULT 0;
    -- Determine the total usage based on resource type
     IF resource_type = 'Electricity' THEN
         SELECT SUM(Electricity_Usage) INTO total_usage
         FROM Electricity_Logs
         WHERE User_ID = user_id;
     ELSE
         SELECT SUM(Water_Usage) INTO total_usage
         FROM Water_Logs
         WHERE User_ID = user_id;
     END IF;

     -- Fetch the threshold value for the specified resource
     SELECT Threshold_Value INTO threshold_value
     FROM Threshold
     WHERE Resource_Type = resource_type;

     -- Check if usage exceeds the threshold and raise an error if so
     IF total_usage > threshold_value THEN
         SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Threshold exceeded. Please reduce usage.';
     END IF;
 END$$
 
--stored procedures2
DELIMITER //

CREATE PROCEDURE GenerateUserReport(IN user_id INT)
BEGIN
    DECLARE total_water_usage FLOAT DEFAULT 0;
    DECLARE total_electricity_usage FLOAT DEFAULT 0;
    DECLARE total_usage FLOAT DEFAULT 0;
    DECLARE report_date DATE;

    SET report_date = CURDATE();

    -- Calculate the total water usage
    SELECT COALESCE(SUM(Water_Usage), 0)
    INTO total_water_usage
    FROM Water_Logs
    WHERE User_ID = user_id;

    -- Calculate the total electricity usage
    SELECT COALESCE(SUM(Electricity_Usage), 0)
    INTO total_electricity_usage
    FROM Electricity_Logs
    WHERE User_ID = user_id;

    -- Calculate the total usage
    SET total_usage = total_water_usage + total_electricity_usage;

    -- Insert the report into the Report table
    INSERT INTO Report (User_ID, Report_Date, Water_Usage, Electricity_Usage, Total_Usage)
    VALUES (user_id, report_date, total_water_usage, total_electricity_usage, total_usage);
END //

DELIMITER ;
--TRIGGER1
DELIMITER //
CREATE TRIGGER UpdateRankingsAfterInsertElectricityLog
AFTER INSERT ON Electricity_Logs
FOR EACH ROW
BEGIN
    DECLARE total_consumption FLOAT;
    SELECT SUM(Electricity_Usage) INTO total_consumption
    FROM Electricity_Logs
    WHERE User_ID = NEW.User_ID AND Month = NEW.Month;
    
    IF EXISTS (SELECT * FROM Rankings WHERE User_ID = NEW.User_ID AND Month = NEW.Month) THEN
        UPDATE Rankings
        SET Total_Consumption = total_consumption
        WHERE User_ID = NEW.User_ID AND Month = NEW.Month;
    ELSE
        INSERT INTO Rankings (User_ID, Rank_Position, Month, Total_Consumption)
        VALUES (NEW.User_ID, NULL, NEW.Month, total_consumption);
    END IF;
END //
--TRIGGER2
CREATE TRIGGER UpdateRankingsAfterInsertWaterLog
AFTER INSERT ON Water_Logs
FOR EACH ROW
BEGIN
    DECLARE total_consumption FLOAT;
    SELECT SUM(Water_Usage) INTO total_consumption
    FROM Water_Logs
    WHERE User_ID = NEW.User_ID AND Month = NEW.Month;
    
    IF EXISTS (SELECT * FROM Rankings WHERE User_ID = NEW.User_ID AND Month = NEW.Month) THEN
        UPDATE Rankings
        SET Total_Consumption = total_consumption
        WHERE User_ID = NEW.User_ID AND Month = NEW.Month;
    ELSE
        INSERT INTO Rankings (User_ID, Rank_Position, Month, Total_Consumption)
        VALUES (NEW.User_ID, NULL, NEW.Month, total_consumption);
    END IF;
END //
DELIMITER ;

--FUNCTION1
DELIMITER //
CREATE FUNCTION CheckWaterUsageThreshold(user_id INT, month VARCHAR(255))
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total_water_usage FLOAT;
    SET total_water_usage = (
        SELECT SUM(Water_Usage)
        FROM Water_Logs
        WHERE User_ID = user_id AND Month = month
    );
    RETURN total_water_usage > 50;
END //

DELIMITER ;

--FUNCTION2
DELIMITER //
CREATE FUNCTION CheckElectricityUsageThreshold(user_id INT, month VARCHAR(255))
RETURNS BOOLEAN
DETERMINISTIC
READS SQL DATA
BEGIN
    DECLARE total_electricity_usage FLOAT;
    SET total_electricity_usage = (
        SELECT SUM(Electricity_Usage)
        FROM Electricity_Logs
        WHERE User_ID = user_id AND Month = month
    );
    RETURN total_electricity_usage > 75;
END //
DELIMITER ;

--QUERIES
--Query 1: Get Monthly Water and Electricity Usage for Each User 
SELECT u.Name AS User_Name, 
       u.Email, 
       COALESCE(wl.Month, el.Month) AS Month, 
       IFNULL(wl.Water_Usage, 0) AS Water_Usage, 
       IFNULL(el.Electricity_Usage, 0) AS Electricity_Usage, 
       (IFNULL(wl.Water_Usage, 0) + IFNULL(el.Electricity_Usage, 0)) AS Total_Usage
FROM user u
LEFT JOIN water_logs wl ON u.User_ID = wl.User_ID
LEFT JOIN electricity_logs el ON u.User_ID = el.User_ID AND wl.Month = el.Month
ORDER BY u.Name, Month;

--Query 2: List Admins and Their Permissions in a Specific Location 
SELECT a.Admin_ID, 
       u.Name AS Admin_Name, 
       u.Location, 
       a.Permissions
FROM admin a
JOIN user u ON a.User_ID = u.User_ID
WHERE u.RoleRank = 'Admin' AND u.Location = 'New York';

--Query 3: Get Leaderboard with Total Consumption for the Top 5 Users 
SELECT r.User_ID, 
u.Name AS User_Name, 
u.Email, 
SUM(r.Total_Consumption) AS Total_Usage, 
ROW_NUMBER() OVER(ORDER BY SUM(r.Total_Consumption) DESC) AS Rank_Position 
FROM rankings r 
JOIN user u ON r.User_ID = u.User_ID 
GROUP BY r.User_ID, u.Name, u.Email 
ORDER BY Total_Usage DESC 
LIMIT 5;

--Query 4: Generate Reports on Resource Usage for Each User by Month
SELECT u.User_ID, 
u.Name AS User_Name, 
IFNULL(wl.Month, el.Month) AS Month, 
IFNULL(wl.Water_Usage, 0) AS Water_Usage, 
IFNULL(el.Electricity_Usage, 0) AS Electricity_Usage, 
(IFNULL(wl.Water_Usage, 0) + IFNULL(el.Electricity_Usage, 0)) AS Total_Usage 
FROM user u 
LEFT JOIN water_logs wl ON u.User_ID = wl.User_ID 
LEFT JOIN electricity_logs el ON u.User_ID = el.User_ID 
ORDER BY u.User_ID, Month;

--Query5: High Resource Usage per User 
SELECT u.Name AS User_Name, 
u.Email, 
wl.Month AS Water_Month, 
wl.Water_Usage, 
el.Month AS Electricity_Month, 
el.Electricity_Usage, 
(IFNULL(wl.Water_Usage, 0) + IFNULL(el.Electricity_Usage, 0)) AS Total_Usage, 
CASE 
WHEN IFNULL(wl.Water_Usage, 0) > (SELECT Threshold_Value FROM threshold WHERE Resource_Type = 'Water') THEN 'Water Exceeded' 
WHEN IFNULL(el.Electricity_Usage, 0) > (SELECT Threshold_Value FROM threshold WHERE Resource_Type = 'Electricity') THEN 'Electricity Exceeded' 
ELSE 'Within Limits' 
END AS Threshold_Status 
FROM user u 
LEFT JOIN water_logs wl ON u.User_ID = wl.User_ID 
LEFT JOIN electricity_logs el ON u.User_ID = el.User_ID 
WHERE (IFNULL(wl.Water_Usage, 0) > (SELECT Threshold_Value FROM threshold WHERE Resource_Type = 'Water') 
OR IFNULL(el.Electricity_Usage, 0) > (SELECT Threshold_Value FROM threshold WHERE Resource_Type = 'Electricity')) 
ORDER BY u.Name, wl.Month, el.Month;

--Create a View for User's Total Consumption
CREATE VIEW UserTotalConsumption AS
SELECT 
    u.User_ID,
    u.Name,
    u.Email,
    COALESCE(SUM(e.Electricity_Usage), 0) AS Total_Electricity_Usage,
    COALESCE(SUM(w.Water_Usage), 0) AS Total_Water_Usage,
    COALESCE(SUM(e.Electricity_Usage), 0) + COALESCE(SUM(w.Water_Usage), 0) AS Total_Consumption
FROM 
    User u
LEFT JOIN 
    Electricity_Logs e ON u.User_ID = e.User_ID
LEFT JOIN 
    Water_Logs w ON u.User_ID = w.User_ID
GROUP BY 
    u.User_ID, u.Name, u.Email;

--Create a View for Monthly Rankings
CREATE VIEW MonthlyRankings AS
SELECT 
    r.User_ID,
    u.Name,
    r.Month,
    r.Total_Consumption,
    r.Rank_Position
FROM 
    Rankings r
JOIN 
    User u ON r.User_ID = u.User_ID
ORDER BY 
    r.Month, r.Rank_Position ASC;


--Create a View for Threshold Exceeding Users
CREATE VIEW ThresholdExceeders AS
SELECT 
    u.User_ID,
    u.Name,
    t.Resource_Type,
    t.Threshold_Value,
    COALESCE(SUM(e.Electricity_Usage), 0) AS Electricity_Usage,
    COALESCE(SUM(w.Water_Usage), 0) AS Water_Usage,
    CASE 
        WHEN t.Resource_Type = 'Electricity' AND COALESCE(SUM(e.Electricity_Usage), 0) > t.Threshold_Value THEN 'Exceeded'
        WHEN t.Resource_Type = 'Water' AND COALESCE(SUM(w.Water_Usage), 0) > t.Threshold_Value THEN 'Exceeded'
        ELSE 'Within Limit'
    END AS Status
FROM 
    User u
LEFT JOIN 
    Electricity_Logs e ON u.User_ID = e.User_ID
LEFT JOIN 
    Water_Logs w ON u.User_ID = w.User_ID
JOIN 
    Threshold t ON (t.Resource_Type = 'Electricity' OR t.Resource_Type = 'Water')
GROUP BY 
    u.User_ID, u.Name, t.Resource_Type, t.Threshold_Value;


--Create a View for Reports Overview
CREATE VIEW ReportsOverview AS
SELECT 
    r.Report_ID,
    u.User_ID,
    u.Name,
    r.Report_Content,
    r.Generated_Date
FROM 
    Reports r
JOIN 
    User u ON r.User_ID = u.User_ID
ORDER BY 
    r.Generated_Date DESC;

--Create a View for Suggestions
CREATE VIEW UserSuggestions AS
SELECT 
    s.Suggestion_ID,
    u.User_ID,
    u.Name,
    s.Resource_Type,
    s.Suggestion_Text,
    s.Threshold_Exceeded
FROM 
    Suggestions s
JOIN 
    User u ON s.User_ID = u.User_ID
WHERE 
    s.Threshold_Exceeded = TRUE
ORDER BY 
    s.Resource_Type;


-- Create a View for Admin Activity
CREATE VIEW AdminActivity AS
SELECT 
    a.Admin_ID,
    u.User_ID,
    u.Name,
    a.Permissions
FROM 
    Admin a
JOIN 
    User u ON a.User_ID = u.User_ID;


--Grant All Privileges to Admin
GRANT ALL PRIVILEGES ON EnvironmentalImpactTracker.* TO 'admin_user'@'localhost' IDENTIFIED BY 'admin_password';

-- Grant Limited Permissions to Regular Users
GRANT SELECT, INSERT, UPDATE ON EnvironmentalImpactTracker.User TO 'regular_user'@'localhost' IDENTIFIED BY 'user_password';
GRANT SELECT ON EnvironmentalImpactTracker.Reports TO 'regular_user'@'localhost';

-- Grant Permissions for Reporting Views
GRANT SELECT ON EnvironmentalImpactTracker.ReportsOverview TO 'report_user'@'localhost' IDENTIFIED BY 'report_password';

--Grant Permissions for Procedure Execution
GRANT EXECUTE ON PROCEDURE EnvironmentalImpactTracker.GenerateUserReport TO 'procedure_user'@'localhost' IDENTIFIED BY 'procedure_password';


--Grant Trigger Permissions
GRANT TRIGGER ON EnvironmentalImpactTracker.* TO 'trigger_user'@'localhost' IDENTIFIED BY 'trigger_password';

--Revoke Permissions
REVOKE SELECT, INSERT ON EnvironmentalImpactTracker.User FROM 'regular_user'@'localhost';




