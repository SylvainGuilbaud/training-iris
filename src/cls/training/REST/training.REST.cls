Class training.REST Extends %CSP.REST
{

Parameter HandleCorsRequest = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/" Method="GET" Call="version"/>
<Route Url="/import" Method="POST" Call="import"/>
<Route Url="/import/data" Method="POST" Call="importGlobals"/>
<Route Url="/namespaces" Method="GET" Call="GetNamespaces"/>
<Route Url="/namespace/exist/:namespace" Method="GET" Call="namespaceExists"/>
<Route Url="/namespace" Method="POST" Call="createNamespace" />
<Route Url="/namespace" Method="DELETE" Call="deleteNamespace" />
<Route Url="/namespace/enable/:namespace" Method="GET" Call="enableNamespace" />
<Route Url="/namespace/enable/:namespace" Method="PUT" Call="enableNamespace" />
<Route Url="/namespace/disable/:namespace" Method="GET" Call="disableNamespace" />
<Route Url="/service" Method="GET" Call="service" />
<Route Url="/production" Method="POST" Call="createProduction" />
<Route Url="/_spec" Method="GET" Call="SwaggerSpec" />
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
    set payload={}.%FromJSON(%request.Content)
    set json.namespace=payload.namespace
    set json.directory=##class(%Library.File).NormalizeDirectory(payload.directory)_payload.namespace
    set json.directory=##class(%Library.File).NormalizeDirectory(json.directory)
    set json.interop=payload.interop

    try {
        set ns=$namespace
        zn "%sys"
        if ..namespaceExists(json.namespace) {
            set alreadyExist = ##class(%Exception.General).%New("ALREADY EXIST","5001",,
                             json.namespace_" is already existing")
            throw alreadyExist
        }
        zn ns
        set vars("NAMESPACE")=json.namespace
        set vars("DATABASEDIR")=json.directory
        set vars("INTEROP")=json.interop
        set sc=##class(training.installer.namespace).setup(.vars)
        set json.status=json.namespace_" successfully created"  
    } catch e {
        set sc=e.AsStatus()
        set msg="erreur durant la création de l'espace de noms "_json.namespace_"("_$system.Status.GetErrorText(sc)_")",severity=1
        do ##class(%SYS.System).WriteToConsoleLog(msg,0,severity)
    }
    do json.%ToJSON()
    return sc
}

ClassMethod deleteNamespace() As %Status
{
    set sc=$$$OK
    set ns=$namespace
    zn "%SYS"
    set %response.ContentType="application/json"
    set json={}
    set payload={}.%FromJSON(%request.Content)
    set json.namespace=payload.namespace
    set json.directory=##class(%Library.File).NormalizeDirectory(payload.directory)_payload.namespace
    set json.directory=##class(%Library.File).NormalizeDirectory(json.directory)
    
    try {
       
        set:..namespaceExists(json.namespace) sc=##Class(Config.Namespaces).Delete(json.namespace)
        set:sc json.status=json.namespace_" successfully deleted"
        set json.databases=[]
        for dbType="_SRC","_DATA" {
            set dbName=json.directory_json.namespace_dbType
            set sc=##class(SYS.Database).DismountDatabase(dbName)
            set sc=##class(SYS.Database).DeleteDatabase(dbName)
            set sc=##class(Config.Databases).Delete(json.namespace_dbType)
            do:sc json.databases.%Push(dbName_" successfully deleted")
        }
        
        set json.deleted=##class(%Library.File).RemoveDirectoryTree(json.directory)

        set sc=##class(Security.Applications).Delete("/csp/"_json.namespace)
        set:sc json.CSPApplication="/csp/"_json.namespace_" successfully deleted"
    } catch e {
        set sc=e.AsStatus()
        set msg="erreur durant la création de l'espace de noms "_json.namespace_"("_$system.Status.GetErrorText(sc)_")",severity=1
        do ##class(%SYS.System).WriteToConsoleLog(msg,0,severity)
    }
    do json.%ToJSON()
    zn ns
    return sc
}

ClassMethod import() As %Status
{
    set sc=$$$OK
    set %response.ContentType="application/json"
    set json={}
    set payload={}.%FromJSON(%request.Content)
    
    set json.sourceServer=payload.server
    set json.sourcePort=payload.port
    set json.sourceNamespace=payload.sourceNamespace
    set json.targetNamespace=payload.targetNamespace
    set ns=$namespace
    try {
        // check if namespace exist !!
        zn json.targetNamespace
        set httpRequest=##class(%Net.HttpRequest).%New()
        set httpRequest.Server=json.sourceServer
        set httpRequest.Port=json.sourcePort
        set httpRequest.Username="_system"
        set httpRequest.Password="SYS"
        set sc=httpRequest.Get("http://"_json.sourceServer_":"_json.sourcePort_"/source/export/"_json.sourceNamespace)
        // localhost:57772/source/export/user
        if $$$ISOK(sc) && $IsObject(httpRequest.HttpResponse.Data) {
            set sc=##class(%SYSTEM.OBJ).LoadStream(httpRequest.HttpResponse.Data,"-d",.errors,.list)
            do httpRequest.HttpResponse.Data.Rewind()
            set json.export=httpRequest.HttpResponse.Data.Read(256)
            set json.errors=[]
            set key=$ORDER(errors(""))
            while (key'="") {
                do json.errors.%Push(key) 
                set key = $ORDER(errors(key))
            }
            set json.list=[]
            set key=$ORDER(list(""))
            while (key'="") {
                do json.list.%Push(key) 
                set key = $ORDER(list(key))
            }
        }
        
    }
    catch e {
        set sc=e.AsStatus()
        set msg="erreur durant l'import vers l'espace de noms "_json.targetNamespace_"("_$system.Status.GetErrorText(sc)_")",severity=1
        do ##class(%SYS.System).WriteToConsoleLog(msg,0,severity)
    }
    set json.status=json.sourceNamespace_" successfully imported in namespace "_json.targetNamespace_" from "_json.sourceServer
    do json.%ToJSON()
    zn ns
    return sc
}

ClassMethod importGlobals() As %Status
{
    set sc=$$$OK
    set %response.ContentType="application/json"
    set json={}
    set payload={}.%FromJSON(%request.Content)
    
    set json.sourceServer=payload.server
    set json.sourcePort=payload.port
    set json.sourceNamespace=payload.sourceNamespace
    set json.targetNamespace=payload.targetNamespace
    set json.globals=payload.globals
    set ns=$namespace
    try {
        // check if namespace exist !!
        zn json.targetNamespace
        set httpRequest=##class(%Net.HttpRequest).%New()
        set httpRequest.Server=json.sourceServer
        set httpRequest.Port=json.sourcePort
        set httpRequest.Username="_system"
        set httpRequest.Password="SYS"
        do HttpRequest.EntityBody.Write(json.globals.%ToJSON())
        set sc=httpRequest.Get("http://"_json.sourceServer_":"_json.sourcePort_"/source/export/"_json.sourceNamespace)
        // localhost:57772/source/export/data/user
        if $$$ISOK(sc) && $IsObject(httpRequest.HttpResponse.Data) {
            set sc=##class(%SYSTEM.OBJ).LoadStream(httpRequest.HttpResponse.Data,"-d",.errors,.list)
            do httpRequest.HttpResponse.Data.Rewind()
            set json.export=httpRequest.HttpResponse.Data.Read(256)
            set json.errors=[]
            set key=$ORDER(errors(""))
            while (key'="") {
                do json.errors.%Push(key) 
                set key = $ORDER(errors(key))
            }
            set json.list=[]
            set key=$ORDER(list(""))
            while (key'="") {
                do json.list.%Push(key) 
                set key = $ORDER(list(key))
            }
        }
        
    }
    catch e {
        set sc=e.AsStatus()
         set msg="erreur durant l'import de données vers l'espace de noms "_json.targetNamespace_"("_$system.Status.GetErrorText(sc)_")",severity=1
       do ##class(%SYS.System).WriteToConsoleLog(msg,0,severity)
    }
    set json.status=json.sourceNamespace_" successfully imported in namespace "_json.targetNamespace_" from "_json.sourceServer
    do json.%ToJSON()
    zn ns
    return sc
}

ClassMethod enableNamespace(namespace As %String) As %Status
{
    set sc=$$$OK
    set %response.ContentType="application/json"
    set json={}
    set json.namespace=namespace
    
    try {
        #; if '##class(%Library.EnsembleMgr).IsEnsembleNamespace(namespace){
            set sc=##class(%Library.EnsembleMgr).EnableNamespace(namespace,0)
            set json.status=namespace_" successfully enabled to function with interoperability"
        #; }        
    } catch e {
        set sc=e.AsStatus()
        set msg="erreur durant la création de l'espace de noms "_namespace_"("_$system.Status.GetErrorText(sc)_")",severity=1
        do ##class(%SYS.System).WriteToConsoleLog(msg,0,severity)
    }
    
    do json.%ToJSON()
    return sc
}

ClassMethod disableNamespace(namespace As %String) As %Status
{
    set sc=$$$OK
    set %response.ContentType="application/json"
    set json={}
    set json.namespace=namespace
    
    try {
        if ##class(%Library.EnsembleMgr).IsEnsembleNamespace(namespace){
            set sc=##class(%Library.EnsembleMgr).DisableNamespace(namespace,0)
            set json.status=namespace_" successfully disabled to function with interoperability"
        }        
    } catch e {
        set sc=e.AsStatus()
        set msg="erreur durant la création de l'espace de noms "_namespace_"("_$system.Status.GetErrorText(sc)_")",severity=1
        do ##class(%SYS.System).WriteToConsoleLog(msg,0,severity)
    }
    
    do json.%ToJSON()
    return sc
}

ClassMethod createProduction() As %Status
{
    set sc=$$$OK
    set %response.ContentType="application/json"
    set json={}
    set payload={}.%FromJSON(%request.Content)
    set json.namespace=payload.namespace
    set json.production=payload.production
    

    try {
        set ns=$Namespace
        zn json.namespace
        if ##Class(Ens.Config.Production).%ExistsId(json.production) {
            set alreadyExist = ##class(%Exception.General).%New("ALREADY EXIST","5001",,
                             json.production_" is already existing in "_json.namespace)
            throw alreadyExist
        }
        set a=##class(%Dictionary.ClassDefinition).%New()
        set a.Name=json.production
        set a.Super="Ens.Production"
        set sc=a.%Save()

        set prod=##class(Ens.Config.Production).%New()
        set prod.Name=json.production
        
        set service=##class(Ens.Config.Item).%New()
        set service.Name="from a file"
        set service.ClassName="EnsLib.File.PassthroughService"
        set target=##class(Ens.Config.Setting).%New()
        set target.Name="TargetConfigNames"
        set target.Value="router"
        do service.Settings.Insert(target)
        set FilePath=##class(Ens.Config.Setting).%New()
        set FilePath.Name="FilePath"
        set FilePath.Value="/file/in"
        do service.Settings.Insert(FilePath)
        set FileSpec=##class(Ens.Config.Setting).%New()
        set FileSpec.Name="FileSpec"
        set FileSpec.Value="*.txt"
        do service.Settings.Insert(FileSpec)

        do prod.Items.Insert(service)

        set process=##class(Ens.Config.Item).%New()
        set process.Name="router"
        set process.ClassName="EnsLib.MsgRouter.RoutingEngine"
        do prod.Items.Insert(process)

        set operation=##class(Ens.Config.Item).%New()
        set operation.Name="to a file"
        set operation.ClassName="EnsLib.File.PassthroughOperation"
        do prod.Items.Insert(operation)
        
        set sc=prod.%Save()

       

        set json.status=json.production_" successfully created in "_json.namespace_" ("_sc_")"
        zn ns
    } catch e {
        set sc=e.AsStatus()
        set msg="erreur durant la création de la production "_json.production_"("_$system.Status.GetErrorText(sc)_")",severity=1
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

ClassMethod namespaceExists(namespace As %String) As %Boolean
{
    set ns=$Namespace
    zn "%sys"
    set exist=##Class(Config.Namespaces).Exists(namespace)
    zn ns
    return exist
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

ClassMethod SwaggerSpec() As %Status
{
  Set tSC = ##class(%REST.API).GetWebRESTApplication($NAMESPACE, %request.Application, .swagger)
  Do swagger.info.%Remove("x-ISC_Namespace")
  Set swagger.basePath = "/crud"
  Set swagger.info.title = "InterSystems IRIS REST CRUD demo"
  Set swagger.info.version = "0.1"
  Set swagger.host = "localhost:52773"
  Return ..%ProcessResult($$$OK, swagger)
}

}
