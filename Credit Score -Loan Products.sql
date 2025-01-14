
--select * from LoanProducts where Description like '%project%'
--select * from vw_CustomerAccounts where reference2='30680'
---select * from loanproducts where Description like '%project%'
--sp_CreditScoreFosaProducts 'C33DB1DE-642E-EC11-952E-E09D31F190DB', '48189237-8C6A-4A0A-8771-D259F3ABAD87',2

ALTER PROCEDURE [dbo].[sp_CreditScore]
(@CustomerID UNIQUEIDENTIFIER, 
 @ProductID  UNIQUEIDENTIFIER

)
AS
     SET NOCOUNT ON;
     DECLARE @Consecutive INT, @RepaymentPeriod MONEY, @NetSalary MONEY, @AverageNetSalary MONEY= 0.00, @TotalDeductions MONEY, @RetirementAge INT, @EmployeeAge INT, @BlackListed BIT, @Defaulter BIT, @FosaAccountBalance MONEY, @MinimumLoanAmount MONEY, @MaximumLoanAmount MONEY, @EmployerStatus BIT, @MemberStatus BIT, @MembershipPeriod INT, @CustomerAccountID UNIQUEIDENTIFIER, @CreditsCount INT, @Remarks VARCHAR(100), @LoanAmountInDefault MONEY, @AmountQualified MONEY, @LoanCode INT= 0, @TotalLoans MONEY, @TotalLoanBalance MONEY,  @TotalLoansDescription VARCHAR(50), @DepositBalance MONEY, @MinimumGuarantors INT, @RejectIfOwing BIT, @LoanPercentage NUMERIC(5, 2), @LoanBalance MONEY,@DepositMultiplier MONEY, @EmployerRestriction Int;
     DECLARE @DisbursementDate DATE, @EmployerClassificationDate DATE, @PaidLoanAmountFromSalary MONEY,@EmployerCode nvarchar(10),@VukaCharge MONEY,@UpfrontInterest MONEY,@APR float, @LoanRequestStatus INT,@NetDisbursed MONEY,@NetInterestOnDeposits MONEY,@DepositLastContributionDate Date;

     --select * from loanproducts where Description like '%project%'


	SET @LoanCode = ISNULL(
     (
         SELECT Code
         FROM LoanProducts
         WHERE id = @ProductID
     ), 0);

	  SET @APR = ISNULL(
     (
         SELECT LoanInterest_AnnualPercentageRate
         FROM LoanProducts
         WHERE id = @ProductID
     ), 0);
	 
	 
	 SET @EmployerCode =  
     (
         SELECT CompanyCode
         FROM Employers 
         WHERE id in(Select EmployerId from Customers where Id=@CustomerID)
     );
	 
     SET @EmployerRestriction =  
     (
         SELECT ThrottleScoring
         FROM Employers 
         WHERE id in(Select EmployerId from Customers where Id=@CustomerID)
     );
	 SET  @EmployerClassificationDate =  
    ISNULL((
         SELECT LoanClassificationDate
         FROM Employers 
         WHERE EnforceLoanClassificationDate=1 and id in(Select EmployerId from Customers where Id=@CustomerID)
     ),GETDATE());
	 
     SET @RejectIfOwing = ISNULL(
     (
         SELECT LoanRegistration_RejectIfMemberHasBalance
         FROM LoanProducts
         WHERE id = @ProductID
     ), 0);
     SET @MinimumLoanAmount = ISNULL(
     (
         SELECT LoanRegistration_MinimumAmount
         FROM LoanProducts
         WHERE id = @ProductID
     ), 0);
     SET @MinimumGuarantors = ISNULL(
     (
         SELECT LoanRegistration_MinimumGuarantors
         FROM LoanProducts
         WHERE id = @ProductID
     ), 0);
     SET @MaximumLoanAmount = ISNULL(
     (
         SELECT LoanRegistration_MaximumAmount
         FROM LoanProducts
         WHERE id = @ProductID
     ), 0);
     SET @Consecutive = ISNULL(
     (
         SELECT LoanRegistration_ConsecutiveIncome
         FROM LoanProducts
         WHERE id = @ProductID
     ), 0);
     SET @RepaymentPeriod = ISNULL(
     (
         SELECT LoanRegistration_TermInMonths
         FROM LoanProducts
         WHERE id = @ProductID
     ), 0);
     SET @EmployeeAge = ISNULL(
     (
         SELECT DATEDIFF(hour, Individual_BirthDate, GETDATE()) / 8766 AS AgeYearsIntTrunc
         FROM Customers
              INNER JOIN Employers ON Customers.EmployerId = employers.Id
         WHERE Customers.id = @CustomerID
     ), 0);
     SET @MembershipPeriod = ISNULL(
     (
         SELECT LoanRegistration_MinimumMembershipPeriod
         FROM LoanProducts
         WHERE id = @ProductID
     ), 0);
     SET @MemberStatus = ISNULL(
     (
         SELECT MembershipStatus
         FROM Customers
         WHERE id = @CustomerID
     ), 0);
	-- select * from Loanproducts where description like '%default%'
    SET @TotalLoanBalance = ISNULL(
             (
                 SELECT SUM(dbo.JournalEntries.Amount)
                 FROM dbo.CustomerAccounts
                      INNER JOIN dbo.JournalEntries ON dbo.CustomerAccounts.Id = dbo.JournalEntries.CustomerAccountId
                      INNER JOIN dbo.LoanProducts ON dbo.CustomerAccounts.CustomerAccountType_TargetProductId = dbo.LoanProducts.Id
                                                          AND dbo.JournalEntries.ChartOfAccountId = dbo.LoanProducts.ChartOfAccountId
                 WHERE CustomerAccounts.CustomerId = @CustomerID and dbo.LoanProducts.Code not in(30,34)
                ), 0) * -1;
				 SET @DepositBalance = ISNULL(
             (
                 SELECT SUM(JournalEntries.amount)
                 FROM dbo.JournalEntries
                      INNER JOIN dbo.CustomerAccounts ON dbo.JournalEntries.CustomerAccountId = dbo.CustomerAccounts.Id
                      INNER JOIN dbo.InvestmentProducts ON dbo.CustomerAccounts.CustomerAccountType_TargetProductId = dbo.InvestmentProducts.Id
                                                                AND dbo.JournalEntries.ChartOfAccountId = dbo.InvestmentProducts.ChartOfAccountId
                 WHERE CustomerAccounts.CustomerId = @CustomerID
                       AND InvestmentProducts.Code = 2
             ), 0);
	  SET @DepositMultiplier= ISNULL(
             (
                 SELECT SUM(JournalEntries.amount)
                 FROM dbo.JournalEntries
                      INNER JOIN dbo.CustomerAccounts ON dbo.JournalEntries.CustomerAccountId = dbo.CustomerAccounts.Id
                      INNER JOIN dbo.InvestmentProducts ON dbo.CustomerAccounts.CustomerAccountType_TargetProductId = dbo.InvestmentProducts.Id
                                                                AND dbo.JournalEntries.ChartOfAccountId = dbo.InvestmentProducts.ChartOfAccountId
                 WHERE CustomerAccounts.CustomerId = @CustomerID
                       AND InvestmentProducts.Code = 2
             ), 0)*4;
		 SET @DepositLastContributionDate = ISNULL(
             (
                 SELECT Max(JournalEntries.CreatedDate)
                 FROM dbo.JournalEntries
                      INNER JOIN dbo.CustomerAccounts ON dbo.JournalEntries.CustomerAccountId = dbo.CustomerAccounts.Id
                      INNER JOIN dbo.InvestmentProducts ON dbo.CustomerAccounts.CustomerAccountType_TargetProductId = dbo.InvestmentProducts.Id
                                                                AND dbo.JournalEntries.ChartOfAccountId = dbo.InvestmentProducts.ChartOfAccountId
                 WHERE CustomerAccounts.CustomerId = @CustomerID
                       AND InvestmentProducts.Code = 2 and dbo.JournalEntries.CreatedDate<=@EmployerClassificationDate and dbo.JournalEntries.Amount>0 
             ),(SELECT max([Date])
                 FROM DepositContributions
                 WHERE CustomerId = @CustomerID
                  ));
		SET @TotalLoans = ISNULL(
             (
                 SELECT SUM(dbo.JournalEntries.Amount)
                 FROM dbo.CustomerAccounts
                      INNER JOIN dbo.JournalEntries ON dbo.CustomerAccounts.Id = dbo.JournalEntries.CustomerAccountId
                      INNER JOIN dbo.LoanProducts ON dbo.CustomerAccounts.CustomerAccountType_TargetProductId = dbo.LoanProducts.Id
                                                          AND dbo.JournalEntries.ChartOfAccountId = dbo.LoanProducts.ChartOfAccountId
                 WHERE CustomerAccounts.CustomerId = @CustomerID
                       AND dbo.LoanProducts.LoanRegistration_TermInMonths >= 3
                       AND dbo.LoanProducts.LoanRegistration_LoanProductSection = 0
                       AND dbo.LoanProducts.LoanRegistration_Microcredit = 0 and LoanProducts.code not in (34,28,30,19,20,21)
					   --select * from loanproducts where description like '%defaulters%'
             ), 0) * -1;
             SET @TotalLoansDescription = ISNULL(
             (
                 SELECT TOP 1 dbo.LoanProducts.Description
                 FROM dbo.CustomerAccounts
                      INNER JOIN dbo.JournalEntries ON dbo.CustomerAccounts.Id = dbo.JournalEntries.CustomerAccountId
                      INNER JOIN dbo.LoanProducts ON dbo.CustomerAccounts.CustomerAccountType_TargetProductId = dbo.LoanProducts.Id
                                                          AND dbo.JournalEntries.ChartOfAccountId = dbo.LoanProducts.ChartOfAccountId
                 WHERE CustomerAccounts.CustomerId = @CustomerID
                       AND dbo.LoanProducts.LoanRegistration_TermInMonths >= 3
                       AND dbo.LoanProducts.LoanRegistration_LoanProductSection = 0
                       AND dbo.LoanProducts.LoanRegistration_Microcredit = 0 and LoanProducts.code not in (34,28,30)
                 GROUP BY dbo.LoanProducts.Description
                 HAVING SUM(dbo.JournalEntries.Amount) <> 0
             ), '');

     SET @LoanAmountInDefault = ISNULL(
     (
         SELECT SUM(a.LoanDefaultAmount)
         FROM vw_CustomerAccounts c
              CROSS APPLY [dbo].[LoanArrearsPosition](c.Id,getdate(),@EmployerClassificationDate,2) a
         WHERE c.CustomerId = @CustomerID
               AND c.CustomerAccountType_TargetProductId IN
         (
             SELECT id
             FROM LoanProducts
          ) --and LoanDefaultTimeline>31  
		  having SUM(a.LoanDefaultAmount)>0 ), 0);
	-- and LoanDefaultTimeline>=30), 0);
	-- END
     SET @FosaAccountBalance = ISNULL(
     (
         SELECT SUM(amount)
         FROM JournalEntries
              INNER JOIN CustomerAccounts ON JournalEntries.CustomerAccountId = CustomerAccounts.Id
         WHERE CustomerAccounts.CustomerId = @CustomerID
               AND CustomerAccountType_TargetProductId =
         (
             SELECT id
             FROM SavingsProducts
             WHERE code = 0
         )
               AND ChartOfAccountId =
         (
             SELECT ChartOfAccountId
             FROM SavingsProducts
             WHERE code = 0
         )
     ), 0);
     SET @CustomerAccountID =
     (
         SELECT id
         FROM CustomerAccounts
         WHERE CustomerId = @CustomerID
               AND CustomerAccountType_TargetProductId =
         (
             SELECT id
             FROM SavingsProducts
             WHERE code = 0
         )
     );
     SET @CreditsCount = ISNULL(
     (
         SELECT COUNT(*)
         FROM dbo.CreditBatches
              INNER JOIN dbo.CreditBatchEntries ON dbo.CreditBatches.Id = dbo.CreditBatchEntries.CreditBatchId
              INNER JOIN dbo.CreditTypes ON dbo.CreditBatches.CreditTypeId = dbo.CreditTypes.Id
         WHERE CustomerAccountId = @CustomerAccountID
               AND creditbatchentries.STATUS = 2
               AND dbo.CreditTypes.ThrottleScoring = 0
               AND creditbatchentries.CreatedDate >= DATEADD(mm, -3, GETDATE())
               AND type = 56026
     ), 0);
     SET @LoanBalance = ISNULL(
     (
         SELECT sum(a.LoanBalance) * -1
         FROM CustomerAccounts c
              CROSS APPLY [dbo].[LoanArrearsPosition](c.Id, GETDATE(),@EmployerClassificationDate,2) a
         WHERE c.CustomerId = @CustomerID
               AND c.CustomerAccountType_TargetProductId = @ProductID
     ), ISNULL((Select sum(amount) FROM  dbo.CustomerAccounts INNER JOIN
                         dbo.JournalEntries ON dbo.CustomerAccounts.Id = dbo.JournalEntries.CustomerAccountId 
						 where dbo.CustomerAccounts.CustomerId=@CustomerID and CustomerAccountType_TargetProductId=@ProductID and ChartOfAccountId in(select ChartOfAccountId from LoanProducts)),0)*-1);
     IF @LoanCode IN(18, 11, 12)
         BEGIN
             IF @CreditsCount < @Consecutive
                 BEGIN
                     SET @Remarks = 'Rejected: Consecutive Income falls short';
             END;
     END;
     SET @NetSalary = ISNULL(
     (
         SELECT TOP 1 Principal
         FROM dbo.CreditBatches
              INNER JOIN dbo.CreditBatchEntries ON dbo.CreditBatches.Id = dbo.CreditBatchEntries.CreditBatchId
              INNER JOIN dbo.CreditTypes ON dbo.CreditBatches.CreditTypeId = dbo.CreditTypes.Id
         WHERE CustomerAccountId = @CustomerAccountID
               AND creditbatchentries.STATUS = 2
               AND dbo.CreditTypes.ThrottleScoring = 0
               AND creditbatchentries.CreatedDate >= DATEADD(mm, -3, GETDATE())
               AND type = 56026
         ORDER BY CreditBatchEntries.CreatedDate DESC
     ), 0);


with cte ( principal ) as 
(
SELECT    top 3    dbo.JournalEntries.Amount principal
--into #Credits 
FROM            dbo.JournalEntries INNER JOIN
                         dbo.Journals ON dbo.JournalEntries.JournalId = dbo.Journals.Id
						  where JournalEntries.CustomerAccountId=@CustomerAccountID 
						  and
						  JournalEntries.CreatedDate>=dateadd(mm,-3,getdate()) and journals.TransactionCode=27 
						  and Journals.ParentId is null
						  and AlternateChannelLogId is null
						  and JournalEntries.ChartOfAccountId
						  in (select ChartOfAccountId from SavingsProducts where id ='99D4E297-12CA-48EC-832A-8B8353D89521') 
						  and Amount>0 
						   order by JournalEntries.CreatedDate desc
union 

SELECT TOP 3 Principal
    -- INTO #Credits
     FROM dbo.CreditBatches
          INNER JOIN dbo.CreditBatchEntries ON dbo.CreditBatches.Id = dbo.CreditBatchEntries.CreditBatchId
          INNER JOIN dbo.CreditTypes ON dbo.CreditBatches.CreditTypeId = dbo.CreditTypes.Id
     WHERE CustomerAccountId = @CustomerAccountID
           AND creditbatchentries.STATUS = 2
           AND dbo.CreditTypes.ThrottleScoring = 0
           AND creditbatchentries.CreatedDate >= DATEADD(mm, -3, GETDATE())
           AND type = 56026
     ORDER BY CreditBatchEntries.CreatedDate DESC)
	 select * into #Credits from cte
     SET @AverageNetSalary = ISNULL(
     (
         SELECT SUM(Principal)
         FROM #Credits
     ), 0) / 3;

     /*Get Standing Order Deductions*/

     --select * from [LoanArrearsPosition] ('F7AFD51C-3912-EC11-9E8F-E4115BB03D0A','10/08/2021')
     SELECT ISNULL(dbo.StandingOrders.Principal, 0) Total
     INTO #Deductions
     FROM dbo.StandingOrders
          INNER JOIN dbo.CustomerAccounts ON dbo.StandingOrders.BeneficiaryCustomerAccountId = dbo.CustomerAccounts.Id
     WHERE CustomerAccounts.CustomerId = @CustomerID
           AND StandingOrders.[Trigger] = 0
		   AND CustomerAccounts.CustomerAccountType_TargetProductId in (select id from LoanProducts)
           AND CustomerAccounts.CustomerAccountType_TargetProductId not in( '93AA49DB-23A0-469E-A113-F991268AFB90','A1A78590-7E36-4DB6-A231-A913E04C5AE3')
           AND dbo.StandingOrders.BeneficiaryCustomerAccountId NOT IN
     (
         SELECT id
         FROM CustomerAccounts
         WHERE CustomerId = @CustomerID
               AND CustomerAccountType_TargetProductId = @ProductID
     )
         AND BeneficiaryCustomerAccountId IN
     (
         SELECT id
         FROM vw_LoanBalancesscore
     );
     /*FOSA Flex*/

     IF @LoanCode = 11 --- /*FOSA Flex*/
         BEGIN
            
			SET @VukaCharge = ISNULL(@TotalLoans*0.04, 0);
    
             SET @TotalDeductions = ISNULL(
             (
                 SELECT SUM(Total)
                 FROM #Deductions
             ), 0);
             IF @TotalDeductions < (@AverageNetSalary)
                 BEGIN
                     SET @Remarks = 'Qualified';
                     SET @AmountQualified = 0.6 * 2 * (@AverageNetSalary - @TotalDeductions);
             END;
                 ELSE
                 BEGIN
                     SET @Remarks = 'Rejeced: Not Qualified Based on Income';
                     SET @AmountQualified = 0;
             END;
             IF @FosaAccountBalance < 500
                 BEGIN
                     SET @Remarks = 'Rejected: Fosa Balance Below 500';
                     SET @AmountQualified = 0;
             END;
   
			   IF @AmountQualified > @MaximumLoanAmount
			     BEGIN
			      SET @UpfrontInterest=(select sum(InterestPayment) from [dbo].[RepaymentSchedule] (@RepaymentPeriod,12,0,512, @APR, @MaximumLoanAmount,getdate(),1))
			     END;
			        ELSE
			     BEGIN
			       SET @UpfrontInterest=(select sum(InterestPayment) from [dbo].[RepaymentSchedule] (@RepaymentPeriod,12,0,512, @APR, @AmountQualified ,getdate(),1))
			       END;

			   IF @AmountQualified > @MaximumLoanAmount
                 BEGIN
                  SET @NetDisbursed =@MaximumLoanAmount-(@VukaCharge+@UpfrontInterest+@TotalLoans) 
			     END
			        ELSE 
			       SET @NetDisbursed =@AmountQualified-(@VukaCharge+@UpfrontInterest+@TotalLoans)
				
				   IF @NetDisbursed <1500
				 
                 BEGIN
                     SET @Remarks = 'Qualified Amount Less than Take Home';
                     SET @AmountQualified = 0;
             END;
         
             IF @LoanAmountInDefault < 0
               -- AND @LoanPercentage < 30
                 BEGIN
                     SET @Remarks = 'Rejected: You have Loan Arrears';
                     SET @AmountQualified = 0;
             END;
			 	   IF @EmployerCode not in (001,003,018,021,041,013,015)
                 BEGIN
                     SET @Remarks = 'Employer Restricted';
                     SET @AmountQualified = 0;
             END;
     END;
     IF @LoanCode = 12  ---FOSA Instant
         BEGIN
           
			 SET @VukaCharge = ISNULL(@TotalLoans*0.04, 0);
   
             SET @TotalDeductions = ISNULL(
             (
                 SELECT SUM(Total)
                 FROM #Deductions
             ), 0);
             IF @TotalDeductions < (@AverageNetSalary)
                 BEGIN
                     SET @Remarks = 'Qualified';
                     SET @AmountQualified = 0.6 * 3 * (@AverageNetSalary - @TotalDeductions);
             END;
                 ELSE
                 BEGIN
                     SET @Remarks = 'Not Qualified Based on Income';
                     SET @AmountQualified = 0;
             END;
             IF @FosaAccountBalance < 500
                 BEGIN
                     SET @Remarks = 'Fosa Balance Below 500';
                     SET @AmountQualified = 0;
             END;
			  IF @AmountQualified > @MaximumLoanAmount
			     BEGIN
			      SET @UpfrontInterest=(select sum(InterestPayment) from [dbo].[RepaymentSchedule] (@RepaymentPeriod,12,0,512, @APR, @MaximumLoanAmount,getdate(),1))
			     END;
			        ELSE
			     BEGIN
			       SET @UpfrontInterest=(select sum(InterestPayment) from [dbo].[RepaymentSchedule] (@RepaymentPeriod,12,0,512, @APR,@AmountQualified ,getdate(),1))
			       END;

			   IF @AmountQualified > @MaximumLoanAmount
                 BEGIN
                  SET @NetDisbursed =@MaximumLoanAmount-(@VukaCharge+@UpfrontInterest+@TotalLoans) 
			     END
			        ELSE 
			       SET @NetDisbursed =@AmountQualified-(@VukaCharge+@UpfrontInterest+@TotalLoans)
				
				   IF @NetDisbursed <1500
				 
                 BEGIN
                     SET @Remarks = 'Qualified Amount Less than Take Home';
                     SET @AmountQualified = 0;
             END;
             --IF --@LoanPercentage < 30 and 
             --    @TotalLoans > 0
             --    BEGIN
             --        SET @Remarks = 'Not Qualified:Outstanding Loan Balance of ' + @TotalLoansDescription;
             --        SET @AmountQualified = 0;
                    
                    
                     IF @LoanAmountInDefault < 0
                       -- AND @LoanPercentage < 30
                         BEGIN
                             SET @Remarks = 'Rejected: You have Loan Arrears';
                             SET @AmountQualified = 0;
                     END;
					 	   IF @EmployerCode not in (001,003,018,021,041,013,015)
                 BEGIN
                     SET @Remarks = 'Employer Restricted';
                     SET @AmountQualified = 0;
             END;
            -- END;
     END;
     IF @LoanCode = 25  ---Super Instant
         BEGIN
            
			  SET @VukaCharge = ISNULL(@TotalLoans*0.04, 0);

             SET @TotalDeductions = ISNULL(
             (
                 SELECT SUM(Total)
                 FROM #Deductions
             ), 0);
             IF @TotalDeductions < (@AverageNetSalary)
                 BEGIN
                     SET @Remarks = 'Qualified';
                     SET @AmountQualified = 0.6 * 6 * (@AverageNetSalary - @TotalDeductions);
					
             END;
                 ELSE
                 BEGIN
                     SET @Remarks = 'Not Qualified Based on Income ';
                     SET @AmountQualified = 0;
             END;
             IF @FosaAccountBalance < 500
                 BEGIN
                     SET @Remarks = 'Fosa Balance Below 500';
                     SET @AmountQualified = 0;
             END;
			  IF @AmountQualified > @MaximumLoanAmount
			     BEGIN
			      SET @UpfrontInterest=(select sum(InterestPayment) from [dbo].[RepaymentSchedule] (@RepaymentPeriod,12,0,512, @APR, @MaximumLoanAmount,getdate(),1))
			     END;
			        ELSE
			     BEGIN
			       SET @UpfrontInterest=(select sum(InterestPayment) from [dbo].[RepaymentSchedule] (@RepaymentPeriod,12,0,512, @APR, @AmountQualified ,getdate(),1))
			       END;

			   IF @AmountQualified > @MaximumLoanAmount
                 BEGIN
                  SET @NetDisbursed =@MaximumLoanAmount-(@VukaCharge+@UpfrontInterest+@TotalLoans) 
			     END
			        ELSE 
			       SET @NetDisbursed =@AmountQualified-(@VukaCharge+@UpfrontInterest+@TotalLoans)
				
				   IF @NetDisbursed <1500
				 --print @NetDisbursed
                 BEGIN
                     SET @Remarks = 'Qualified Amount Less than Take Home';
                     SET @AmountQualified = 0;
             END;

             --IF --@LoanPercentage < 30 and 
             --    @TotalLoans > 0
             --    BEGIN
             --        SET @Remarks = 'Not Qualified:Outstanding Loan Balance of ' + @TotalLoansDescription;
             --        SET @AmountQualified = 0;
             --END;
           
             IF @LoanAmountInDefault < 0
               
                 BEGIN
                     SET @Remarks = 'Rejected: You have Loan Arrears';
                     SET @AmountQualified = 0;
             END;
			 	   IF @EmployerCode not in (001,003,018,021,041,015,013)
                 BEGIN
                     SET @Remarks = 'Employer Restricted';
                     SET @AmountQualified = 0;
             END;
     END;
     IF @LoanCode = 39  ---Fosa Project 18
         BEGIN
            
			  SET @VukaCharge = ISNULL(@TotalLoans*0.04, 0);
            
             SET @TotalDeductions = ISNULL(
             (
                 SELECT SUM(Total)
                 FROM #Deductions
             ), 0);
             IF @TotalDeductions < (@AverageNetSalary)
                 BEGIN
                     SET @Remarks = 'Qualified';
                     SET @AmountQualified = 9 * 0.6 * (@AverageNetSalary - @TotalDeductions);
             END;
                 ELSE
                 BEGIN
                     SET @Remarks = 'Not Qualified Based on Income';
                     SET @AmountQualified = 0;
             END;
             IF @TotalLoans > @DepositBalance * 5
                 BEGIN
                     SET @Remarks = 'Not Qualified Based Deposits X 5';
                     SET @AmountQualified = 0;
             END;
             IF @FosaAccountBalance < 500
                 BEGIN
                     SET @Remarks = 'Fosa Balance Below 500';
                     SET @AmountQualified = 0;
             END;
			  IF @AmountQualified > @MaximumLoanAmount
			     BEGIN
			      SET @UpfrontInterest=(select sum(InterestPayment) from [dbo].[RepaymentSchedule] (@RepaymentPeriod,12,0,512, @APR, @MaximumLoanAmount,getdate(),1))
			     END;
			        ELSE
			     BEGIN
			       SET @UpfrontInterest=(select sum(InterestPayment) from [dbo].[RepaymentSchedule] (@RepaymentPeriod,12,0,512, @APR, @AmountQualified ,getdate(),1))
			       END;

			   IF @AmountQualified > @MaximumLoanAmount
                 BEGIN
                  SET @NetDisbursed =@MaximumLoanAmount-(@VukaCharge+@UpfrontInterest+@TotalLoans) 
			     END
			        ELSE 
			       SET @NetDisbursed =@AmountQualified-(@VukaCharge+@UpfrontInterest+@TotalLoans)
				
				   IF @NetDisbursed <1500
				 
                 BEGIN
                     SET @Remarks = 'Qualified Amount Less than Take Home';
                     SET @AmountQualified = 0;
             END;
    
             --IF --@LoanPercentage < 40 and 
             --    @TotalLoans > 0
             --    BEGIN
             --        SET @Remarks = 'Not Qualified:Outstanding Loan Balance of ' + @TotalLoansDescription;
             --        SET @AmountQualified = 0;
					
          
             --END;
           
             IF @LoanAmountInDefault < 0
               -- AND @LoanPercentage < 40
                 BEGIN
                     SET @Remarks = 'Rejected: You have Loan Arrears';
                     SET @AmountQualified = 0;
             END;
			 	   IF @EmployerCode not in (001,003,018,021,041,015,013)
                 BEGIN
                     SET @Remarks = 'Employer Restricted';
                     SET @AmountQualified = 0;
             END;
     END;
     IF @LoanCode = 15  ---Project Loan 24 Months
         BEGIN
           
			 SET @VukaCharge = ISNULL(@TotalLoans*0.04, 0);
             
             SET @TotalDeductions = ISNULL(
             (
                 SELECT SUM(Total)
                 FROM #Deductions
             ), 0);
			  print  'TotalDeductions'
			 print  @TotalDeductions
             IF isnull(@TotalDeductions,0) < (@AverageNetSalary)
                 BEGIN
                     SET @Remarks = 'Qualified';
                     SET @AmountQualified = 0.6 * 12 * (@AverageNetSalary - @TotalDeductions);
             END;
		
                 ELSE
                 BEGIN
                     SET @Remarks = 'Not Qualified Based on Income';
                     SET @AmountQualified = 0;
             END;
			print 'AVerageNetSalary'
			print @AverageNetSalary
			  print  'AmountQualified'
			 print  @AmountQualified 
             IF @TotalLoans > @DepositBalance * 6
                 BEGIN
                     SET @Remarks = 'Not Qualified Based Deposits X 5';
                     SET @AmountQualified = 0;
             END;
             IF @FosaAccountBalance < 500
                 BEGIN
                     SET @Remarks = 'Fosa Balance Below 500';
                     SET @AmountQualified = 0;
             END;
			  IF @AmountQualified >= @MaximumLoanAmount
			     BEGIN
			      SET @UpfrontInterest=(select sum(InterestPayment) from [dbo].[RepaymentSchedule] (@RepaymentPeriod,12,0,512, @APR, @MaximumLoanAmount,getdate(),1))
			     END;
				
			        ELSE
			     BEGIN
			       SET @UpfrontInterest=(select sum(InterestPayment) from [dbo].[RepaymentSchedule] (@RepaymentPeriod,12,0,512, @APR, @AmountQualified ,getdate(),1))
			       END;

				   print 'upfrontinterest'
				    print @UpfrontInterest

			IF @AmountQualified >= @MaximumLoanAmount
                 BEGIN
                  SET @NetDisbursed =@MaximumLoanAmount-(@VukaCharge+@UpfrontInterest+@TotalLoans) 
			     END
			        ELSE 
			       SET @NetDisbursed =@AmountQualified-(@VukaCharge+@UpfrontInterest+@TotalLoans)
				
			  IF @NetDisbursed <1500
				 
                 BEGIN
                     SET @Remarks = 'Qualified Amount Less than Take Home';
                     SET @AmountQualified = 0;
             END;
		    
             IF @LoanAmountInDefault < 0
              --  AND @LoanPercentage < 40
                 BEGIN
                     SET @Remarks = 'Rejected: You have Loan Arrears';
                     SET @AmountQualified = 0;
             END;
			 	   IF @EmployerCode not in (001,003,018,021,041,015,013)
                 BEGIN
                     SET @Remarks = 'Employer Restricted';
                     SET @AmountQualified = 0;
             END;
			--select * from employers where CompanyCode in (001,003,018,021,041,015,013)
     END;
	  
	 
     IF @LoanCode = 17  ---QuickFix
         BEGIN
             DECLARE @MinimumContribution MONEY;
             SET @TotalLoans = ISNULL(
             (
                 SELECT SUM(dbo.JournalEntries.Amount)
                 FROM dbo.CustomerAccounts
                      INNER JOIN dbo.JournalEntries ON dbo.CustomerAccounts.Id = dbo.JournalEntries.CustomerAccountId
                      INNER JOIN dbo.LoanProducts ON dbo.CustomerAccounts.CustomerAccountType_TargetProductId = dbo.LoanProducts.Id
                                                          AND dbo.JournalEntries.ChartOfAccountId = dbo.LoanProducts.ChartOfAccountId
                 WHERE CustomerAccounts.CustomerId = @CustomerID
                       AND dbo.LoanProducts.LoanRegistration_TermInMonths >= 3
                       AND dbo.LoanProducts.LoanRegistration_LoanProductSection = 0
                       AND dbo.LoanProducts.LoanRegistration_Microcredit = 0 and LoanProducts.code not in (34,28,30)
             ), 0) * -1;
	

             IF @DepositBalance < 5000
                 BEGIN
                     SET @Remarks = 'Rejected: Minimum total deposit less kshs. 5,000';
                     SET @AmountQualified = 0;
             END;
			  
             SET @MinimumContribution = ISNULL(
             (
                 SELECT dbo.StandingOrders.Charge_FixedAmount
                 FROM dbo.StandingOrders
                      INNER JOIN dbo.CustomerAccounts ON dbo.StandingOrders.BeneficiaryCustomerAccountId = dbo.CustomerAccounts.Id
                      INNER JOIN dbo.InvestmentProducts ON dbo.CustomerAccounts.CustomerAccountType_TargetProductId = dbo.InvestmentProducts.Id
                 WHERE CustomerAccounts.CustomerId = @CustomerID
                       AND InvestmentProducts.code = 2
             ), 0);
             IF @MinimumContribution < 1000
                 BEGIN
                     SET @Remarks = 'Rejected: Minimum deposit contribution of at least kshs. 1,000 per month';
                     SET @AmountQualified = 0;
             END;
             IF @TotalLoans > @DepositBalance * 3
                 BEGIN
                     SET @Remarks = 'Rejected: Not Qualified Based Deposits X 3';
                     SET @AmountQualified = 0;
             END;
             IF @FosaAccountBalance < 500
                 BEGIN
                     SET @Remarks = 'Rejected: Fosa Balance Below 500';
                     SET @AmountQualified = 0;
             END;
            
			 
             DECLARE @MembershipPeriodInSacco INT, @ScorebyMembership INT, @DefaultHistory BIT, @DefaultHistoryScore INT, @BOSADepositContribution INT;
             SET @MembershipPeriodInSacco = ISNULL(
             (
                 SELECT DATEDIFF(mm, RegistrationDate, GETDATE())
                 FROM Customers
                 WHERE Id = @CustomerID
             ), 0);
             SET @ScorebyMembership = ISNULL((CASE
                                                  WHEN @MembershipPeriodInSacco >= 6
                                                       AND @MembershipPeriodInSacco < 12
                                                  THEN 1
                                                  WHEN @MembershipPeriodInSacco >= 12
                                                       AND @MembershipPeriodInSacco < 24
                                                  THEN 2
                                                  WHEN @MembershipPeriodInSacco >= 24
                                                       AND @MembershipPeriodInSacco <= 36
                                                  THEN 3
                                                  WHEN @MembershipPeriodInSacco > 36
                                                  THEN 4
                                                  ELSE 0
                                              END), 0);
             SET @MinimumContribution = ISNULL(
             (
                 SELECT top 1  Balance
                 FROM DepositContributions
                 WHERE CustomerId = @CustomerID
                 Order By [Date] Desc), 0);

             SET @BOSADepositContribution = ISNULL(
             (
                 SELECT CASE
                            WHEN @MinimumContribution > 1500
                            THEN 4
                            WHEN @MinimumContribution > 1000
                                 AND @MinimumContribution <= 1500
                            THEN 3
                            WHEN @MinimumContribution > 500
                                 AND @MinimumContribution <= 1000
                            THEN 2
                            ELSE 1
                        END
             ), 0);
             SET @DefaultHistoryScore = IIF(@LoanAmountInDefault<0,0,2);
			 SET @Remarks = 'Qualified';
             SET @AmountQualified =(ISNULL(@DefaultHistoryScore, 0) + ISNULL(@BOSADepositContribution, 0) + ISNULL(@ScorebyMembership, 0)) * 5000 / 10;

			  IF @AmountQualified<@MinimumLoanAmount
                 BEGIN
                     SET @Remarks = 'Not Qualified: Qualified Amount Lower that Minimum Allowed';
                     SET @AmountQualified = 0;
             END;
			 	   --IF @EmployerCode not in (001,003,018,021,041)
        --         BEGIN
        --             SET @Remarks = 'Employer Restricted';
        --             SET @AmountQualified = 0;
        --     END;
			 if --@NetSalary <= 0
			 @CustomerAccountID not in (select CustomerAccountId from CreditBatchEntries where CreditBatchId = 'A316F359-5180-EC11-96D4-000C29869AA6')
			 BEGIN 
			 SET @Remarks ='Loan available to Fosa Salaried Members Only'
			 SET @AmountQualified = 0;
			 END;
			 
     END;

 
	 IF @TotalLoanBalance >@DepositMultiplier and @LoanCode not in(11,18,19)  and @EmployerCode not in('018','012')  
                 BEGIN
                     SET @Remarks = 'Total Loans Exceed Deposits Multiplier x4' ;
                     SET @AmountQualified = 0;
             END;

	  IF @LoanBalance > 0 and @LoanCode = 17
                 BEGIN
                     SET @Remarks = 'Not Qualified: Outstanding Loan Balance of '+cast(@LoanBalance as varchar(10)) ;
                     SET @AmountQualified = 0;
             END;

     IF(
     (
         SELECT DATEDIFF(mm, Individual_BirthDate, GETDATE())
         FROM Customers
         WHERE Id = @CustomerID
     ) + @RetirementAge) / 12 > ISNULL(@EmployeeAge, 0)
         BEGIN
             SET @AmountQualified = 0;
             SET @Remarks = 'Rejected: Number of months to retirement';
     END;
     IF @AmountQualified > @MaximumLoanAmount
        AND @Remarks = 'Qualified'
         BEGIN
             SET @AmountQualified = @MaximumLoanAmount;
             SET @Remarks = 'Qualified';
     END;
  
     --IF @LoanAmountInDefault < 0 and @LoanCode<>19
     --    BEGIN
     --        SET @Remarks = 'Rejected: You have Loan Arrears';
     --        SET @AmountQualified = 0;
     --END;

	 
     IF @AmountQualified < @LoanAmountInDefault and @LoanCode<>19
         BEGIN
             SET @Remarks = 'Rejected: Arrears more than Qualified Amount';
             SET @AmountQualified = 0;
     END;

     IF ISNULL(
     (
         SELECT DATEDIFF(mm, RegistrationDate, GETDATE())
         FROM Customers
         WHERE id = @CustomerID
     ), 0) < @MembershipPeriod
         BEGIN
             SET @Remarks = 'Rejected: Sacco membership for less 6 months';
             SET @AmountQualified = 0;
     END;
     IF @RejectIfOwing = 1
        AND @LoanBalance > 0 --Loanbalance>0 added by Joan
         BEGIN
             SET @Remarks = 'Rejected: You Have Outstanding Balance of ' + CAST(@LoanBalance AS VARCHAR(10));
             SET @AmountQualified = 0;
     END;

	 if exists(select top 1 * from CustomerAccounts where CustomerId=@CustomerID and CustomerAccountType_TargetProductId=@ProductID and status<>0 order by CreatedDate desc)
	 begin
		set @Remarks=isnull((select top 1 Remarks from CustomerAccounts where CustomerId=@CustomerID and CustomerAccountType_TargetProductId=@ProductID and status<>0 order by CreatedDate desc),'Rejected: Account Remarked')		
		set @AmountQualified=0
	 end


	 	
		if exists(select    * 
                   FROM    dbo.LoanProductExemptions INNER JOIN
                         dbo.LoanProductExemptionEntries ON dbo.LoanProductExemptions.Id = dbo.LoanProductExemptionEntries.LoanProductExemptionId
						 WHERE dbo.LoanProductExemptionEntries.CustomerId=@CustomerID and dbo.LoanProductExemptions.LoanProductId=@ProductID)
	 begin
		set @Remarks='Member is Blocked from Taking This Product'		
		set @AmountQualified=0

		 END
		 if exists(select top 1 * from LoanRequests where CustomerId=@CustomerID and status=0 and Origin=1)
	 begin
		set @Remarks='You Have a pending Loan request'		
		set @AmountQualified=0
	 end
     IF @MemberStatus <> 0
         BEGIN
             SET @Remarks = 'Rejected: Member is Not Active';
             SET @AmountQualified = 0;
     END;

	 --IF @EmployerRestriction=1
	 --BEGIN SET @Remarks='Employer Restricted';
	 --SET @AmountQualified = 0;
	 --END;


	 --IF @CustomerID not in ('8037CFDE-642E-EC11-952E-E09D31F190DB' )
	 --BEGIN SET @Remarks='Sorry Member Blocked';
	 --SET @AmountQualified = 0;
	 --END

	 --select id,code,Description from LoanProducts where code in(19,20,21)
	 IF @ProductID not in ('2A323623-DEBF-4E74-A664-307CE6539F80',
	 'D2B8A8DD-9CDA-48EF-BE60-D3289E2BBDF4','4895806F-45A4-45B4-9FFC-52FCDDBDE3B8','180BDAA1-9F40-4F61-AC41-A06522228293','48189237-8C6A-4A0A-8771-D259F3ABAD87',
	 'A1A78590-7E36-4DB6-A231-A913E04C5AE3','6A73EE49-D089-42E3-A4D6-4B20CB0072CD') 
	--'A1A78590-7E36-4DB6-A231-A913E04C5AE3',Quickfix
	--'48189237-8C6A-4A0A-8771-D259F3ABAD87',project 24
	--'180BDAA1-9F40-4F61-AC41-A06522228293', project 18
	 BEGIN 
	   SET @Remarks='Sorry Loan Blocked';
	   SET @AmountQualified = 0;
	 END
	 -- IF @ProductID='4895806F-45A4-45B4-9FFC-52FCDDBDE3B8' and @CustomerID not in(select customerid from Employees)
	
	 --BEGIN 
	 --  SET @Remarks='Sorry Loan Under Testing Face';
	 --  SET @AmountQualified = 0;
	 --END

     DROP TABLE #Credits;
     DROP TABLE #Deductions;
     SELECT ISNULL(@LoanCode, 1) AS LoanCode, 
	   -- 0 AS AmountQualified,
	     ISNULL(@AmountQualified,0) AS AmountQualified,
            ISNULL(@Remarks, 'Not Qualified') AS Remarks, 
            ISNULL(@MinimumGuarantors, 0) AS MinimumGuarantors;



			--select id,address_mobileline, individual_firstname from customers where Reference2 in ('44529','39912','30680','22692')

			--select * from LoanProducts where Description like '%quick%'

			--select id, Description, LoanRegistration_LoanProductSection from LoanProducts where id in ('2A323623-DEBF-4E74-A664-307CE6539F80','A1A78590-7E36-4DB6-A231-A913E04C5AE3' )
			--select * from LoanRequests where CustomerId='8037CFDE-642E-EC11-952E-E09D31F190DB' and Origin=1 and Status=0
			--select * from Enumerations where [key] = 'LoanRequestStatus'