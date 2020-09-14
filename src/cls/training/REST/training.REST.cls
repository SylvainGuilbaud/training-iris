Class training.REST Extends %CSP.REST
{

Parameter HandleCorsRequest = 1;

XData UrlMap [ XMLNamespace = "http://www.intersystems.com/urlmap" ]
{
<Routes>
<Route Url="/class/:namespace/:classname" Method="GET" Call="GetClass"/>
<Route Url="/namespaces" Method="GET" Call="training.REST:GetNamespaces"/>
<Route Url="/request" Method="GET" Call="Request"/>
<Route Url="/request" Method="POST" Call="Request"/>
<Route Url="/echo" Method="POST" Call="Echo"/>
<Route Url="/colorclass" Method="POST" Call="ColorClass"/>
<Route Url="/languages" Method="GET" Call="GetColorLanguages"/>
</Routes>
}

/// This method returns the class text for the named cache class
ClassMethod GetClass(pNamespace As %String, pClassname As %String) As %Status
{
    #dim tSC As %Status = $$$OK
    #dim e As %Exception.AbstractException
    
    #dim tStream As %Stream.Character
    
    Try {
        Set tSC=##class(%Compiler.UDL.TextServices).GetTextAsStream(pNamespace,pClassname,.tStream)
        If $$$ISERR(tSC) Quit
        
        #; Looks good
        Do tStream.OutputToDevice()
        
    } Catch (e) {
        Set tSC=e.AsStatus()
    }
    
    Quit tSC
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
