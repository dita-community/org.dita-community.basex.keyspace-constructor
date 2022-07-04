module namespace ditacomm="http://dita-community.org/xquery/webapp";

import module namespace keyspace = "http://dita-community.org/basex/keyspace/xquery/module/construct-keyspace";

declare
  %rest:GET
  %rest:path('/ditacomm')
  %output:method('html')
function ditacomm:root()
as element(html) {
  let $mapPath := 'simple-scoped-map/simple_scoped_map.ditamap'
  let $db := 'test-data'
  let $rootMap as element() := db:open($db, $mapPath)/*
  
  return
  <html>
    <head>
      <title>DITA Community Namespace Constructor Application</title>
      <link href="/static/ditacomm/ditacomm.css" rel="stylesheet"/>
    </head>
    <body>
      <h1>DITA Community Namespace Constructor Application</h1>
      <p>Key Space for <span>simple-scoped-map/simple_scoped_map.ditamap</span>:</p>
      {
        ditacomm:reportKeySpaceForMap($rootMap)
      }
    </body>
  </html>
};

declare function ditacomm:reportKeySpaceForMap($rootMap as element()) as node()* {
  let $keySpace as map(*)* := keyspace:pass1($rootMap)
  let $rootScope as map(*) := $keySpace(db:node-id($rootMap))
  return
  <div class="keyspace-report">
    <h2>Key Space for map {db:path($rootMap)}</h2>
    <div>{
       ditacomm:reportKeyScope($rootScope, $keySpace)
    }{     
    }
    </div>
  </div>
};

declare function ditacomm:reportKeyScope($keyScope as map(*), $keySpace as map(*)) as node()* {
  let $childScopes as map(*)* := $keyScope('child-scopes') ! $keySpace(.)
  let $keydefs as map(*) := $keyScope('keydefs')
  
  return (
  <div class="key-scope-report" id="{ditacomm:getScopeId($keyScope)}">
    <h3>{$keyScope('scope-names') => string-join(', ')}</h3>
    <table class="key-scope">
      <thead>
        <tr>
          <th>Key Name</th>
          <th>Resource</th>
        </tr>
      </thead>    
      <tbody>{
        for $keyName in map:keys($keydefs)
        return 
        <tr>
          <td>{$keyName}</td>
          <td>{string($keydefs($keyName)/@href)}</td>
        </tr>        
      }</tbody>
    </table>
    <p>Child scopes:</p>
    {
      if (empty($childScopes))
      then <p>None</p>
      else
      <ul>{
        for $scope in $childScopes
        return
        <li><a href="#{keyspace:getScopeId($scope)}">{$scope('scope-names') => string-join(', ')}</a></li>
      }</ul>
    }
  </div>
   ,
  ($childScopes ! ditacomm:reportKeyScope(., $keySpace)) 
  )
};

