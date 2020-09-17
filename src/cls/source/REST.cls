Class source.REST Extends %CSP.REST
{

Parameter HandleCorsRequest = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/" Method="GET" Call="version"/>
<Route Url="/export/:namespace" Method="GET" Call="export"/>
<Route Url="/exportPackage/:namespace/:package" Method="GET" Call="ExportPackage"/>
<Route Url="/export/data/:namespace" Method="POST" Call="exportGlobals"/>
</Routes>
}

ClassMethod version() As %Status
{
    set sc=$$$OK
    set %response.ContentType="application/json"
    set json={}
    set json.version=$zv
    set json.date=$zdt($h,3)
    set json.system=$System
    set json.username=$Username
    set json.roles=$Roles
    set json.namespace=$Namespace
    write json.%ToJSON()
    return sc
}

ClassMethod export(namespace As %String) As %Status
{
    set %response.ContentType="application/xml"
    #dim tSC As %Status = $$$OK
    #dim e As %Exception.AbstractException
    #dim file as %Library.File
    set ns=$Namespace
    try {
        if ##class(%SYS.Namespace).Exists(namespace) {
            zn namespace
            set tSC=##class(%SYSTEM.OBJ).ExportAllClassesToStream(.stream,"-d")
            if $$$ISERR(tSC) quit

            do stream.OutputToDevice()   
            
            
        } else {
            set tSC=$system.Status.Error(5001,"<"_namespace_"> n'est pas un namespace valide")
        }
    } catch (e) {
        Set tSC=e.AsStatus()
    }
    zn ns
    return tSC
}

ClassMethod exportGlobals(namespace As %String) As %Status
{
    set %response.ContentType="application/xml"
    #dim tSC As %Status = $$$OK
    #dim e As %Exception.AbstractException
    #dim file as %Library.File
    set ns=$Namespace
    try {
        set payload=[].%FromJSON(%request.Content)
        if ##class(%SYS.Namespace).Exists(namespace) {
            zn namespace
            set i = payload.%GetIterator()
	        while i.%GetNext(.key, .value) {
		        set list(value_".gbl")=""
            }

            set tSC=##class(%SYSTEM.OBJ).ExportToStream(.list,.stream,"-d")
            if $$$ISERR(tSC) quit

            do stream.OutputToDevice()   
            
            
        } else {
            set tSC=$system.Status.Error(5001,"<"_namespace_"> n'est pas un namespace valide")
        }
    } catch (e) {
        Set tSC=e.AsStatus()
    }
    zn ns
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
