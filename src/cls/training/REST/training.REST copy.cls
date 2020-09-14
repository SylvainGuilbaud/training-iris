Class training.REST Extends %CSP.REST
{

Parameter HandleCorsRequest = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/" Method="GET" Call="version"/>
<Route Url="/namespaces" Method="GET" Call="GetNamespaces"/>
<Route Url="/namespace" Method="POST" Call="createNamespace" />
<Route Url="/namespace/enable/:namespace" Method="GET" Call="enableNamespace" />
<Route Url="/service" Method="GET" Call="service" />
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
    do json.%ToJSON()
    return sc
}

ClassMethod createNamespace() As %Status
{
    set sc=$$$OK
    set %response.ContentType="application/json"
    set json={}
    set payload=%request.Content
    set json.ContentSize=payload.Size
    #; set json.namespace=namespace
    
    #; set json.requestContent=payload.Read()
    //set json.databasesDirectory=%request.{}.%FromJSON
    #; try {
    #;     set vars("NAMESPACE")=namespace
    #;     set vars("DATABASEDIR")=""
    #;     set sc=##class(training.installer.namespace).setup(.vars)
        
    #; } catch e {
    #;     set sc=e.AsStatus()
    #;     set msg="erreur durant la création de l'espace de noms "_namespace_"("_$system.Status.GetErrorText(sc)_")",severity=1
    #;     do ##class(%SYS.System).WriteToConsoleLog(msg,0,severity)
    #; }
    
    do json.%ToJSON()
    return sc
}

ClassMethod enableNamespace(namespace As %String) As %Status
{
    set sc=$$$OK
    set %response.ContentType="application/json"
    set json={}
    set json.namespace=namespace
    
    try {
        if '##class(%Library.EnsembleMgr).IsEnsembleNamespace(namespace){
            set sc=##class(%Library.EnsembleMgr).EnableNamespace(namespace,0)
            set json.status="success"
        }        
    } catch e {
        set sc=e.AsStatus()
        set msg="erreur durant la création de l'espace de noms "_namespace_"("_$system.Status.GetErrorText(sc)_")",severity=1
        do ##class(%SYS.System).WriteToConsoleLog(msg,0,severity)
    }
    
    do json.%ToJSON()
    return sc
}

ClassMethod service() As %Status
{
 try {
	set sc=$$$OK
	set %response.ContentType="application/json"

	set payload=%request.Content

	set tSC=##class(Ens.Director).CreateBusinessService("training.service.REST",.tService)

	set request=##class(Ens.StringRequest).%New()
	set request.StringValue=payload.Read()

	set sc=tService.ProcessInput(request,.response)
	set retour={}
	set retour.data=response.StringValue
	write retour.%ToJSON()
	} catch e {
		throw e
	}
	return sc
}

/// This method returns a list of namespaces for this server
ClassMethod GetNamespaces() As %Status
{
    #dim tSC As %Status = $$$OK
    #dim tList,tNS,tFilteredList,tValue As %String
    
    #; Get the list of namespaces
    Do List^%SYS.NAMESPACE(.tList)
    Set tNS="" For  {
    
        Set tNS=$Order(tList(tNS),1,tValue) If tNS="" Quit
    
        #; Only want namespaces which are enabled and are not remote
        If $List(tValue,1)=1&&$List(tValue,2)=0 {
            Set tFilteredList(tNS)=""
        }
    }
    
    #; If we have been asked for json
    If $Get(%request.CgiEnvs("HTTP_ACCEPT"))="application/json" {
        
        #; Set the response header to JSON
        Set %response.ContentType="application/json"
        
        #; Create a JSON proxy
        Set tProxy = ##class(%ZEN.proxyObject).%New()
        
        #; And a list to hold the namespaces
        Set tList=##class(%Library.ListOfDataTypes).%New()
        
        #; Add the namespaces to the list
        Set tNS="" For  {
            Set tNS=$Order(tFilteredList(tNS)) If tNS="" Quit
            Do tList.Insert(tNS)
        }
        
        #; Set the namespace property
        Set tProxy.namespaces=tList
        
        #; Output the JSON
        Do tProxy.%ToJSON()
        
    } else {
        
        Set tNS="" For  {
            Set tNS=$Order(tFilteredList(tNS)) If tNS="" Quit
            Write tNS,!
        }
    }
    Quit tSC
}

/// Return a dump of the request object
ClassMethod Request() As %Status
{
	Set %response.ContentType="text/plain"
	Do $System.OBJ.Dump(%request)
    Quit $$$OK
}

/// Return the posted data
ClassMethod Echo() As %Status
{
    Set %response.ContentType=%request.ContentType
    
    Quit %request.Content.OutputToDevice()
}

}
