Create database Book_Store_Management;

use Book_Store_Management;



CREATE TABLE Users (
    user_id INT PRIMARY KEY IDENTITY(1,1),
    name NVARCHAR(100) NOT NULL,
    email NVARCHAR(255) UNIQUE NOT NULL,
    password NVARCHAR(255) NOT NULL,
    role NVARCHAR(50) CHECK (role IN ('Admin', 'User')) NOT NULL
);

CREATE TABLE Books (
    book_id INT PRIMARY KEY IDENTITY(1,1),
    title NVARCHAR(255) NOT NULL,
    author NVARCHAR(255),
    description NVARCHAR(MAX),
    price DECIMAL(10, 2) NOT NULL,
    stock INT NOT NULL,
    publication_date DATE
);

CREATE TABLE Carts (
    cart_id INT PRIMARY KEY IDENTITY(1,1),
    user_id INT NOT NULL,
    created_at DATETIME DEFAULT GETDATE(),
	total_price DECIMAL (10, 2) NOT NULL
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE
);

CREATE TABLE CartItems (
    cart_item_id INT PRIMARY KEY IDENTITY(1,1),
    cart_id INT NOT NULL,
    book_id INT NOT NULL,
    quantity INT NOT NULL,
    FOREIGN KEY (cart_id) REFERENCES Carts(cart_id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES Books(book_id) ON DELETE CASCADE
);

CREATE TABLE Wishlists (
    wishlist_id INT PRIMARY KEY IDENTITY(1,1),
    user_id INT NOT NULL,
    book_id INT NOT NULL,
    created_date DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES Books(book_id) ON DELETE CASCADE
);

CREATE TABLE Orders (
    order_id INT PRIMARY KEY IDENTITY(1,1),
    user_id INT NOT NULL,
    order_date DATETIME DEFAULT GETDATE(),
    status NVARCHAR(50) DEFAULT 'Pending',
    total_amount DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE
);

CREATE TABLE OrderItems (
    order_item_id INT PRIMARY KEY IDENTITY(1,1),
    order_id INT NOT NULL,
    book_id INT NOT NULL,
    quantity INT NOT NULL,
    purchase_price DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (order_id) REFERENCES Orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (book_id) REFERENCES Books(book_id) ON DELETE CASCADE
);

CREATE TABLE Reviews (
    review_id INT PRIMARY KEY IDENTITY(1,1),
    book_id INT NOT NULL,
    user_id INT NOT NULL,
    rating INT CHECK (rating BETWEEN 1 AND 5),
    comment NVARCHAR(MAX),
    review_date DATETIME DEFAULT GETDATE(),
    FOREIGN KEY (book_id) REFERENCES Books(book_id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE
);

CREATE TABLE Addresses (
    address_id INT PRIMARY KEY IDENTITY(1,1),
    user_id INT NOT NULL,
    address_line NVARCHAR(255) NOT NULL,
    city NVARCHAR(100) NOT NULL,
    state NVARCHAR(100) NOT NULL,
    pin_code NVARCHAR(20) NOT NULL,
    country NVARCHAR(100) NOT NULL,
    FOREIGN KEY (user_id) REFERENCES Users(user_id) ON DELETE CASCADE
);
CREATE TABLE AuditLog (
    log_id INT PRIMARY KEY IDENTITY(1,1),
    user_id INT,
    action NVARCHAR(255),
    action_time DATETIME DEFAULT GETDATE(),
    details NVARCHAR(MAX)
);


--user table operations

Alter PROCEDURE AddUser
    @name NVARCHAR(100),
    @email NVARCHAR(255),
    @password NVARCHAR(255),
    @role NVARCHAR(50)
AS
BEGIN
    BEGIN TRY
        IF @role NOT IN ('Admin', 'User')
            RAISERROR('Invalid role. Must be Admin or User.', 16, 1);

        INSERT INTO Users (name, email, password, role)
        VALUES (@name, @email, @password, @role);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;

CREATE TRIGGER LogUserActions
ON Users
AFTER INSERT, UPDATE
AS
BEGIN
    INSERT INTO AuditLog (user_id, action, details)
    SELECT 
        i.user_id, 
        'User Action', 
        CASE WHEN EXISTS (SELECT 1 FROM INSERTED i JOIN DELETED d ON i.user_id = d.user_id) 
             THEN 'Updated user details' ELSE 'Registered new user' END
    FROM INSERTED i;
END;

---User's Address
CREATE or Alter PROCEDURE UpdateAddress
    @user_id INT,
    @address_line NVARCHAR(255),
    @city NVARCHAR(100),
    @state NVARCHAR(100),
    @pin_code NVARCHAR(20),
    @country NVARCHAR(100)
AS
BEGIN
    BEGIN TRY
        IF EXISTS (SELECT 1 FROM Addresses WHERE user_id = @user_id)
        BEGIN
            UPDATE Addresses
            SET address_line = @address_line, city = @city, state = @state, pin_code = @pin_code, country = @country
            WHERE user_id = @user_id;
        END
        ELSE
        BEGIN
            INSERT INTO Addresses (user_id, address_line, city, state, pin_code, country)
            VALUES (@user_id, @address_line, @city, @state, @pin_code, @country);
        END
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;



---Book Reviews---
CREATE or Alter PROCEDURE AddBook
    @user_id INT,
    @title NVARCHAR(255),
    @author NVARCHAR(255),
    @description NVARCHAR(MAX),
    @price DECIMAL(10, 2),
    @stock INT,
    @publication_date DATE
AS
BEGIN
    BEGIN TRY
        
        IF EXISTS (
            SELECT 1
            FROM Users
            WHERE user_id = @user_id AND role = 'Admin'
        )
        BEGIN
            INSERT INTO Books (title, author, description, price, stock, publication_date)
            VALUES (@title, @author, @description, @price, @stock, @publication_date);

            PRINT 'Book added successfully.';
        END
        ELSE
        BEGIN
            THROW 50001, 'Only Admin users can add books.', 1;
        END
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;
Create or Alter PROCEDURE AddReview
    @user_id INT,
    @book_id INT,
    @rating INT,
    @comment NVARCHAR(MAX)
AS
BEGIN
    BEGIN TRY
        INSERT INTO Reviews (book_id, user_id, rating, comment)
        VALUES (@book_id, @user_id, @rating, @comment);
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;



----CartItems---

CREATE or Alter PROCEDURE AddOrderItem
    @order_id INT,
    @book_id INT,
    @quantity INT
AS
BEGIN
    BEGIN TRY
        IF (SELECT stock FROM Books WHERE book_id = @book_id) < @quantity
        BEGIN
            THROW 50001, 'Insufficient stock available for this book.', 1;
        END
        
        INSERT INTO OrderItems (order_id, book_id, quantity, purchase_price)
        VALUES (
            @order_id,
            @book_id,
            @quantity,
            (SELECT price FROM Books WHERE book_id = @book_id)
        );

        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;


CREATE or Alter TRIGGER trg_DeductStockOnOrder
ON OrderItems
AFTER INSERT
AS
BEGIN
    
    UPDATE Books
    SET stock = stock - i.quantity
    FROM Books b
    INNER JOIN Inserted i ON b.book_id = i.book_id;

    
    IF EXISTS (SELECT 1 FROM Books WHERE stock < 0)
    BEGIN
        THROW 50002, 'Stock cannot be negative. Transaction rolled back.', 1;
    END
END;


CREATE OR ALTER PROCEDURE AddToCart 
    @user_id INT,
    @book_id INT,
    @quantity INT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (
            SELECT 1
            FROM Books
            WHERE book_id = @book_id AND stock < @quantity
        )
        BEGIN
            THROW 51000, 'Insufficient stock for the requested item.', 1;
        END;

        DECLARE @cart_id INT;
        SELECT @cart_id = cart_id FROM Carts WHERE user_id = @user_id;

        IF @cart_id IS NULL
        BEGIN
            INSERT INTO Carts (user_id, total_price)
            VALUES (@user_id, 0);

            SET @cart_id = SCOPE_IDENTITY();
        END;

        IF EXISTS (SELECT 1 FROM CartItems WHERE cart_id = @cart_id AND book_id = @book_id)
        BEGIN
            UPDATE CartItems
            SET quantity = quantity + @quantity
            WHERE cart_id = @cart_id AND book_id = @book_id;
        END
        ELSE
        BEGIN
            INSERT INTO CartItems (cart_id, book_id, quantity)
            VALUES (@cart_id, @book_id, @quantity);
        END;

        -- Update the total price of the cart
        UPDATE Carts
        SET total_price = (
            SELECT SUM(ci.quantity * b.price)
            FROM CartItems ci
            JOIN Books b ON ci.book_id = b.book_id
            WHERE ci.cart_id = @cart_id
        )
        WHERE cart_id = @cart_id;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;


CREATE or Alter PROCEDURE ViewCartItems
    @user_id INT
AS
BEGIN
    SELECT 
        ci.cart_item_id,
        b.title AS book_title,
        ci.quantity,
        b.price AS unit_price,
        (ci.quantity * b.price) AS total_price
    FROM CartItems ci
    JOIN Books b ON ci.book_id = b.book_id
    JOIN Carts c ON ci.cart_id = c.cart_id
    WHERE c.user_id = @user_id;
END;



---Orders---

CREATE OR ALTER PROCEDURE PlaceOrder
    @user_id INT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        IF EXISTS (
            SELECT 1
            FROM CartItems ci
            JOIN Books b ON ci.book_id = b.book_id
            WHERE ci.cart_id = (SELECT cart_id FROM Carts WHERE user_id = @user_id)
              AND ci.quantity > b.stock
        )
        BEGIN
            THROW 51000, 'Insufficient stock for one or more items in the cart.', 1;
        END;

        DECLARE @order_id INT;
        INSERT INTO Orders (user_id, total_amount, order_date)
        VALUES (
            @user_id,
            (SELECT SUM(ci.quantity * b.price)
             FROM CartItems ci
             JOIN Books b ON ci.book_id = b.book_id
             WHERE ci.cart_id = (SELECT cart_id FROM Carts WHERE user_id = @user_id)),
            GETDATE()
        );

        SET @order_id = SCOPE_IDENTITY();

        INSERT INTO OrderItems (order_id, book_id, quantity, purchase_price)
        SELECT 
            @order_id,
            ci.book_id,
            ci.quantity,
            b.price
        FROM CartItems ci
        JOIN Books b ON ci.book_id = b.book_id
        WHERE ci.cart_id = (SELECT cart_id FROM Carts WHERE user_id = @user_id);


        DELETE FROM CartItems
        WHERE cart_id = (SELECT cart_id FROM Carts WHERE user_id = @user_id);

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END;


CREATE OR ALTER PROCEDURE ViewOrderDetails
    @user_id INT = NULL,  
    @order_id INT = NULL 
AS
BEGIN
    BEGIN TRY
        -- Retrieve order details
        SELECT 
            o.order_id,
            o.user_id,
            u.name AS user_name,
            o.order_date,
            o.total_amount,
            oi.book_id,
            b.title,
            b.author,
            oi.quantity,
            oi.purchase_price,
            (oi.quantity * oi.purchase_price) AS item_total
        FROM Orders o
        JOIN OrderItems oi ON o.order_id = oi.order_id
        JOIN Books b ON oi.book_id = b.book_id
        LEFT JOIN Users u ON o.user_id = u.user_id
        WHERE 
            (@user_id IS NULL OR o.user_id = @user_id) AND
            (@order_id IS NULL OR o.order_id = @order_id)
        ORDER BY o.order_date DESC, o.order_id;

    END TRY
    BEGIN CATCH
       
        THROW;
    END CATCH
END;




EXEC AddUser 'Ravi Kumar','ravi.kumar@gmail.com', 'securePass123', 'User';
EXEC AddUser @name = 'Anjali Sharma', @email = 'anjali.sharma@gmail.com', @password = 'password456', @role = 'User';
EXEC AddUser @name = 'Arjun Mehta', @email = 'arjun.mehta@gmail.com', @password = 'secureMehta789', @role = 'Admin';


EXEC UpdateAddress @user_id = 1, @address_line = '123 MG Road', @city = 'Mumbai', @state = 'Maharashtra', @pin_code = '400001', @country = 'India';
EXEC UpdateAddress @user_id = 2, @address_line = '45 Park Street', @city = 'Kolkata', @state = 'West Bengal', @pin_code = '700016', @country = 'India';
EXEC UpdateAddress @user_id = 3, @address_line = '67 Residency Road', @city = 'Bengaluru', @state = 'Karnataka', @pin_code = '560025', @country = 'India';


-- Book 1
EXEC AddBook 
    @user_id = 3,  
    @title = 'The God of Small Things',
    @author = 'Arundhati Roy',
    @description = 'A deeply moving family saga set in Kerala.',
    @price = 499.00,
    @stock = 25,
    @publication_date = '1997-05-01';

-- Book 2
EXEC AddBook 
    @user_id = 3,  
    @title = 'A Suitable Boy',
    @author = 'Vikram Seth',
    @description = 'An epic love story set in post-independence India.',
    @price = 899.00,
    @stock = 10,
    @publication_date = '1993-10-08';

-- Book 3
EXEC AddBook 
    @user_id = 3, 
    @title = 'Train to Pakistan',
    @author = 'Khushwant Singh',
    @description = 'A gripping tale of Partition and its aftermath.',
    @price = 350.00,
    @stock = 30,
    @publication_date = '1956-01-01';

-- Book 4
EXEC AddBook 
    @user_id = 3, 
    @title = 'Mahabharata',
    @author = 'C. Rajagopalachari',
    @description = 'A retelling of the great Indian epic.',
    @price = 599.00,
    @stock = 40,
    @publication_date = '1951-08-01';

-- Book 5
EXEC AddBook 
    @user_id = 3, 
    @title = 'Indian Summer',
    @author = 'Alex von Tunzelmann',
    @description = 'An account of the last days of the British Raj.',
    @price = 699.00,
    @stock = 15,
    @publication_date = '2007-06-15';

-- Book 6
EXEC AddBook 
    @user_id = 3, 
    @title = 'The Palace of Illusions',
    @author = 'Chitra Banerjee Divakaruni',
    @description = 'A retelling of the Mahabharata from Draupadi’s perspective.',
    @price = 499.00,
    @stock = 20,
    @publication_date = '2008-02-01';

-- Book 7
EXEC AddBook 
    @user_id = 3,  
    @title = 'Ignited Minds',
    @author = 'Dr. A.P.J. Abdul Kalam',
    @description = 'A book that inspires Indian youth for nation-building.',
    @price = 250.00,
    @stock = 50,
    @publication_date = '2002-07-01';

-- Book 8
EXEC AddBook 
    @user_id = 3,  
    @title = 'The Inheritance of Loss',
    @author = 'Kiran Desai',
    @description = 'A story of various characters in a small Himalayan town.',
    @price = 399.00,
    @stock = 35,
    @publication_date = '2006-01-01';

-- Book 9
EXEC AddBook 
    @user_id = 3,  
    @title = 'The Namesake',
    @author = 'Jhumpa Lahiri',
    @description = 'A tale of an immigrant family’s journey in the US.',
    @price = 299.00,
    @stock = 20,
    @publication_date = '2003-09-01';

-- Book 10
EXEC AddBook 
    @user_id = 3,  -- Admin user
    @title = 'Shantaram',
    @author = 'Gregory David Roberts',
    @description = 'An Australian fugitive’s experiences in Mumbai.',
    @price = 799.00,
    @stock = 12,
    @publication_date = '2003-10-01';


INSERT INTO Wishlists (user_id, book_id)
VALUES 
(1, 2),
(2, 1),
(2, 3),
(3, 4),
(3, 7);


EXEC AddToCart @user_id = 1, @book_id = 1, @quantity = 2; 
EXEC AddToCart @user_id = 1, @book_id = 3, @quantity = 1; 
EXEC AddToCart @user_id = 2, @book_id = 3, @quantity = 2;

EXEC ViewCartItems 2;


EXEC AddReview @user_id = 1, @book_id = 1, @rating = 5, @comment = 'An inspiring read!';
EXEC AddReview @user_id = 2, @book_id = 2, @rating = 4, @comment = 'Very motivational and uplifting.';
EXEC AddReview @user_id = 1, @book_id = 3, @rating = 3, @comment ='Satire isnt my cup of tea, but a good book nonetheless.';



EXEC PlaceOrder @user_id = 1;

EXEC PlaceOrder @user_id = 2;

EXEC ViewOrderDetails @user_id = 2;



Select * from Orders;
select * from carts;
SELECT * FROM Books;

Select * from Users;
select * from AuditLog;







