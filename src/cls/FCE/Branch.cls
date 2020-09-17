/// Bank branch information
Class FCE.Branch Extends (%Persistent, %Populate, %XML.Adaptor, %JSON.Adaptor)
{

Property Phone As FCE.PhoneNumber [ Required ];

Index PhoneIndex On Phone [ Unique ];

Property Address As FCE.RealEstate;

Index AddressIndex On Address [ Unique ];

ForeignKey RealEstateFK(Address) References FCE.RealEstate() [ OnDelete = setnull ];

/// Time branch opens
Property Opens As %Time(MAXVAL = "$ztimeh(""12:00n"")", MINVAL = "$ztimeh(""6:00am"")");

/// Time branch closes
Property Closes As %Time(MAXVAL = "$ztimeh(""10:00pm"")", MINVAL = "$ztimeh(""1:00pm"")");

/// Currency used by this branch's nation
Property NationalCurrency As FCE.CurrencyName [ InitialExpression = "USD" ];

Property DurationOpen As %String(%JSONINCLUDE = "NONE") [ Calculated, SqlComputeCode = {if ({Closes} = "") || ({Opens} = "")
	{set {DurationOpen} = ""}
else
	{set {DurationOpen} = $ztime({Closes} - {Opens})}}, SqlComputed ];

Property CurrencyBalances As array Of %Numeric(MAXVAL = 1000000, MINVAL = 0, POPSPEC = ":5:##class(FCE.Currency).Currency()") [ SqlFieldName = Balance ];

Index CBIndex On CurrencyBalances(KEYS) [ Type = bitmap ];

/// Serial numbers of ATMs belonging to this branch
Property ATMs As list Of %String(POPSPEC = "##class(%PopulateUtils).String(5)_##class(%PopulateUtils).String(5)");

Index ATMIndex On ATMs(ELEMENTS);

Relationship Orders As FCE.CurrencyOrder(%JSONINCLUDE = "NONE") [ Cardinality = many, Inverse = Branch ];

Property Notes As %Stream.GlobalCharacter;

Index NotesiFind On (Notes) As %iFind.Index.Basic;

/// create a JSON object from Branch properties
Method CopyToObject(Output object As %DynamicObject) As %Status
{
	// for IRIS, use these 2 lines
	do ..%JSONExportToString(.jsonString)
	set object = ##class(%DynamicObject).%FromJSON(jsonString)
	
	// for Cache, use these 4 lines
	//set object.Phone = ..Phone
	//set object.Opens = $ztime(..Opens)
	//set object.Closes = $ztime(..Closes)
	//set object.NationalCurrency = ..NationalCurrency
	
	// this line is for IRIS and Cache
	set object.ID = ..%Id()
	return $$$OK
}

/// copy a JSON object into Branch properties
Method CopyFromObject(object As %DynamicObject) As %Status
{
	// for IRIS, use this line
	do ..%JSONImport(object)
	
	// for Cache, use these 4 lines
	//set ..Phone  = object.Phone
	//set ..Opens = $ztimeh(object.Opens)
	//set ..Closes = $ztimeh(object.Closes)
	//set ..NationalCurrency = object.NationalCurrency
	return $$$OK
}

Method %OnValidateObject() As %Status [ Private ]
{
    // convert currency abbreviations to $list format
    set abbreviations = ##class(FCE.Currency).#ABBREVIATIONS
	set validKeys = ##class(FCE.Currency).ConvertCurrenciestoListString(abbreviations)
 	
    // loop through keys until either reaching end or key is not in validKeys
    set key = ""
    do { do ..CurrencyBalances.GetNext(.key) }
    while (key '= "") && ($listfind(validKeys, key))

    if (key = "") { return $$$OK }
    else { return $$$ERROR($$$GeneralError, "Invalid key: " _ key) }
}

/// Update Branch by debiting/crediting currencies<br>
/// This method can be called with:<br>
/// * all 4 arguments (cash in - cash out). currencyOut and currencyIn <b>must</b> be different<br>
/// * the first 2 arguments (cash out only, paid for by credit card or bank account)<br>
/// * the last 2 arguments (cash in only, to be credited to bank balance)<br>
Method Update(currencyOut As FCE.CurrencyName = "", amountOut As %Numeric = 0, currencyIn As FCE.CurrencyName = "", amountIn As %Numeric = 0) As %Status
{
	try {	
		#dim cb as %Collection.ArrayOfDT
		set cb = ..CurrencyBalances
		set status = $$$OK
		set (outChanged, inChanged) = 0
		
		// debit stock amount by amount taken out
		if (currencyOut '= "") && (amountOut > 0) {
			set outChanged = 1
			set balanceBeforeDebit = cb.GetAt(currencyOut)
			set balanceAfterDebit = balanceBeforeDebit - amountOut
			do cb.SetAt(balanceAfterDebit, currencyOut)
			set status = ..%ValidateObject()
			if $$$ISERR(status) {
				set ex = ##class(%Exception.StatusException).CreateFromStatus(status)
				throw ex
			}
		}
		
		// credit stock amount by amount put in
		if (currencyIn '= "") && (amountIn > 0) {
			set inChanged = 1
			set balanceBeforeCredit = cb.GetAt(currencyIn)
			set balanceAfterCredit = balanceBeforeCredit + amountIn
			do cb.SetAt(balanceAfterCredit, currencyIn)
			set status = ..%ValidateObject()
			if $$$ISERR(status) {
				set ex = ##class(%Exception.StatusException).CreateFromStatus(status)
				throw ex
			}
		}
		// create unforseen <DIVIDE> exception 10% of the time
		// if '$r(10) {write 1/0}
	}
	catch ex {
		#dim ex, exCustom as %Exception.StatusException // enable Studio Assist for the exception objects
		// return custom error status and also write it to Application Error Log
		if (ex.Code = $$$ERRORCODE($$$DTMinVal)) {
			set custom = "Not enough stock in branch for " _ currencyOut
			set status = $$$ERROR($$$GeneralError, custom)
			set exCustom = ##class(%Exception.StatusException).CreateFromStatus(status)
			do exCustom.Log()
		}
		elseif (ex.Code = $$$ERRORCODE($$$DTMaxVal)) {
			set custom = "Branch has no more room for " _ currencyIn
			set status = $$$ERROR($$$GeneralError, custom)
			set exCustom = ##class(%Exception.StatusException).CreateFromStatus(status)
			do exCustom.Log()
		}
		// or change unforeseen exception back into a status
		else {
			set status = ex.AsStatus()
			do ex.Log()
		}
		// reset currencyIn and currencyOut
		do:outChanged cb.SetAt(balanceBeforeDebit, currencyOut)
		do:inChanged cb.SetAt(balanceBeforeCredit, currencyIn)
		
		// write to console log, optionally triggering notification
		set consoleMsg = "Branch Stock Problem - Check Error Log for details: "
		set portalLink = "http://localhost:52773/csp/sys/op/UtilSysAppErrorNamespaces.csp"
		do ##class(%SYS.System).WriteToConsoleLog(consoleMsg _ portalLink, , 2)
	}
	return status
}

Query CurrencySummary(minimum = 0) As %SQLQuery [ SqlProc ]
{
 select element_key as Currency, count(Branch) as Branch_Count,
        sum(Balance) as Total_Balance
 from FCE.Branch_Balance
 group by element_key
 having sum(Balance) >= :minimum
 order by element_key
}

/// Return unique list of city/state combinations with branches, along with a count of branches with currencies, and the list of cities with branches
Query CitiesStates() As %SQLQuery [ SqlProc ]
{
 select Address->State, count(distinct ID) as Branches, list(distinct Address->City) as Cities
 from FCE.Branch
 where Branch_Balance->element_key is not null
 group by Address->State
}

ClassMethod CitiesStatesList() As %Status
{
	#dim resultSet as %SQL.StatementResult
	set sql = "select * from FCE.Branch_CitiesStates()"
	set resultSet = ##class(%SQL.Statement).%ExecDirect(, sql)
	set SQLCODE = resultSet.%SQLCODE
	if (SQLCODE = 0) {
		while resultSet.%Next() {
			write !, resultSet.State, ?5, resultSet.Branches, ?10, resultSet.Cities
		}
	}
	else {
		write !, SQLCODE, "  ", rSets.%Message
	}
	return $$$OK
}

/// Show ATM serial numbers and addresses for branches in a given city that have at least one currency
ClassMethod BranchesInACity(city As %String, state As %String) As %Status
{
	// check for SELECT privileges on FCE.Branch and -> referenced tables
	if '$system.SQL.CheckPriv($username, "1,FCE.Branch", "s") ||
	   '$system.SQL.CheckPriv($username, "1,FCE.Branch_Balance", "s") ||
	   '$system.SQL.CheckPriv($username, "1,FCE.RealEstate", "s") {
		set message = "User " _ $username _ " is not privileged for the operation"
		set status = $$$ERROR($$$SQLCode, -99, message)
		return status
	}
	&sql(declare BC cursor for
	     select Phone, %odbcout(ATMs), Address->Street, list(Branch_Balance->element_key) as Currencies
	     from FCE.Branch
	     where (Address->City = :city AND Address->State = :state)
	     group by ATMs
	     having list(Branch_Balance->element_key) is not null)
	&sql(open BC)
	quit:(SQLCODE '= 0) // error -101 if cursor already open
	for {
	    &sql(fetch BC into :phone, :ATMs, :street, :currencies)
	    quit:(SQLCODE '= 0)
	    write !, phone, ?15, street
	    write !?5, "ATMs: ", ATMs
	    write !?5, "Currencies: ", currencies
	}
	if SQLCODE = 100 {
	    write !!, %ROWCOUNT, " row(s) returned."
	    set status = $$$OK
	}
	else { set status = $$$ERROR($$$GeneralError, "SQLCODE: " _ SQLCODE _ " " _ %msg) }
	&sql(close BC)
	quit:(SQLCODE '= 0) // error -102 if cursor not open
	return status
}

ClassMethod BranchReport() [ ReturnResultsets, SqlProc ]
{
	#dim %sqlcontext, sets as %ProcedureContext
	#dim resultSet as %SQL.StatementResult
	set sql = "call FCE.Branch_CurrencySummary()"	
	set rSets = ##class(%SQL.Statement).%ExecDirect(, sql)
	set SQLCODE = rSets.%SQLCODE
	if (SQLCODE = 0) {
		set resultSet = rSets.%NextResult()
		do %sqlcontext.AddResultSet(resultSet)
	}
	else {
		set %sqlcontext.%SQLCODE = SQLCODE
		set %sqlcontext.%Message = rSets.%Message
		quit
	}
	
	set sql = "call FCE.Branch_CitiesStates()"	
	set rSets = ##class(%SQL.Statement).%ExecDirect(, sql)
	set SQLCODE = rSets.%SQLCODE
	if (SQLCODE = 0) {
		set resultSet = rSets.%NextResult()
		do %sqlcontext.AddResultSet(resultSet)
	}
	else {
		set %sqlcontext.%SQLCODE = SQLCODE
		set %sqlcontext.%Message = rSets.%Message
		quit
	}
}

Storage Default
{
<Data name="BranchDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>Phone</Value>
</Value>
<Value name="3">
<Value>Address</Value>
</Value>
<Value name="4">
<Value>Opens</Value>
</Value>
<Value name="5">
<Value>Closes</Value>
</Value>
<Value name="6">
<Value>NationalCurrency</Value>
</Value>
<Value name="7">
<Value>ATMs</Value>
</Value>
<Value name="8">
<Value>Notes</Value>
</Value>
</Data>
<Data name="CurrencyBalances">
<Attribute>CurrencyBalances</Attribute>
<Structure>subnode</Structure>
<Subscript>"CurrencyBalances"</Subscript>
</Data>
<DataLocation>^FCE.BranchD</DataLocation>
<DefaultData>BranchDefaultData</DefaultData>
<IdLocation>^FCE.BranchD</IdLocation>
<IndexLocation>^FCE.BranchI</IndexLocation>
<StreamLocation>^FCE.BranchS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
