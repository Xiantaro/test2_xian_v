--������
--------------------------------------------------------------------------------
-- �s��
CREATE TYPE OverDueTVP3 AS TABLE(
	ResultCode INT NULL,
	Message NVARCHAR(MAX) NULL,
	[reservationId] [int] NULL,
	[borrowId] [int] NULL,
	[cid] [int] NULL,
	[collectionId] [int] NULL,
	[bookid] [int] NULL,
	[dueDateB] [datetime2](7) NULL,
	[title] [nvarchar](MAX) NULL,
	[cName] [nvarchar] (MAX) NULL,
	[cAccount] [nvarchar] (MAX) NULL
)
GO

CREATE TYPE OverDueOneToThreeTVP AS TABLE (
	Cid INT NULL,
	ClientName NVARCHAR(50),
	Title NVARCHAR(50),
	Days INT,
	DueDays DATETIME2,
	Email NVARCHAR(100)
)
GO

CREATE TYPE DueBookTVP AS TABLE(
	collectionid INT,
	bookid INT
)
GO
--------------------------------------------------------------------------------
-- �ɾ\�Ҧ�_���y��T
ALTER PROC BookInfomationForBorrow
@bookCode NVARCHAR(500)
AS
BEGIN
		SELECT bok.bookCode, 
			col.title, 
			auth.author, 
			col.translator, 
			typ.[type], 
			col.publisher, 
			col.publishDate, 
			col.collectionImg, 
			bokstu.bookStatus
		FROM Book bok JOIN Collection col ON bok.collectionId = col.collectionId
		JOIN BookStatus bokstu ON bok.bookStatusId = bokstu.bookStatusId
		JOIN [Type] typ ON col.typeId = typ.typeId
		JOIN Author auth ON auth.authorId = col.authorId
		WHERE bok.bookCode = @bookCode
END
GO
-- �ɾ\�Ҧ��D�nPROC
ALTER PROC BorrowResult
    @cid INT,
    @bookCode NVARCHAR(500)
AS
BEGIN 
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL REPEATABLE READ
    BEGIN TRY
        BEGIN TRAN
        -- �T�w�ӭɾ\�̬O�_�s�b
        IF NOT EXISTS( SELECT 1 FROM Client WHERE cId = @cid)
        BEGIN
            SELECT 0  ResultCode, N'�ӭɾ\�̤��s�b�A�Э��s��J!' AS Message;
            ROLLBACK
            RETURN
        END
        
        -- �T�{�ѬO�_�s�b
        IF NOT EXISTS ( SELECT 1 FROM Book WHERE bookCode = @bookCode)
        BEGIN
            ROLLBACK
            SELECT 0   ResultCode, N'�ӥ����y���s�b�A�Э��s��J!' AS Message;
            RETURN
        END

        DECLARE @bookid INT,@collectionId INT, @title NVARCHAR(50)
		SELECT @bookid = bok.bookid, @collectionId = bok.collectionId, @title = col.title
        FROM Book bok
		JOIN Collection col ON bok.collectionId = col.collectionId
        WHERE bookCode = @bookCode
		-- ���O�������y
		IF EXISTS ( SELECT 1 FROM Borrow WHERE cid = @cid AND borrowStatusId = 3 AND returnDate IS NULL)
		BEGIN 
			ROLLBACK
			SELECT 0 ResultCode, N'���O�����٪����y�i' + @title + '�j' Message
			RETURN
		END
		-- �T�{�O�_�ɾ\�W�L��������
		IF EXISTS ( SELECT 1 FROM Borrow bow WHERE bow.cId = @cid AND bow.borrowStatusId = 2 GROUP BY cid, borrowStatusId HAVING COUNT(cid) > = 5)
		BEGIN 
			ROLLBACK
			SELECT 0 ResultCode, N'�w�ɾ\�W�L�����A�L�k�A�ɾ\' Message
			RETURN
		END
        -- �o���Ѧb�]���� 1.�i�ɾ\
        IF EXISTS ( SELECT 1 FROM Book WHERE bookCode = @bookCode AND bookStatusId = 1)
        BEGIN

			-- ���୫�ƭɾ\�P�@��collectioinid��
			IF EXISTS ( SELECT 1 
			FROM Borrow bow JOIN Book bok ON bow.bookId = bok.bookId JOIN Collection col ON bok.collectionId = col.collectionId 
			WHERE col.collectionId = @collectionId   AND cid = @cid AND bow.borrowStatusId = 2)
			BEGIN 
				ROLLBACK
				SELECT 0 ResultCode, N'���୫�ƭɾ\�P�@�����y' Message
				RETURN
			END
			-- ������s���ɥX���A(1)
            UPDATE Book WITH(ROWLOCK, UPDLOCK) SET bookStatusId = 2
            WHERE bookCode = @bookCode AND bookStatusId = 1;
						
			-- �p�G�S����s���\�A�N��Q�w���F....
            IF @@ROWCOUNT = 0
            BEGIN
                SELECT 0  ResultCode, N'�ӥ����y�w�Q��L�H�ɨ�' Message;
                ROLLBACK;
                RETURN;
            END
			-- �s�W�ɾ\����
            INSERT INTO Borrow (cId, bookid, borrowDate, dueDateB, borrowStatusId)
            VALUES(@cid, @bookid, GETDATE(), DATEADD(DAY, 14, GETDATE()), 2)
			

			DECLARE @borrwId INT
			SELECT @borrwId = SCOPE_IDENTITY();

			INSERT INTO History (borrowId)
			VALUES (@borrwId)

            SELECT 1 AS ResultCode, N'�ɾ\���\' AS Message;
            COMMIT
            RETURN
        END
        -- �p�G���b�����W�w��(2)����
        DECLARE @reservationId INT;
        IF EXISTS (
            SELECT 0 FROM Book WHERE bookCode = @bookCode AND bookStatusId = 2
        )
        BEGIN
            -- �P�_�ӤH�O�_�O ����q�����w���̫e�ӻ�� => ���A: �ݨ��Ѥ�
            SELECT @reservationId = reservationId
            FROM Reservation WITH(UPDLOCK, ROWLOCK)
            WHERE cid = @cid AND reservationStatusId = 3
            AND bookId = @bookId

            IF @reservationId IS NULL
            BEGIN 
                SELECT 0 AS ResultCode, N'�����y�w�Q�ɾ\!' AS Message;
                ROLLBACK
				RETURN
            END

            --  �令�w�����A �w�ɥX
            UPDATE Reservation SET reservationStatusId = 1
            WHERE reservationId = @reservationId AND cid = @cid

            IF @@ROWCOUNT = 0
            BEGIN 
                SELECT 1  ResultCode, N'���y���A�w�ܧ�A�L�k�����ɮ�' AS Message;
                ROLLBACK;
                RETURN;
            END

			-- ���J�ɾ\����
            INSERT INTO Borrow (cId,reservationId, bookId, borrowDate, dueDateB, borrowStatusId)
            VALUES(@cid, @reservationId , @bookId, GETDATE(), DATEADD(DAY, 14, GETDATE()), 2)

            SELECT 1 AS ResultCode, N'�ɾ\���\' AS Message;
            COMMIT;
            RETURN;
        END
        -- 
        SELECT 0 ResultCode, N'�ӥ����y�L�k�ɾ\�C' AS Message;
        ROLLBACK
        RETURN
    END TRY
    BEGIN CATCH 
        ROLLBACK
        SELECT 500 ResultCode, N'�o�Ϳ��~' Message
    END CATCH
END
GO
--------------------------------------------------------------------------------
-- �w���Ҧ�_����r���y�j�M
ALTER PROC BookStatusDetail
    @keyword NVARCHAR(500),
    @bookstatus NVARCHAR(20)
AS 
BEGIN 
    SELECT col.collectionId ,title, author, bookstatus, 
	( SELECT COUNT(*) FROM Reservation r WHERE r.collectionId = col.collectionId AND reservationStatusId = 2) number
    FROM Collection col 
	JOIN Book bok ON col.collectionId = bok.collectionId
    JOIN BookStatus bokstu ON bok.bookStatusId = bokstu.bookStatusId
	JOIN Author auth ON auth.authorId = col.authorId
    LEFT JOIN Reservation re ON col.collectionId = re.collectionId
    WHERE (col.title LIKE '%'+ @keyword + '%' OR auth.author LIKE '%' + @keyword + '%') 
    AND 
            (@bookstatus = 'ALL' AND bok.bookStatusId IN (1,2, 3) OR
            (@bookstatus = 'IsLent' AND bok.bookStatusId IN (2)) OR
            (@bookstatus = 'Available' AND bok.bookStatusId = 1)
    )
    GROUP BY  col.collectionId, title, author, bokstu.bookStatus
END;
GO

-- �w���Ҧ�_�w���q��
ALTER PROC NotificationAppointmentSuccess
    @cid INT,
    @collectionId INT
AS
BEGIN
	SET NOCOUNT ON
    BEGIN TRY
        DECLARE @message NVARCHAR(500); 
		DECLARE @title NVARCHAR(500); 
		DECLARE @cName NVARCHAR(20);

        SELECT @cName = cName FROM Client WHERE cid = @cid
        SELECT @title = title FROM Collection WHERE collectionId = @collectionId
		IF (@cName IS NULL OR @title IS NULL)
		BEGIN 
			SELECT 0 ResultCode, '�q������: �䤣��w���̩ή��y' Message
			RETURN
		END

        SET @message = N'�i�w�����\�q���j�˷R�� ' + @cName +
                       N' �A�z�w��'  + CONVERT(NVARCHAR ,FORMAT(GETDATE(), 'yyyy-MM-dd hh-mm-ss'))+ N'�w���F '+ @title + 
                       N' �Э@�ߵ��Գq���C�Ϯ��]�޲z�t�� �q�W�C';

        INSERT INTO Notification (cid, [message], notificationDate) VALUES (@cid,  @message, GETDATE());
		
    END TRY
    BEGIN CATCH
		SELECT 0 ResultCode, '�q������: ' + ERROR_MESSAGE() Message
        RETURN
    END CATCH
END
GO

--�w���Ҧ��D�nPROC
ALTER PROC AppointmentMode
    @cid INT,
    @collectionId INT
AS	
BEGIN 
	SET NOCOUNT ON
    BEGIN TRY
        BEGIN TRANSACTION
        -- ���T�{�ϥΪ̬O�_�s�b
        IF NOT EXISTS ( SELECT 1 FROM Client WHERE cid = @cid)
        BEGIN
			ROLLBACK
            SELECT 0 ResultCode, '�ϥΪ̤��s�b' Message 
			RETURN
        END
		DECLARE @title NVARCHAR(50)
		SELECT @title = title
		FROM Collection WHERE collectionId = @collectionId
		-- �O������
        IF EXISTS (SELECT 1 FROM Borrow WHERE cid = @cid AND borrowStatusId = 3 AND returnDate IS NULL)
		BEGIN 
			ROLLBACK
			SELECT 0 ResultCode, N'���O�����٪����y�i' + @title + '�j' Message
			RETURN 
		END
        -- �T�{���y�O�_�s�b
        IF NOT EXISTS (SELECT 1 FROM Collection WHERE collectionId = @collectionId)
        BEGIN
			ROLLBACK
            SELECT 0 ResultCode, '���y���s�b' Message  
			RETURN
        END 
        -- �p�G�w���w�g�s�b
        IF EXISTS (SELECT 1 FROM Reservation WHERE cid=@cid AND collectionId = @collectionId AND reservationStatusId  = 2 )
        BEGIN 
				ROLLBACK
				SELECT 0 ResultCode, '���ƹw��' Message
				RETURN
		END
        -- �p�G�ӥ��� �b�]�� 
        IF EXISTS (SELECT 1 FROM Book WHERE collectionId = @collectionId AND  bookStatusId = 1)
        BEGIN 
                ROLLBACK 
                SELECT 0 ResultCode, '�����ѥثe�b���]' Message
				RETURN
        END 
		-- �p�G�A�w�g�ɾ\�ӥ��ѤF�A�N����A�w��
		IF EXISTS ( SELECT 1 FROM Borrow bor JOIN Book bok ON bor.bookId = bok.bookId WHERE bok.collectionId = @collectionId AND bor.cId = @cid AND bor.borrowStatusId = 2)
		BEGIN
			ROLLBACK 
            SELECT 0 ResultCode, '�w�ɾ\�ۦP�����y�A�L�k�A�i��w��' Message
			RETURN
		END
        -- �p�G�ӥ��Ѧ��w�� 
        IF EXISTS (SELECT 1 FROM Book WHERE bookStatusId  = 2 AND collectionId = @collectionId)
        BEGIN 
            INSERT INTO Reservation (cId, collectionId, reservationDate,reservationStatusId)
			VALUES (@cid, @collectionid, GETDATE(), 2)
			EXEC NotificationAppointmentSuccess @cid,@collectionid
            SELECT 1 ResultCode, '�w�����\' Message 
            COMMIT 
            RETURN 
        END 

        ROLLBACK
		SELECT 0 ResultCode, '�w������' Message
		RETURN
    END TRY

    BEGIN CATCH 
		ROLLBACK
		SELECT 0 ResultCode, '�X�{���~: ' + ERROR_MESSAGE() Message 
		RETURN
	END CATCH
END
GO
--------------------------------------------------------------------------------
--�ٮѼҦ�_���o�̦��w����TVF  
ALTER FUNCTION GetEarliestReservation(@collectionId INT)
RETURNS TABLE
AS 
RETURN
(
	WITH ReservationCTE AS (
			SELECT reservationId,  collectionId, cid, reservationDate, rs.reservationStatus,ROW_NUMBER() OVER(PARTITION BY collectionId  ORDER BY  reservationDate ASC) rk
			FROM Reservation re  JOIN ReservationStatus rs ON re.reservationStatusId =  rs.reservationStatusId
			WHERE collectionId = @collectionId AND  re.reservationStatusId = 2
	)
    SELECT reservationId, collectionId, cid,reservationDate, reservationStatus
    FROM ReservationCTE
    WHERE rk = 1
)
GO

--�ٮѼҦ�_�q���w���̨���
ALTER PROC NotificationBooker
    @cid INT,
    @collectionId INT
AS
BEGIN
	SET NOCOUNT ON
    BEGIN TRY
        DECLARE @message NVARCHAR(500); 
		DECLARE @title NVARCHAR(500); 
		DECLARE @cName NVARCHAR(20);

        SELECT @cName = cName FROM Client WHERE cid = @cid
        SELECT @title = title FROM Collection WHERE collectionId = @collectionId
		IF (@cName IS NULL OR @title IS NULL)
		BEGIN 
			RETURN
		END

        SET @message = N'�i���ѳq���j�˷R�� ' + @cName +
                       N' �A�z�ҹw������ ' + @title + 
                       N' �w�i�H�ɾ\�A�Щ�' + CONVERT(NVARCHAR, DATEADD(DAY, 2, GETDATE()), 111)+'���쥻�]�ɮѡA���¡C�Ϯ��]�޲z�t�� �q�W�C';
        INSERT INTO Notification (cid, [message], notificationDate) VALUES (@cid,  @message, GETDATE());
    END TRY
    BEGIN CATCH
		SELECT 0 ResultCode, N'�q������: ' + ERROR_MESSAGE() Message
        RETURN
    END CATCH
END
GO

--�ٮѼҦ�_�ˬd�O�_����L�w��
ALTER PROC CheckBookIsReservation
    @collectionId int,
	@bookid INT
AS 
BEGIN
	SET NOCOUNT ON
    BEGIN TRY
        DECLARE @cid INT;
        DECLARE @reservationId INT;

        --�����ӥ��ѳ̦��w����
        SELECT @reservationId = reservationId, @cid = cid
        FROM GetEarliestReservation(@collectionId)
		IF (@reservationId IS NULL OR @cid IS NULL)
		BEGIN 
				SELECT 0 ResultCode, N'�L���Ĺw������' Message, NULL AS cName, NULL AS cAccount, NULL AS title
				RETURN
		END
        -- ��s�w�����A"�i����"�B�T�Ѩ��Ѯɶ�
        UPDATE Reservation WITH(ROWLOCK, UPDLOCK)
        SET bookid = @bookid, reservationStatusId = 3, dueDateR = DATEADD(DAY, 3, GETDATE())
        WHERE reservationId = @reservationId AND cid = @cid
		AND reservationStatusId = 2

        IF @@ROWCOUNT = 0
        BEGIN 
            SELECT 0 ResultCode, N'���w���̪��A����' MESSAGE, NULL AS cName, NULL AS cAccount, NULL AS title
            RETURN
        END
		-- �q���w���̨���
        EXEC NotificationBooker @cid, @collectionId

		-- �^��
        SELECT 1 ResultCode, N'�^�ǹw���̨��ѡC' Message, cli.cName, cli.cAccount AS cAccount , col.title
		FROM Client cli JOIN Reservation re ON cli.cId = re.cId
		JOIN Collection col ON re.collectionId = col.collectionId
		WHERE cli.cId = @cid AND re.collectionId = @collectionId

    END TRY
    BEGIN CATCH
        SELECT 0 ResultCode, N'�o�Ϳ��~:' + ERROR_MESSAGE() Message, NULL AS cName, NULL AS cAccount, NULL AS title
        RETURN
    END CATCH
END 
GO

--�ٮѼҦ�_�D�nPROC
ALTER PROC ReturnBook
			@BookCode NVARCHAR(500)
AS
BEGIN
		SET TRANSACTION ISOLATION LEVEL READ COMMITTED
		SET NOCOUNT ON
		BEGIN TRY
				BEGIN TRAN
				DECLARE @borrwid INT
				DECLARE @collectionId INT
				DECLARE @bookid INT

				-- ��X�ɾ\����
				SELECT TOP 1 @borrwid = borrowid, @collectionId = collectionId, @bookid = bok.bookid
				FROM Borrow bor JOIN Book bok ON bor.bookId  = bok.bookId
				WHERE bookCode = @BookCode AND bor.borrowStatusId IN ( 2,3) 
				
				-- �T�{�O�_���Q�ɾ\
				IF @borrwid IS NULL
				BEGIN 
					ROLLBACK
					SELECT 0 ResultCode, @BookCode + N'�å��Q�ɾ\�C' Message, NULL collectionid, NULL bookid
					RETURN
				END

				-- �T�{�O�ӥ��ѳQ�ɾ\ => �n�k��
				IF  @borrwid IS NOT NULL 
				BEGIN
					-- �p�G�S�w�ɾ\��
					-- ��s �ٮѪ̪��A �w�k��(1)
					UPDATE Borrow WITH(ROWLOCK, UPDLOCK) SET borrowStatusId = 1, returnDate = GETDATE()
					WHERE borrowId = @borrwid 
					
					IF @@ROWCOUNT = 0 
					BEGIN 
						SELECT 0 ResultCode, N'�k�٥���' Message, NULL collectionid, NULL bookid
						ROLLBACK
						RETURN
					END

					
					--  �p�G����L�ɾ\��
					IF EXISTS ( SELECT 1 FROM Reservation re WHERE collectionId = @collectionId AND reservationStatusId = 2 )
					BEGIN
						COMMIT
						SELECT 1 ResultCode,   N'����L�ɾ\�̦^��'  Message, @collectionId AS collectionid, @bookid  AS bookid
						RETURN 
					END

					-- �p�G�S����L�ɾ\��~��sBook�i�ɾ\(1)
					UPDATE Book WITH(ROWLOCK, UPDLOCK) SET bookStatusId = 1
					WHERE bookCode = @BookCode  

					IF @@ROWCOUNT = 0 
					BEGIN 
						SELECT 0 ResultCode, N'��s���y�i�ɾ\���A����' Message, NULL collectionid, NULL bookid
						ROLLBACK
						RETURN
					END

					SELECT 1 ResultCode, (@BookCode + N'�k�٦��\!' ) Message, NULL collectionid, NULL bookid
					COMMIT
					RETURN
				END

				-- �ӥ��Ѥ��s�b
				ROLLBACK
				SELECT 0 ResultCode, N'�ӥ��Ѥ��s�b' Message
				RETURN
		END TRY
		BEGIN CATCH
				SELECT 0 ResultCode, N'�o�Ϳ��~: '+ ERROR_MESSAGE() Message
				ROLLBACK
				RETURN
		END CATCH
END
GO
--------------------------------------------------------------------------------
---�Y�N�O������_�q��
CREATE PROC NotificationAboutToExpireToEmail
	@OverDue OverDueOneToThreeTVP READONLY
AS
BEGIN
	SET NOCOUNT ON
	INSERT INTO Notification (cid, message, notificationDate)
	SELECT
		Cid,
		N'�i�Y�N�O���q���j�˷R�� ' + ClientName +
		N' �A�z�ҭɾ\�� ' + Title +
		N' �N�� ' + CONVERT(NVARCHAR, DueDays, 111) +
		N' �O���A�Z���ٮѴ����ȳ�' + CONVERT(NVARCHAR, Days) +
		N' �ѡC�о��t�k�١C�Ϯ��]�޲z�t�� �q�W�C',
		GETDATE()
	FROM @OverDue od
	SELECT 1 ResultCode, N'�Ҧ��Y�N�w���q���w�o�񦨥\' Message 
END
GO
--------------------------------------------------------------------------------
--���ѹO���Ƶ{_�q���w���̤w��������

ALTER PROC NotificationOverdue
    @OverDue OverDueTVP3 READONLY
AS
BEGIN
	SET NOCOUNT ON
    BEGIN TRY
		INSERT INTO Notification (cid, message, notificationDate )
		SELECT
				od.cid,
				N'�i�w�������q���j�˷R�� ' + cli.cName +
                       N' �A�z�ҹw���� �i' + col.title + 
                       N'�j ���� ' + CONVERT(NVARCHAR, DATEADD(DAY, -1, GETDATE()), 111) +' �e���ѡA�t�Τw�����A�p���ݭn�Э��s�w���A����!!',
				GETDATE()
		FROM @OverDue od
		JOIN Client cli ON od.cid = cli.cid 
		JOIN Collection col ON col.collectionId = od.collectionId
    END TRY
    BEGIN CATCH
        RETURN
    END CATCH
END
GO

--���ѹO���Ƶ{_���o���y�̦��w��TVF
ALTER FUNCTION GetEarliestReservationTVF
(
	@InputTable DueBookTVP READONLY
)
RETURNS @RESULT TABLE (
		reservationId INT,
		collectionid INT,
		cid INT,
		bookid INT,
		reservationDate DATETIME,
		reservationStatus NVARCHAR(50)
)
AS 
BEGIN
		INSERT INTO @RESULT
		SELECT 
				re.reservationId,
				re.collectionid,
				re.cId,
				re.bookid,
				re.reservationDate,
				rs.reservationStatus
		FROM (
			SELECT 
				re.reservationId,  
				re.collectionid, 
				re.cid, 
				tvp.bookId,
				re.reservationDate, 
				re.reservationStatusId,
				ROW_NUMBER() OVER(PARTITION BY re.collectionId  ORDER BY  re.reservationDate ASC) rk
				FROM Reservation re
				JOIN @InputTable tvp ON re.collectionid = tvp.collectionid
				WHERE re.reservationStatusId = 2
			) AS re
			JOIN ReservationStatus rs ON re.reservationStatusId = rs.reservationStatusId
			WHERE re.rk = 1
			RETURN;
END
GO

--���ѹO���Ƶ{_�q���w���̨���
ALTER PROC NotificationBookerTVPvsersion
    @reservationer OverDueTVP3 READONLY
AS
BEGIN
	SET NOCOUNT ON
    BEGIN TRY
			INSERT INTO Notification (cid, [message], notificationDate)
			SELECT  
				cli.cid,
				N'�i���ѳq���j�˷R�� ' + cli.cName +
                       N' �A�z�ҹw������ �i' + col.title + 
                       N'�j�w�i�H�ɾ\�A�Щ�'+ CONVERT(NVARCHAR, DATEADD(DAY, 2, GETDATE()), 111)+'�Ѥ��쥻�]�ɮѡA����!!',
					   GETDATE()
			FROM @reservationer re 
			JOIN Client cli ON re.cid = cli.cid
			JOIN Collection col ON re.collectionId = col.collectionId
    END TRY
    BEGIN CATCH
        RETURN
    END CATCH
END
GO

--���ѹO���Ƶ{_�ˬd��L�w���̨ç�s���y���A
ALTER PROC CheckReservationSchedule
		@DueBook DueBookTVP READONLY
AS 
BEGIN
	SET NOCOUNT ON
    BEGIN TRY
		-- 1�ΨӦs��-���y�S���w���̪�TVP
		DECLARE @bookList  OverDueTVP3;
		-- 2�ΨӦs��-���y����L�w���̪�TVP
		DECLARE @reservationList OverDueTVP3;
		
		-- 1.���o�S���w������
		INSERT INTO @bookList (collectionId, bookid)
		SELECT  collectionId, bookid 
		FROM @DueBook bok 
		WHERE NOT EXISTS 
		( SELECT 1 FROM Reservation re WHERE re.collectionId = bok.collectionId   AND reservationStatusId IN ( 2, 3)  )

		 --1.1 ��s���y���A�� 1.�i�ɾ\
		IF EXISTS (SELECT 1 FROM @bookList)
		BEGIN
					UPDATE  Book WITH(ROWLOCK, UPDLOCK) SET bookStatusId = 1
					FROM Book bok JOIN @bookList boklist ON bok.bookid = boklist.bookid AND bok.collectionId = boklist.collectionId
		END

        --2.���o���y�̦��w�����H ok
		INSERT INTO @reservationList (reservationId, cid, bookid,collectionid )
        SELECT reservationId,  cid,bookid,collectionid 
        FROM GetEarliestReservationTVF(@DueBook)
		
        -- 2.2��s�w�����A"�i����"�B�T�Ѩ��Ѯɶ� ok
        UPDATE Reservation WITH(ROWLOCK, UPDLOCK)
        SET bookid = rlist.bookid, reservationStatusId = 3, dueDateR = DATEADD(DAY, 3, GETDATE())
        FROM Reservation re JOIN @reservationList rlist ON re.reservationId = rlist.reservationId

		--2.3�q���w���� ok
		IF EXISTS ( SELECT 1 FROM @reservationList)
		BEGIN
				EXEC NotificationBookerTVPvsersion  @reservationer = @reservationList
		END

		--�o�̭n�^�Ǩ� �X�h! �n���W�r �B���y
        SELECT 1 ResultCode, N'�^�ǤU�@��w���̦W��' Message, u.cName, col.title, u.cAccount
		FROM @reservationList list
		JOIN Collection col ON list.collectionId = col.collectionId
		JOIN Client u ON u.cId = list.cid

    END TRY
    BEGIN CATCH
        SELECT 0 ResultCode, N'�o�Ϳ��~:' + ERROR_MESSAGE() Message,  NULL Name, NULL title, NULL cAccount
        RETURN
    END CATCH
END 
GO

--���ѹO���Ƶ{_�D�nPROC
ALTER PROC OverDue
AS
BEGIN
	SET NOCOUNT ON
	SET TRANSACTION ISOLATION LEVEL READ COMMITTED
	BEGIN TRY
		BEGIN TRANSACTION
		DECLARE @OverDueList OverDueTVP3
		-- �x�s���ѹO����
		INSERT INTO @OverDueList ( reservationId, cid, collectionId, bookId, dueDateB )
		SELECT reservationId, cid, collectionId, bookId, dueDateR
		FROM Reservation
		WHERE reservationStatusId = 3 AND dueDateR < GETDATE()

		-- �ˬd�O�_�����ѹO����
		IF NOT EXISTS ( SELECT 1 FROM @OverDueList)
		BEGIN
			ROLLBACK
			SELECT 0 ResultCode, N'�S���O����!' Message, NULL AS reservationId  , NULL AS cid, NULL AS  borrowId, NULL AS  collectionId, NULL AS bookId, NULL AS  cName, NULL AS  title, NULL AS  cAccount, NULL AS  dueDateB
			RETURN
		END
		
		-- ���ѹO���̧�窱�A ���ѹO��
		UPDATE Reservation WITH(ROWLOCK,UPDLOCK) SET reservationStatusId = 4
		WHERE reservationId IN ( SELECT reservationId FROM @OverDueList);
		
		IF (@@ROWCOUNT = 0)
		BEGIN 
			ROLLBACK
			SELECT 0 ResultCode, N'�L�O�������C' Message
			RETURN
		END

		-- �����q���O���̭� 
		EXEC NotificationOverdue @OverDue = @OverDueList

		-- �^�� @OverDueList
		SELECT 1 ResultCode, N'�O���̭�' Message,  reservationId, ov.cid,ov.borrowId, ov.collectionId, bookId, cli.cName, col.title, cli.cAccount, ov.dueDateB
		FROM @OverDueList ov
		JOIN Client cli ON ov.cid = cli.cId
		JOIN Collection col ON ov.collectionId = col.collectionId

		COMMIT
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK;
		SELECT 0 ResultCode, N'���楢��' + ERROR_MESSAGE() Message;
	END CATCH
END
GO

--------------------------------------------------------------------------------
--�ɾ\�O���Ƶ{_�w���q��
ALTER PROC NotificationOverdueBorrow
    @OverDue OverDueTVP2 READONLY
AS
BEGIN
	SET NOCOUNT ON
    BEGIN TRY
		INSERT INTO Notification (cid, message, notificationDate )
		SELECT
				od.cid,
				N'�i�O��ĵ�i�q���j�˷R�� ' + cli.cName +
                       N' �A�z�ҭɾ\�� ' + col.title + 
                       N' ���� ' + CONVERT(NVARCHAR, od.dueDateB, 111) + N' �e�ٮѡA�кɳt�ٮѡC',
				GETDATE()
		FROM @OverDue od
		JOIN Client cli ON od.cid = cli.cid 
		JOIN Book bok ON od.bookid = bok.bookId
		JOIN Collection col ON bok.collectionId = col.collectionId
    END TRY
    BEGIN CATCH
        RETURN
    END CATCH
END
GO

--�ɾ\�O���Ƶ{_ �D�n�ɾ\�w��PROC 
CREATE PROC LateReturn2Email
AS
BEGIN
		SET NOCOUNT ON
		SET TRANSACTION ISOLATION LEVEL READ COMMITTED
		BEGIN TRY
			BEGIN TRANSACTION
			DECLARE @DueList OverDueTVP2;
			

			INSERT INTO @DueList ( cid, bookid,borrowId, dueDateB)
			SELECT  cid, bookid,borrowId, dueDateB
			FROM Borrow
			WHERE dueDateB < GETDATE() AND borrowStatusId = 2 OR (  borrowStatusId = 3 AND  returnDate IS NULL)

			IF NOT EXISTS ( SELECT 1 FROM @DueList)
			BEGIN
				SELECT 0 ResultCode, N'�L�O���k�٪�' Message, NULL cName , NULL cAccount , NULL title  
				ROLLBACK
				RETURN 
			END

			 --��s�O���k�٪̪����A(�O��)
			UPDATE Borrow WITH(ROWLOCK,UPDLOCK) SET borrowStatusId = 3
			FROM Borrow bow JOIN @DueList due ON bow.borrowId = due.borrowId AND bow.cid = due.cid
			WHERE borrowStatusId = 2

			-- �q��
			EXEC NotificationOverdueBorrow @OverDue = @DueList

			-- �^��
			SELECT 1 ResultCode, N'�^�ǹO�����' Message, cli.cName , cli.cAccount , col.title  
			FROM @DueList due 
			JOIN Client cli ON due.cid = cli.cid
			JOIN Book bok ON bok.bookId = due.bookid
			JOIN Collection col ON bok.collectionId = col.collectionId

			COMMIT
		END TRY

		BEGIN CATCH
			IF @@TRANCOUNT > 0 
			ROLLBACK
			SELECT 0 ResultCode, N'�X�{���~' + ERROR_MESSAGE() Message, NULL cName , NULL cAccount , NULL title  
		END CATCH
END
GO

--------------------------------------------------------------------------------
-- ���y�޲zTVF
ALTER FUNCTION BookQueryResultView()
RETURNS TABLE
AS
RETURN(
	SELECT col.collectionId, col.isbn ,col.collectionImg , title, auth.author, col.collectionDesc, col.publisher, col.publishDate, typ.type,col.translator,lan.language, ISNULL(COUNT(*), 0) NumberOfBook
	FROM Collection col 
	JOIN Author auth ON col.authorId = auth.authorId
	JOIN Language lan ON col.languageId = lan.languageId
	JOIN Type typ ON col.typeId = typ.typeId
	LEFT JOIN Book bok ON col.collectionId = bok.collectionId
	GROUP BY col.collectionId,col.isbn, collectionImg, title, auth.author,col.collectionDesc, col.publisher, col.publishDate, typ.type,col.translator,lan.language
)
GO
--------------------------------------------------------------------------------
DROP PROC LateReturn
DROP PROC LateReturnOneToThree
DROP PROC NotificationAboutToExpire