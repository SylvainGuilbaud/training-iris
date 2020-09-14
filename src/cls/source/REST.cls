Class source.REST Extends %CSP.REST
{

Parameter HandleCorsRequest = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/export/:namespace" Method="GET" Call="export"/>
<Route Url="/exportPackage/:namespace/:package" Method="GET" Call="ExportPackage"/>
</Routes>
}

ClassMethod export(namespace As %String) As %Status
{
    set %response.ContentType="application/xml"
    #dim tSC As %Status = $$$OK
    #dim e As %Exception.AbstractException
    #dim file as %Library.File
    
    try {
        set ns=$Namespace
        if ##class(%SYS.Namespace).Exists(namespace) {
            zn namespace
            set tSC=##class(%SYSTEM.OBJ).ExportAllClassesToStream(.stream,"-d")
            if $$$ISERR(tSC) quit

            do stream.OutputToDevice()   
            
            zn ns
        } else {
            set tSC=$system.Status.Error(5001,"<"_namespace_"> n'est pas un namespace valide")
        }
    } catch (e) {
        Set tSC=e.AsStatus()
    }
    
    return tSC
}

ClassMethod ExportPackage(pNamespace As %String, pPackageName As %String) As %Status
{
    #dim tSC As %Status = $$$OK
    #dim e As %Exception.AbstractException
    set %response.ContentType="application/xml"
    Try {
        set tSC=##class(%SYSTEM.OBJ).ExportPackageToStream(pPackageName,.tStream,"-d")
        If $$$ISERR(tSC) Quit
        
        Do tStream.OutputToDevice()

        
    } Catch (e) {
        Set tSC=e.AsStatus()
    }
    
    Quit tSC
}

}
