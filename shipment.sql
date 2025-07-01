DROP DATABASE IF EXISTS mydb;
DROP DATABASE IF EXISTS ddata;

CREATE DATABASE ddata;
USE ddata;
CREATE TABLE Customer (
    CustomerID INT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    ContactInfo TEXT,
    AccountType VARCHAR(50)  -- 'Contract' or 'One-off'
);

-- =====================
-- 2. ADDRESS
-- =====================
CREATE TABLE Address (
    AddressID INT PRIMARY KEY,
    Street VARCHAR(200),
    City VARCHAR(100),
    StateProvince VARCHAR(100),
    Country VARCHAR(100),
    PostalCode VARCHAR(20)
);

-- =====================
-- 3. RECIPIENT
-- =====================
CREATE TABLE Recipient (
    RecipientID INT PRIMARY KEY,
    Name VARCHAR(100) NOT NULL,
    ContactInfo TEXT,
    AddressID INT,
    FOREIGN KEY (AddressID) REFERENCES Address(AddressID)
);

-- =====================
-- 4. SERVICE_TYPE (Delivery Timeliness)
-- =====================
CREATE TABLE ServiceType (
    ServiceCode VARCHAR(10) PRIMARY KEY,  -- e.g. 'OVERNIGHT','ONE_DAY','STANDARD'
    Description VARCHAR(100),
    DeliveryDays INT  -- number of days until promised delivery
);

-- =====================
-- 5. SHIPMENT
-- =====================
CREATE TABLE Shipment (
    ShipmentID INT PRIMARY KEY,
    CustomerID INT,
    SenderAddressID INT,
    RecipientID INT,
    ServiceCode VARCHAR(10),
    ShipmentDate DATE,
    PromiseDate DATE,
    FOREIGN KEY (CustomerID) REFERENCES Customer(CustomerID),
    FOREIGN KEY (SenderAddressID) REFERENCES Address(AddressID),
    FOREIGN KEY (RecipientID) REFERENCES Recipient(RecipientID),
    FOREIGN KEY (ServiceCode) REFERENCES ServiceType(ServiceCode)
);

-- =====================
-- 6. PACKAGE
-- =====================
CREATE TABLE Package (
    PackageID INT PRIMARY KEY,
    ShipmentID INT,
    PackageType VARCHAR(50),   -- e.g. 'Box','Envelope','Pallet'
    Weight DECIMAL(10,2),
    Dimensions VARCHAR(50),     -- e.g. '10x8x4'
    ContentDescription TEXT,
    HazardClass VARCHAR(50),    -- nullable
    CustomsValue DECIMAL(10,2), -- nullable
    CustomsCurrency VARCHAR(10),-- nullable
    FOREIGN KEY (ShipmentID) REFERENCES Shipment(ShipmentID)
);

-- =====================
-- 7. CUSTOMS_DECLARATION
-- =====================
CREATE TABLE CustomsDeclaration (
    DeclarationID INT PRIMARY KEY,
    PackageID INT,
    ContentDescription TEXT,
    Value DECIMAL(10,2),
    Currency VARCHAR(10),
    DeclarationDate DATE,
    FOREIGN KEY (PackageID) REFERENCES Package(PackageID)
);

-- =====================
-- 8. HAZARDOUS_MATERIAL
-- =====================
CREATE TABLE HazardousMaterial (
    HMID INT PRIMARY KEY,
    PackageID INT,
    HazardClass VARCHAR(50),
    UNNumber VARCHAR(20),
    HandlingInstructions TEXT,
    FOREIGN KEY (PackageID) REFERENCES Package(PackageID)
);

-- =====================
-- 9. PAYMENT_METHOD
-- =====================
CREATE TABLE PaymentMethod (
    PaymentMethodID INT PRIMARY KEY,
    MethodName VARCHAR(50),    -- e.g. 'CreditCard','Prepaid','Account'
    Details TEXT               -- e.g. last4 digits or account terms
);

-- =====================
-- 10. PAYMENT
-- =====================
CREATE TABLE Payment (
    PaymentID INT PRIMARY KEY,
    ShipmentID INT,
    PaymentMethodID INT,
    Amount DECIMAL(10,2),
    Timestamp DATETIME,
    FOREIGN KEY (ShipmentID) REFERENCES Shipment(ShipmentID),
    FOREIGN KEY (PaymentMethodID) REFERENCES PaymentMethod(PaymentMethodID)
);

-- =====================
-- 11. VEHICLE
-- =====================
CREATE TABLE Vehicle (
    VehicleID INT PRIMARY KEY,
    Type VARCHAR(50),            -- e.g. 'Truck','Plane'
    Identifier VARCHAR(100),     -- e.g. '1721'
    Capacity VARCHAR(100),       -- e.g. '1000kg'
    Status VARCHAR(50)           -- e.g. 'Active','Maintenance'
);

-- =====================
-- 12. FACILITY
-- =====================
CREATE TABLE Facility (
    FacilityID INT PRIMARY KEY,
    Name VARCHAR(100),
    AddressID INT,
    FacilityType VARCHAR(50),    -- e.g. 'Hub','Depot'
    FOREIGN KEY (AddressID) REFERENCES Address(AddressID)
);

-- =====================
-- 13. ROUTE_SEGMENT (Route Checkpoints)
-- =====================
CREATE TABLE RouteSegment (
    SegmentID INT PRIMARY KEY,
    ShipmentID INT NOT NULL,
    SequenceNumber INT NOT NULL,     -- order of the segment in the route (1=origin->CP1, 2=CP1->CP2, 3=CP2->CP3, 4=CP3->destination)
    FromFacilityID INT NOT NULL,     -- checkpoint or origin facility
    ToFacilityID INT NOT NULL,       -- next checkpoint or destination facility
    ExpectedDeparture DATETIME NOT NULL,
    ExpectedArrival DATETIME NOT NULL,
    FOREIGN KEY (ShipmentID) REFERENCES Shipment(ShipmentID) ON DELETE CASCADE,
    FOREIGN KEY (FromFacilityID) REFERENCES Facility(FacilityID),
    FOREIGN KEY (ToFacilityID) REFERENCES Facility(FacilityID),
    UNIQUE (ShipmentID, SequenceNumber)  -- ensure unique checkpoint order
);

-- Example segments represent 4 checkpoints:
--  1: Origin -> Checkpoint A
--  2: Checkpoint A -> Checkpoint B
--  3: Checkpoint B -> Checkpoint C
--  4: Checkpoint C -> Final Destination

-- =====================
-- 14. TRACKING_EVENT
-- =====================
CREATE TABLE TrackingEvent (
    EventID INT PRIMARY KEY,
    PackageID INT,
    Timestamp DATETIME,
    VehicleID INT,               -- nullable if at facility
    FacilityID INT,              -- nullable if on vehicle
    StatusDetail TEXT,
    FOREIGN KEY (PackageID) REFERENCES Package(PackageID),
    FOREIGN KEY (VehicleID) REFERENCES Vehicle(VehicleID),
    FOREIGN KEY (FacilityID) REFERENCES Facility(FacilityID)
);
 
--Customer Who Shipped the Most Packages in the Past Year

SELECT c.CustomerID,
       c.Name,
       COUNT(p.PackageID) AS NumPackages
FROM Customer c
JOIN Shipment s ON c.CustomerID = s.CustomerID
JOIN Package p  ON s.ShipmentID = p.ShipmentID
WHERE s.ShipmentDate >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
GROUP BY c.CustomerID, c.Name
ORDER BY NumPackages DESC
LIMIT 1;
--Customer Who Spent the Most on Shipping in the Past Year

SELECT c.CustomerID,
       c.Name,
       SUM(pay.Amount) AS TotalSpent
FROM Customer c
JOIN Shipment s ON c.CustomerID = s.CustomerID
JOIN Payment pay ON s.ShipmentID = pay.ShipmentID
WHERE pay.Timestamp >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
GROUP BY c.CustomerID, c.Name
ORDER BY TotalSpent DESC
LIMIT 1;
--Street with the most customers

SELECT a.Street, COUNT(c.CustomerID) AS CustomerCount
FROM Address a
JOIN Customer c ON c.CustomerID = a.AddressID
GROUP BY a.Street
ORDER BY CustomerCount DESC
LIMIT 1;
Packages not delivered within the promised time

SELECT p.PackageID, s.PromiseDate, MAX(te.Timestamp) AS DeliveredAt
FROM Package p
JOIN Shipment s ON p.ShipmentID = s.ShipmentID
JOIN TrackingEvent te ON p.PackageID = te.PackageID
WHERE te.StatusDetail = 'Delivered'
GROUP BY p.PackageID, s.PromiseDate
HAVING DeliveredAt > s.PromiseDate;
Packages not delivered within the promised time

SELECT 
    c.CustomerID, 
    c.Name, 
    a.Street, 
    SUM(p.Amount) AS AmountOwed  
FROM 
    Customer c  
JOIN 
    Shipment s ON c.CustomerID = s.CustomerID  
JOIN 
    Address a ON s.SenderAddressID = a.AddressID  
JOIN 
    Payment p ON s.ShipmentID = p.ShipmentID  
WHERE 
    s.ShipmentDate >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)  
GROUP BY 
    c.CustomerID, c.Name, a.Street
LIMIT 0, 1000;
--a. Simple bill (Customer, Address, Amount Owed) – Past Month

SELECT c.CustomerID,
       c.Name,
       st.Description AS ServiceType,
       SUM(pay.Amount) AS TotalByService
FROM Customer c
JOIN Shipment s      ON c.CustomerID = s.CustomerID
JOIN ServiceType st  ON s.ServiceCode = st.ServiceCode
JOIN Payment pay     ON s.ShipmentID = pay.ShipmentID
WHERE pay.Timestamp >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
GROUP BY c.CustomerID, c.Name, st.ServiceCode, st.Description;
--Bill by Service Type (Charges Grouped by Delivery Tier)

SELECT c.CustomerID,
       c.Name,
       s.ShipmentID,
       s.ShipmentDate,
       st.Description AS ServiceType,
       pay.Amount,
       pay.Timestamp AS PaidAt
FROM Customer c
JOIN Shipment s      ON c.CustomerID = s.CustomerID
JOIN ServiceType st  ON s.ServiceCode = st.ServiceCode
JOIN Payment pay     ON s.ShipmentID = pay.ShipmentID
WHERE pay.Timestamp >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
ORDER BY c.CustomerID, pay.Timestamp;
-- Count rows in Customer table
SELECT COUNT(*) AS CustomerCount FROM Customer;

-- Count rows in Address table
SELECT COUNT(*) AS AddressCount FROM Address;

-- Count rows in Recipient table
SELECT COUNT(*) AS RecipientCount FROM Recipient;

-- Count rows in ServiceType table
SELECT COUNT(*) AS ServiceTypeCount FROM ServiceType;

-- Count rows in Shipment table
SELECT COUNT(*) AS ShipmentCount FROM Shipment;

-- Count rows in Package table
SELECT COUNT(*) AS PackageCount FROM Package;

-- Count rows in CustomsDeclaration table
SELECT COUNT(*) AS CustomsDeclarationCount FROM CustomsDeclaration;

-- Count rows in HazardousMaterial table
SELECT COUNT(*) AS HazardousMaterialCount FROM HazardousMaterial;

-- Count rows in PaymentMethod table
SELECT COUNT(*) AS PaymentMethodCount FROM PaymentMethod;

-- Count rows in Payment table
SELECT COUNT(*) AS PaymentCount FROM Payment;

-- Count rows in Vehicle table
SELECT COUNT(*) AS VehicleCount FROM Vehicle;

-- Count rows in Facility table
SELECT COUNT(*) AS FacilityCount FROM Facility;

-- Count rows in RouteSegment table
SELECT COUNT(*) AS RouteSegmentCount FROM RouteSegment;

-- Count rows in TrackingEvent table
SELECT COUNT(*) AS TrackingEventCount FROM TrackingEvent;

