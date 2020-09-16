Class training.web.hello Extends %CSP.Page
{

ClassMethod OnPage() As %Status [ ServerOnly = 1 ]
{
    write "Hello "
	Quit $$$OK
}

}
