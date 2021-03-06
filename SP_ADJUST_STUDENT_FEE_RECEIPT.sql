USE [AWSS_21_22]
GO
/****** Object:  StoredProcedure [dbo].[ADJUST_STUDENT_FEE_RECEIPT]    Script Date: 25/03/2022 14:15:54 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[ADJUST_STUDENT_FEE_RECEIPT]	(	@ADMISSION_NUMBER	NVARCHAR(50),
														@ROLL_NUMBER		NVARCHAR(50)= '0',
														@CLASS_MASTER_ID	INT,
														@AMOUNT				DECIMAL(20,2),
														@RECEIPT_TYPE_ID	INT,
														@FEE_HEAD_ID        INT = 0,
														@SORT_ID			INT,
														@COMMON_DB_NAME		NVARCHAR(100),
														@SESSION_ID			NVARCHAR(100),
														@TIME_STAMP			INT,
														@USER_MASTER_ID		INT
													)
AS
BEGIN
	DECLARE @STUDENT_MASTER_ID AS INTEGER
	DECLARE @ERROR_MESSAGE AS NVARCHAR(MAX)

	DECLARE @MONTH_SORT AS TABLE	(	MONTH_NUMBER	INT,
										SORTID			INT
									)

	DECLARE @APR_CLASS_MASTER_ID AS INTEGER

	IF LEN(@ADMISSION_NUMBER) = 0
	BEGIN
		SELECT		@ADMISSION_NUMBER = ADMISSION_NUMBER
		FROM		STUDENT_MASTER
		WHERE		ROLL_NUMBER = @ROLL_NUMBER
	END


	INSERT INTO @MONTH_SORT (MONTH_NUMBER, SORTID) VALUES (-1, 0)
	INSERT INTO @MONTH_SORT (MONTH_NUMBER, SORTID) VALUES (0, 1)
	INSERT INTO @MONTH_SORT (MONTH_NUMBER, SORTID) VALUES (4, 2)
	INSERT INTO @MONTH_SORT (MONTH_NUMBER, SORTID) VALUES (5, 3)
	INSERT INTO @MONTH_SORT (MONTH_NUMBER, SORTID) VALUES (6, 4)
	INSERT INTO @MONTH_SORT (MONTH_NUMBER, SORTID) VALUES (7, 5)
	INSERT INTO @MONTH_SORT (MONTH_NUMBER, SORTID) VALUES (8, 6)
	INSERT INTO @MONTH_SORT (MONTH_NUMBER, SORTID) VALUES (9, 7)
	INSERT INTO @MONTH_SORT (MONTH_NUMBER, SORTID) VALUES (10, 8)
	INSERT INTO @MONTH_SORT (MONTH_NUMBER, SORTID) VALUES (11, 9)
	INSERT INTO @MONTH_SORT (MONTH_NUMBER, SORTID) VALUES (12, 10)
	INSERT INTO @MONTH_SORT (MONTH_NUMBER, SORTID) VALUES (1, 11)
	INSERT INTO @MONTH_SORT (MONTH_NUMBER, SORTID) VALUES (2, 12)
	INSERT INTO @MONTH_SORT (MONTH_NUMBER, SORTID) VALUES (3, 13)


	/*Deleting Records which are older than a Day*/
	DELETE
	FROM		[FEE_RECEIPT_TEMP_ADJUSTMENT]
	WHERE		USER_MASTER_ID = @USER_MASTER_ID




	SELECT		@STUDENT_MASTER_ID = ID,
				@APR_CLASS_MASTER_ID = APR_CLASS_MASTER_ID
	FROM		STUDENT_MASTER
	WHERE		ADMISSION_NUMBER = @ADMISSION_NUMBER




	IF (ISNULL(@STUDENT_MASTER_ID, 0) = 0)
	BEGIN
		IF LEN(@ADMISSION_NUMBER) = 0
		BEGIN
			SET @ERROR_MESSAGE = 'Sorry! Unable to find record of Roll No. [' + @ROLL_NUMBER + ']'
		END
		ELSE
		BEGIN
			SET @ERROR_MESSAGE = 'Sorry! Unable to find record of Admission No. [' + @ADMISSION_NUMBER + ']'
		END
		
		;THROW 99000, @ERROR_MESSAGE, 1
	END




	/*Deleting Records of Selected Student*/
	DELETE
	FROM		[FEE_RECEIPT_TEMP_ADJUSTMENT]
	WHERE		USER_MASTER_ID = @USER_MASTER_ID
	AND			SESSION_ID = @SESSION_ID
	AND			TIME_STAMP = @TIME_STAMP
	AND			STUDENT_MASTER_ID = @STUDENT_MASTER_ID




	DECLARE @FEE_HEAD_MASTER_ID AS INTEGER
	DECLARE @MONTH_NUMBER AS INTEGER
	DECLARE @CURRENT_CLASS_MASTER_ID AS INTEGER
	DECLARE @BALANCE_AMOUNT AS DECIMAL(20, 2)
	DECLARE @ADJUSTED_AMOUNT AS DECIMAL(20, 2)
	DECLARE @REMAINING_AMOUNT AS DECIMAL(20, 2)

	SET @REMAINING_AMOUNT = @AMOUNT


	DECLARE CUR_RECEIPT_ADJUSTMENT CURSOR FOR	SELECT		BAL.FEE_HEAD_MASTER_ID,
															BAL.MONTH_NUMBER,
															BAL.CLASS_MASTER_ID,
															SUM(BAL.SLIP_AMOUNT - BAL.RECEIPT_AMOUNT) AS AMOUNT
												FROM		(	SELECT		FEE_HEAD_MASTER_ID,
																			MONTH_NUMBER,
																			CLASS_MASTER_ID,
																			SUM(CALCULATION_TYPE * AMOUNT) AS SLIP_AMOUNT,
																			0 AS RECEIPT_AMOUNT
																FROM		STUDENT_FEE_SLIP SLIP
																WHERE		STUDENT_MASTER_ID = @STUDENT_MASTER_ID
																AND			CLASS_MASTER_ID = @CLASS_MASTER_ID
																GROUP BY	FEE_HEAD_MASTER_ID,
																			MONTH_NUMBER,
																			CLASS_MASTER_ID
																
																UNION ALL
																
																SELECT		SDOB.FEE_HEAD_MASTER_ID,
																			-1 AS MONTH_NUMBER,
																			@APR_CLASS_MASTER_ID,
																			SUM(SDOB.AMOUNT) AS SLIP_AMOUNT,
																			0 AS RECEIPT_AMOUNT
																FROM		STUDENT_OPENING_BALANCE SOB
																INNER JOIN	STUDENT_DEBIT_OPENING_BALANCE SDOB
																ON			SOB.ID = SDOB.STUDENT_OPENING_BALANCE_ID
																WHERE		SOB.STUDENT_MASTER_ID = @STUDENT_MASTER_ID
																GROUP BY	SDOB.FEE_HEAD_MASTER_ID
																
																UNION ALL
																
																SELECT		FRI.FEE_HEAD_MASTER_ID,
																			FRI.MONTH_NUMBER,
																			FRI.CLASS_MASTER_ID,
																			0 AS SLIP_AMOUNT,
																			SUM(FRI.AMOUNT)		AS RECEIPT_AMOUNT
																FROM		FEE_RECEIPT_INV FRI
																INNER JOIN  FEE_RECEIPT_MAIN FRM
																ON			FRI.FEE_RECEIPT_MAIN_ID = FRM.ID
																WHERE		FRI.STUDENT_MASTER_ID = @STUDENT_MASTER_ID
																AND			FRI.CLASS_MASTER_ID = @CLASS_MASTER_ID
																AND			FRM.IS_CANCELLED = 0
																GROUP BY	FRI.FEE_HEAD_MASTER_ID,
																			FRI.MONTH_NUMBER,
																			FRI.CLASS_MASTER_ID
																
																UNION ALL
																
																SELECT		SCOB.FEE_HEAD_MASTER_ID,
																			SCOB.MONTH_NUMBER,
																			@APR_CLASS_MASTER_ID,
																			0 AS SLIP_AMOUNT,
																			SUM(SCOB.AMOUNT) AS RECEIPT_AMOUNT
																FROM		STUDENT_OPENING_BALANCE SOB
																INNER JOIN	STUDENT_CREDIT_OPENING_BALANCE_MONTH_WISE SCOB
																ON			SOB.ID = SCOB.STUDENT_OPENING_BALANCE_ID
																WHERE		SOB.STUDENT_MASTER_ID = @STUDENT_MASTER_ID
																GROUP BY	SCOB.FEE_HEAD_MASTER_ID,
																			SCOB.MONTH_NUMBER
															)BAL
												INNER JOIN	FEE_HEAD_MASTER FHM
												ON			FHM.ID = BAL.FEE_HEAD_MASTER_ID
												INNER JOIN	@MONTH_SORT MS
												ON			MS.MONTH_NUMBER = BAL.MONTH_NUMBER
												WHERE       FHM.ID = CASE WHEN @FEE_HEAD_ID > 0 THEN @FEE_HEAD_ID ELSE FHM.ID END
												GROUP BY	BAL.FEE_HEAD_MASTER_ID,
															BAL.MONTH_NUMBER,
															BAL.CLASS_MASTER_ID,
															MS.SORTID,
															FHM.SORTID
												ORDER BY	MS.SORTID,
															FHM.SORTID

	OPEN CUR_RECEIPT_ADJUSTMENT
	FETCH NEXT FROM CUR_RECEIPT_ADJUSTMENT INTO @FEE_HEAD_MASTER_ID, @MONTH_NUMBER, @CURRENT_CLASS_MASTER_ID, @BALANCE_AMOUNT

	WHILE @@FETCH_STATUS = 0 AND @REMAINING_AMOUNT > 0
	BEGIN
		SET @ADJUSTED_AMOUNT = 0
		
		IF (@BALANCE_AMOUNT >= @REMAINING_AMOUNT)
		BEGIN
			SET @ADJUSTED_AMOUNT = @REMAINING_AMOUNT
			SET @REMAINING_AMOUNT = 0
		END
		
		IF (@BALANCE_AMOUNT < @REMAINING_AMOUNT)
		BEGIN
			SET @ADJUSTED_AMOUNT = @BALANCE_AMOUNT
			SET @REMAINING_AMOUNT = @REMAINING_AMOUNT - @ADJUSTED_AMOUNT
		END
		
		INSERT INTO [FEE_RECEIPT_TEMP_ADJUSTMENT]	(	USER_MASTER_ID,
														SESSION_ID,
														TIME_STAMP,
														RECEIPT_TYPE_ID,
														STUDENT_MASTER_ID,
														FEE_HEAD_MASTER_ID,
														MONTH_NUMBER,
														QUANTITY,
														RATE,
														ADJUSTED_AMOUNT,
														STUDENT_SORTID,
														CLASS_MASTER_ID
													)
											VALUES	(	@USER_MASTER_ID,
														@SESSION_ID,
														@TIME_STAMP,
														@RECEIPT_TYPE_ID,
														@STUDENT_MASTER_ID,
														@FEE_HEAD_MASTER_ID,
														@MONTH_NUMBER,
														0,
														0,
														@ADJUSTED_AMOUNT,
														@SORT_ID,
														@CURRENT_CLASS_MASTER_ID
													)
		
		FETCH NEXT FROM CUR_RECEIPT_ADJUSTMENT INTO @FEE_HEAD_MASTER_ID, @MONTH_NUMBER, @CURRENT_CLASS_MASTER_ID, @BALANCE_AMOUNT
	END
	
	CLOSE CUR_RECEIPT_ADJUSTMENT
	DEALLOCATE CUR_RECEIPT_ADJUSTMENT
	
	
	
	
	IF (ISNULL(@REMAINING_AMOUNT, 0) > 0)
	BEGIN
		IF LEN(@ADMISSION_NUMBER) = 0
		BEGIN
			SET @ERROR_MESSAGE = 'Sorry! Unable to Adjust Rs. ' + CONVERT(NVARCHAR, CONVERT(DECIMAL(20, 2), @AMOUNT)) + ' for Roll No. [' + @ROLL_NUMBER + '] because of insufficient balance amount. Unadjusted Amount is Rs. ' + CONVERT(NVARCHAR, CONVERT(DECIMAL(20,2), @REMAINING_AMOUNT)) 
		END
		ELSE
		BEGIN
			SET @ERROR_MESSAGE = 'Sorry! Unable to Adjust Rs. ' + CONVERT(NVARCHAR, CONVERT(DECIMAL(20, 2), @AMOUNT)) + ' for Admission No. [' + @ADMISSION_NUMBER + '] because of insufficient balance amount. Unadjusted Amount is Rs. ' + CONVERT(NVARCHAR, CONVERT(DECIMAL(20,2), @REMAINING_AMOUNT)) 
		END
		
		;THROW 99000, @ERROR_MESSAGE, 1
	END
	
	
	

	
	--SELECT		SM.ID					AS StudentMasterId,
	--			SM.ADMISSION_NUMBER		AS AdmissionNumber,
	--			SM.ROLL_NUMBER			AS RollNumber,
	--			SM.NAME					AS StudentMasterName,
	--			SM.FATHER_NAME			AS FatherName,
	--			CM.NAME					AS ClassName,
	--			SM.FATHER_MOBILE		AS MobileNumber,
	--			@AMOUNT					AS Amount,
	--			1						AS IsSelected
	--FROM		STUDENT_MASTER SM
	--INNER JOIN	CLASS_MASTER CM
	--ON			SM.CLASS_MASTER_ID = CM.ID
	--INNER JOIN	STUDENT_FEE_SLIP SFS
	--ON			SFS.CLASS_MASTER_ID = CM.ID
	--AND			SFS.STUDENT_MASTER_ID = @STUDENT_MASTER_ID
	--WHERE		SM.ID = @STUDENT_MASTER_ID


	SELECT		SM.ID					AS StudentMasterId,
				SM.ADMISSION_NUMBER		AS AdmissionNumber,
				SM.ROLL_NUMBER			AS RollNumber,
				SM.[NAME]				AS StudentMasterName,
				SM.FATHER_NAME			AS FatherName,
				CM.ID					AS ClassMasterId,
				CM.[NAME]				AS ClassName,
				SM.FATHER_MOBILE		AS MobileNumber,
				@AMOUNT					AS Amount,
				1						AS IsSelected
	FROM		STUDENT_MASTER SM
	INNER JOIN	STUDENT_FEE_SLIP SFS
	ON			SFS.STUDENT_MASTER_ID = SM.ID
	INNER JOIN	CLASS_MASTER CM
	ON			SFS.CLASS_MASTER_ID = CM.ID
	WHERE		SM.ID = @STUDENT_MASTER_ID
	AND			SFS.CLASS_MASTER_ID = @CLASS_MASTER_ID
	GROUP BY	SM.ID,
				SM.ADMISSION_NUMBER,
				SM.ROLL_NUMBER,
				SM.[NAME],
				SM.FATHER_NAME,
				CM.ID,
				CM.[NAME],
				SM.FATHER_MOBILE
END
