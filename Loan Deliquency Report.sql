
--select * from loanproducts where LoanRegistration_TermInMonths=1--code  in(25,32,39,42)
---[Sp_LoanDeliquencyReport] '07/30/2020'
--select * from vw_customeraccounts where reference1='2678-0002-04015'
--select duration_startdate, remarks from StandingOrders where duration_startdate<'11/28/2018'  and BeneficiaryCustomerAccountId in (select id from vw_customerloanaccounts)
ALTER procedure [dbo].[Sp_LoanDeliquencyReport] (@EndDate as Date)

as

SET NOCOUNT ON;

with CTE (customerloanid,FullName,LoanName,FullAccount,MemberNumber,ArmotizationType,period,Balance,InterestBalance,InterestpaidCurrent,StartDate,EndDate,
LoanAmount,Principal,PaymentPerPeriod,LoanCode,Section,annualLoanRate,EmployerName,InterestMode,DateLoanDisbursed,CaseNumber,LatestAmtPaid,
LatestPaidDate,Customerid,LoanProductID,GracePeriod)
as
(
select vw_CustomerLoanAccounts.id,
FullName,vw_CustomerLoanAccounts.Description,reference1,reference2,vw_CustomerLoanAccounts.LoanInterest_CalculationMode,vw_CustomerLoanAccounts.LoanRegistration_TermInMonths,
 sum(isnull(amount,0)) *-1 ,

  (select isnull(sum(Amount),0) from JournalEntries where CustomerAccountId=vw_CustomerLoanAccounts.Id and ChartOfAccountId =LoanProducts.InterestReceivableChartOfAccountId and JournalEntries.CreatedDate<=@EndDate)*-1 as InterestBalance,
(select isnull(sum(Amount),0) from JournalEntries where CustomerAccountId=vw_CustomerLoanAccounts.Id and ChartOfAccountId =LoanProducts.InterestReceivableChartOfAccountId and isnull(amount,0)*-1<0  
  and JournalEntries.CreatedDate<=@EndDate) as Interestpaid1,
(select top 1 Duration_StartDate from StandingOrders where BeneficiaryCustomerAccountId=vw_CustomerLoanAccounts.id) StartDate,
(select top 1 Duration_EndDate from StandingOrders where BeneficiaryCustomerAccountId=vw_CustomerLoanAccounts.id ) EndDate,
(select top 1 LoanAmount from StandingOrders where BeneficiaryCustomerAccountId=vw_CustomerLoanAccounts.id and [trigger]<>5 ) LoanAmount,
(select top 1 Principal from StandingOrders where BeneficiaryCustomerAccountId=vw_CustomerLoanAccounts.id and [trigger]<>5 ) Principal,
(select top 1 PaymentPerPeriod from StandingOrders where BeneficiaryCustomerAccountId=vw_CustomerLoanAccounts.id and [trigger]<>5 ) PaymentPerPeriod,
dbo.LoanProducts.code,dbo.LoanProducts.LoanRegistration_LoanProductSection,vw_CustomerLoanAccounts.LoanInterest_AnnualPercentageRate,
vw_CustomerLoanAccounts.EmployerName,vw_CustomerLoanAccounts.Mode,

(select top 1 Disburseddate from LoanCases where CustomerId=vw_CustomerLoanAccounts.CustomerId and LoanProductId=vw_CustomerLoanAccounts.LoanProductID order by DisbursedDate desc ) DateLoanDisbursed,
-- ( select case when (select top 1 Duration_StartDate from StandingOrders where BeneficiaryCustomerAccountId=vw_CustomerLoanAccounts.id)<'11/28/2018' then
--(select  top 1 casenumber  from vw_oldloancases where BeneficiaryCustomerAccountId=vw_CustomerLoanAccounts.id) else
(select top 1 CaseNumber from LoanCases where CustomerId=vw_CustomerLoanAccounts.CustomerId and LoanProductId=vw_CustomerLoanAccounts.LoanProductID order by DisbursedDate desc )  as CaseNumber,

 (select isnull(sum(Amount),0) from JournalEntries where CustomerAccountId=vw_CustomerLoanAccounts.Id and ChartOfAccountId =LoanProducts.ChartOfAccountId and isnull(amount,0)>0 and 
							 month(JournalEntries.createddate)=month(@EndDate) and year(JournalEntries.createddate)=year(@EndDate)
							  and journalid not in (select id from Journals_Loanrepaid)) as LatestAmtPaid,
(select max(createddate) from JournalEntries where CustomerAccountId=vw_CustomerLoanAccounts.Id and ChartOfAccountId =LoanProducts.ChartOfAccountId and isnull(amount,0)>0 and 
							 month(JournalEntries.createddate)=month(@EndDate) and year(JournalEntries.createddate)=year(@EndDate)
							  and journalid not in (select id from Journals_Loanrepaid)) as LatestPaidDate,vw_CustomerLoanAccounts.CustomerId,vw_CustomerLoanAccounts.LoanProductID,vw_CustomerLoanAccounts.LoanRegistration_GracePeriod
		FROM            dbo.vw_CustomerLoanAccounts INNER JOIN
								 dbo.LoanProducts ON dbo.vw_CustomerLoanAccounts.CustomerAccountType_TargetProductId = dbo.LoanProducts.Id INNER JOIN
								 dbo.JournalEntries ON dbo.vw_CustomerLoanAccounts.Id = dbo.JournalEntries.CustomerAccountId AND 
								 dbo.LoanProducts.ChartOfAccountId = dbo.JournalEntries.ChartOfAccountId inner join
								 dbo.journals on dbo.JournalEntries.JournalId=dbo.journals.id inner join
								 dbo.branches on dbo.journals.branchid=dbo.branches.id
		WHERE        cast(dbo.JournalEntries.CreatedDate as date)<=@EndDate 
	
		GROUP BY  vw_CustomerLoanAccounts.id,dbo.vw_CustomerLoanAccounts.Reference1,dbo.vw_CustomerLoanAccounts.Reference2, dbo.vw_CustomerLoanAccounts.Reference3,  dbo.vw_CustomerLoanAccounts.FullName,
		dbo.vw_CustomerLoanAccounts.FullAccount,dbo.LoanProducts.Description,dbo.vw_CustomerLoanAccounts.Individual_PayrollNumbers,dbo.vw_CustomerLoanAccounts.Individual_BirthDate,
		dbo.Branches.id,vw_CustomerLoanAccounts.Description,vw_CustomerLoanAccounts.id,dbo.LoanProducts.code,dbo.LoanProducts.LoanRegistration_LoanProductSection,
		vw_CustomerLoanAccounts.LoanRegistration_TermInMonths,vw_CustomerLoanAccounts.LoanInterest_CalculationMode,vw_CustomerLoanAccounts.LoanInterest_AnnualPercentageRate,
		vw_CustomerLoanAccounts.EmployerName,vw_CustomerLoanAccounts.CustomerId,vw_CustomerLoanAccounts.LoanProductID,LoanProducts.ChartOfAccountId,
		vw_CustomerLoanAccounts.Id,dbo.LoanProducts.InterestReceivableChartOfAccountId,vw_CustomerLoanAccounts.Mode,dbo.vw_CustomerLoanAccounts.LoanRegistration_GracePeriod
		 )
	
select *,iif(StartDate>=@EndDate,0,DATEDIFF(MM,StartDate,@EndDate)) as PeriodElapsed,DATEADD(dd, -GracePeriod,StartDate) as DateLoanDisbursed2,
iif(StartDate<'02/29/2020', (select top 1 isnull(interestpaid,0) from AccruedInterest where customerid=CTE.CustomerID 
and LoanProductID=CTE.LoanProductID),0) as InterestPaidOld
INTO #temp FROM CTE
SELECT	*,	 
case when InterestMode in(512,513) then
iif((isnull(Principal,0)*PeriodElapsed)>LoanAmount,Balance,isnull(Principal,0)*PeriodElapsed)
else
--iif((isnull(PaymentPerPeriod,0)*PeriodElapsed)>(PaymentPerPeriod*period),(PaymentPerPeriod*period),isnull(PaymentPerPeriod,0)*PeriodElapsed) end as BalanceExpected,
iif((isnull(PaymentPerPeriod,0)*PeriodElapsed)>(PaymentPerPeriod*period),(PaymentPerPeriod*period),isnull(PaymentPerPeriod,0)*PeriodElapsed) end as BalanceExpected,

case
WHEN InterestMode=513 then 0
WHEN InterestMode=512 then InterestBalance+InterestpaidCurrent+InterestPaidOld
else
((PaymentPerPeriod*period)-LoanAmount) end as  expectedInterest,
case
WHEN InterestMode in(512) then LoanAmount --(floor((nullif(LoanAmount,0)*rate/12*TERM2)/200)+LoanAmount) 
else
(PaymentPerPeriod*period) end as TotalLoanInterest,
isnull(LoanAmount,0)-isnull(Balance,0) as [Balance Paid]
into #temp2 from #temp

  select *,'Monthly' As Frequency,

 case when InterestMode=512 then 
 iif(iif(round(BalanceExpected-[Balance Paid],0)<0,0,round(BalanceExpected-[Balance Paid],0))>Balance,Balance,
 iif(round(BalanceExpected-[Balance Paid],0)<0,0,round(BalanceExpected-[Balance Paid],0)))
 else
 iif(iif(round(BalanceExpected-[Balance Paid]-InterestPaidOld-InterestpaidCurrent,0)<0,0,round(BalanceExpected-[Balance Paid]-isnull(InterestPaidOld,0)-InterestpaidCurrent,0))>Balance,Balance,
 iif(round(BalanceExpected-[Balance Paid]-InterestPaidOld-InterestpaidCurrent,0)<0,0,round(BalanceExpected-[Balance Paid]-isnull(InterestPaidOld,0)-InterestpaidCurrent,0)))
 end as DefaultedAmount, 
 case when #temp2.Balance<0 then 0  
 when #temp2.StartDate>@EndDate then 0
 when  #temp2.LoanCode=2 and #temp2.EndDate<@EndDate then 15
 --when #temp2.balance<=(select distinct (Balance) from  Deposits_Shares where customerid=#temp2.CustomerID) then 8.5

 when interestmode in(512,513) then
  iif(round((BalanceExpected-[Balance Paid])/nullif(Principal,0),0)<0,0,round((BalanceExpected-[Balance Paid])/nullif(Principal,0),0)) 
  else
   iif(round((BalanceExpected-[Balance Paid]-isnull(InterestPaidOld,0)-isnull(InterestpaidCurrent,0))/nullif(Paymentperperiod,0),0)<0,0,
   round((BalanceExpected-[Balance Paid]-isnull(InterestPaidOld,0)-InterestpaidCurrent)/nullif(Paymentperperiod,0),0)) end as Freq1,
   Case when interestmode=515 then PaymentPerPeriod else
Principal end as LoanInstalments,isnull(InterestPaidOld,0)+isnull(InterestpaidCurrent,0) as Interest_Paid,

iif(Isnull(expectedInterest,0)-(isnull(InterestPaidOld,0)+isnull(InterestpaidCurrent,0))<0,0,Isnull(expectedInterest,0)-(isnull(InterestPaidOld,0)+isnull(InterestpaidCurrent,0))) as InterestDue
 ,ROW_NUMBER() OVER(ORDER BY CustomerID ASC) AS  RNo into #temp5 from #temp2 where Balance<>0 
 
 select *,iif(floor(Freq1*365/12)<108,0,floor(Freq1*365/12)) as DaysInArrears,
  iif(#temp5.balance<=(select distinct (Balance) from  Deposits_Shares where customerid=#temp5.CustomerID) and Freq1>8.5,8.5,Freq1) Freq,
(select distinct (Balance) from  Deposits_Shares where customerid=#temp5.CustomerID) as Deposits into #temp3 from #temp5

select *,
case
WHEN Freq<=3.5 THEN 1
WHEN Freq>3.5 and Freq<=6 THEN 5
WHEN Freq>6 and Freq<=8.5 THEN 25
WHEN Freq>8.5 and Freq<=14.5 THEN 50
WHEN Freq>14.5 THEN 100
end as ClassOrder,
case 
WHEN Freq <=3.5 THEN 'Performing'
WHEN Freq>3.5 and Freq<=6  THEN 'Watch'
WHEN Freq>6 and Freq<=8.5 THEN 'Substandard'
WHEN Freq>8.5 and Freq<=14.5 THEN 'Doubtful'
WHEN Freq>14.5 THEN 'Loss'
end as Classification,
Freq as DefaultFrequency,
case 
WHEN Freq<=3.5 THEN 1
WHEN Freq>3.5 and Freq<=6 THEN 5
WHEN Freq>6 and Freq<=8.5 THEN 25
WHEN Freq>8.5 and Freq<=14.5 THEN 50
WHEN Freq>14.5 THEN 100 end as Provision,


case 
WHEN Freq<=3.5 THEN 0.01*[Balance]
WHEN Freq>3.5 and Freq<=6 THEN 0.05 *[Balance]
WHEN Freq>6 and Freq<=8.5 THEN 0.25 *[Balance]
WHEN Freq>8.5 and Freq<=14.5 THEN 0.5 *[Balance]
WHEN Freq>14.5 THEN 1 *[Balance] end as [Provision Amount]
into #temp4
 from #temp3 where [Balance]<>0 --and FullAccount in('020104')--,'2678-0006-00607','2678-0006-00161')
 -- order by  FullAccount,LoanName, DefaultFrequency
drop table #temp
drop table #temp2
drop table #temp5


;WITH cte AS
(
  SELECT
      ROW_NUMBER() OVER(PARTITION BY Customerid  ORDER BY Customerid ) AS rno,
      Deposits 
  FROM #temp4
)

UPDATE cte SET Deposits =0
WHERE rno>=2

select * from #temp4   order by  FullAccount,LoanName, DefaultFrequency


