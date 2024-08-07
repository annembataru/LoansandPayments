
--select * from vw_CustomerAccounts where AccountNumber='032506' and CustomerAccountType_TargetProductid='4BE0F1AA-8113-4181-9B5C-94A96F1F92E9'
--sp_CalculateInterestArrears 'D22A4CE8-1D02-EF11-A32A-000C29977841','07/31/2024'
ALTER  PROCEDURE [dbo].[sp_CalculateInterestArrears] (
  @CustomerAccountID UNIQUEIDENTIFIER, @EndDate DATETIME
)
AS

BEGIN

	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	
	DECLARE @InterestArrears DECIMAL(18, 2) = 0;
    DECLARE @InterestChargeDate DATE;
    DECLARE @GracePeriodEndDate DATE;
    DECLARE @GracePeriod INT;
	DECLARE @LoancaseGracePeriod INT;
    DECLARE @InterestAmount DECIMAL(18, 2);
	DECLARE @EndDate_Sniff DATETIME = @EndDate;
	Declare @LoanProductId uniqueidentifier;

	set @LoanProductId =(select CustomerAccountType_TargetProductId from CustomerAccounts where Id=@CustomerAccountID)

	IF LEFT(CAST(@EndDate_Sniff AS TIME),5) = '00:00'
	BEGIN
		SET @EndDate_Sniff = (SELECT DATEADD(day, DATEDIFF(day, 0, @EndDate_Sniff), '23:59:59'));
	END

    -- Get the latest interest charge date for transaction code 24
    SET @InterestChargeDate = (
        SELECT MAX(JE.CreatedDate)
        FROM vw_customeraccounts ca
        INNER JOIN journalentries je ON ca.id = je.CustomerAccountId AND InterestReceivable = je.ChartOfAccountId
        INNER JOIN journals j ON j.id = je.JournalId
        WHERE ca.id = @CustomerAccountID and Amount<0 AND j.TransactionCode = 24
    );

    -- Get the grace period for the employer associated with the account
    SET @GracePeriod = (
        SELECT top 1 LoanInterestArrearsGracePeriod 
        FROM Employers 
        INNER JOIN vw_CustomerAccounts CA ON CA.EmployerID = Employers.ID
        WHERE ca.id = @CustomerAccountID
    );

    -- Get the grace period from loan product setup if employer's setup is not specified
    IF @GracePeriod IS NULL
    BEGIN
        SET @LoanCaseGracePeriod = (
            SELECT  top 1 LoanRegistration_GracePeriod 
            FROM LoanCases 
            INNER JOIN vw_CustomerAccounts CA ON CA.LoanCaseId = LoanCases.ID
            WHERE CA.id = @CustomerAccountID
        );

        SET @GracePeriod = @LoanCaseGracePeriod;
    END;

    -- Calculate the grace period end date if both grace period and interest charge date are available
    IF @GracePeriod IS NOT NULL AND @InterestChargeDate IS NOT NULL
    BEGIN
        SET @GracePeriodEndDate = DATEADD(DAY, @GracePeriod, @InterestChargeDate);
    END
    ELSE
    BEGIN
        SET @GracePeriodEndDate = GETDATE(); -- Default to current date if not specified
    END;
    
    -- Check if the end date has surpassed the grace period
    IF @EndDate > @GracePeriodEndDate
    BEGIN
        -- Get the interest amount for the specified account up to the end date
        SELECT @InterestAmount = SUM(je.Amount) * -1
        FROM vw_customeraccounts ca
        INNER JOIN journalentries je ON ca.id = je.CustomerAccountId AND InterestReceivable = je.ChartOfAccountId
        WHERE ca.id = @CustomerAccountID AND je.CreatedDate <= @EndDate;

        -- Set the interest arrears if an amount is found
        IF @InterestAmount IS NOT NULL
        BEGIN
            SET @InterestArrears = @InterestAmount;
        END
    END
    ELSE
    BEGIN
        -- Get the interest amount for the specified account before the interest charge date
        SELECT @InterestAmount = SUM(je.Amount) * -1
        FROM vw_customeraccounts ca
        INNER JOIN journalentries je ON ca.id = je.CustomerAccountId AND InterestReceivable = je.ChartOfAccountId
        WHERE ca.id = @CustomerAccountID AND je.CreatedDate < @InterestChargeDate;

        -- Set the interest arrears if an amount is found
        IF @InterestAmount IS NOT NULL
        BEGIN
            SET @InterestArrears = @InterestAmount;
        END
    END;
	--Disregard Upfront loans interest charge mode
	SET @InterestArrears = iif((select loanInterest_ChargeMode from LoanProducts where Id=@LoanProductId)=768,0,@InterestArrears);
        
    -- Return the interest arrears
    SELECT @InterestArrears AS InterestArrears;
END;
