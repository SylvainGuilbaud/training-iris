Include FCE

/// Utilities for development
Class FCE.Tests.Utilities
{

/// Delete all data and run tests
ClassMethod DestroyAll()
{
	// if FCE.Currency exists but there's no data run FetchRates()
	if $$$ClassExists(FCE.Currency) && $$$MethodExists(FCE.Currency,FetchRates) {
		set sql = "select count(*) as currencies from FCE.Currency"
		set rs = ##class(%SQL.Statement).%ExecDirect( , sql)
		set SQLCODE = rs.%SQLCODE
		if (SQLCODE = 0) && (rs.%Next()) && (rs.currencies '= 10) {			
			do ##class(FCE.Currency).FetchRates()
		}
		elseif (SQLCODE < 0) {
			write !, "SQL error: ", SQLCODE, " ", %msg
		}
	}

	if $$$ClassExists(FCE.CurrencyOrder) {
		do ##class(FCE.CurrencyOrder).%KillExtent()
	}	
	do ##class(FCE.Payment).%KillExtent()
	do ##class(FCE.AccountHolder).%KillExtent()
	do ##class(FCE.Branch).%DeleteExtent()  // also deletes FCE.Branch Notes stream data
	do ##class(FCE.RealEstate).%KillExtent()
	read !, "Data deleted. Press <Enter> to run tests.", x

	do ##class(FCE.Tests.BasicTests).Run()
	read !, "Press <Enter> to continue.", x
	if $$$ClassExists(FCE.Tests.CurrencyOrderTests) {	
		do ##class(FCE.Tests.CurrencyOrderTests).Run()
		read !, "Press <Enter> to continue.", x
	}
	do ##class(FCE.Tests.PaymentTests).Run()
}

/// Create data and run tests
ClassMethod CreateAll(base As %Integer = 5)
{
	// if FCE.Currency exists but there's no data run FetchRates()
	if $$$ClassExists(FCE.Currency) && $$$MethodExists(FCE.Currency,FetchRates) {
		set sql = "select count(*) as currencies from FCE.Currency"
		set rs = ##class(%SQL.Statement).%ExecDirect( , sql)
		set SQLCODE = rs.%SQLCODE
		if (SQLCODE = 0) && (rs.%Next()) && (rs.currencies '= 10) {			
			do ##class(FCE.Currency).FetchRates()
		}
		elseif (SQLCODE < 0) {
			write !, "SQL error: ", SQLCODE, " ", rs.%Message
		}
	}
	
	do ##class(FCE.RealEstate).Populate(base * 10)
	do ##class(FCE.Branch).Populate(base * 3)
	do ##class(FCE.AccountHolder).Populate(base * 3)
	if $$$ClassExists(FCE.CurrencyOrder) {
		do ##class(FCE.CurrencyOrder).Populate(base * 6)
	}
	read !, "Data added. Press <Enter> to run tests.", x

	do ##class(FCE.Tests.BasicTests).Run()
	read !, "Press <Enter> to continue.", x
	if $$$ClassExists(FCE.Tests.CurrencyOrderTests) {
		do ##class(FCE.Tests.CurrencyOrderTests).Run()
		read !, "Press <Enter> to continue.", x
	}
	do ##class(FCE.Tests.PaymentTests).Run()
}

/// helper method for tests
ClassMethod CreateOrder() As FCE.CurrencyOrder
{
	#dim branch as FCE.Branch
	set branch = ##class(FCE.Branch).%New()
	set branch.Phone = ##class(%PopulateUtils).USPhone()
	do branch.CurrencyBalances.SetAt(250, "EUR")
	do branch.CurrencyBalances.SetAt(50, "USD")
	#dim order as FCE.CurrencyOrder
	set order = ##class(FCE.CurrencyOrder).%New(branch,
												"Smith,John",
												"Smith@abcd.com",
												"EUR", "USD", 100)
	set order.ATM = ##class(%PopulateUtils).String(5)_##class(%PopulateUtils).String(5)
	// override %New() AmountOut calculation for testing purposes
	set order.AmountOut = 95
	return order
}

/// helper method for tests
ClassMethod CreateAccount() As FCE.AccountHolder
{
	#dim account as FCE.AccountHolder	
	set account = ##class(FCE.AccountHolder).%New()
	set account.Name = "Smith,John"
	set account.Email = "Smith@zzz.com"
	set account.Home.Street = "10 High St."
	set account.Home.City = "Cambridge"
	set account.Home.State = "MA"
	set account.Home.Zip = "02142"
	set work = account.Home.%ConstructClone()
	set account.Work = work
	set account.DOB = $zdh("01/01/1980")
	set account.Balance = 1000
	set account.Currency = "USD"
	return account
}

}
