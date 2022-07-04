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
  let $childScopes as xs:integer* := $keyScope('child-scopes')
  let $keydefs as element()* := $keyScope('keydefs')
  return (
  <div class="key-scope-report">
    <h3>{$keyScope('scope-names') => string-join(', ')}</h3>
    <table class="key-scope">
      <thead>
        <tr>
          <th>Key Name</th>
          <th>Resource</th>
        </tr>
      </thead>    
      <tbody>{
        for $keydef in $keydefs
        let $keyNames as xs:string* := tokenize($keydef/@keys, '\s+')
        for $keyName in $keyNames
        return 
        <tr>
          <td>{$keyName}</td>
          <td>{string($keydef/@href)}</td>
        </tr>        
      }</tbody>
    </table>
    <p>Child scopes:</p>
    {
      if (empty($childScopes))
      then <p>None</p>
      else
      <ul>{
        ($childScopes ! $keySpace(.)?scope-names => string-join(', ')) ! (<li>{.}</li>)
      }</ul>
    }
  </div>
  ,
  $childScopes ! $keySpace(.) ! ditacomm:reportKeyScope(., $keySpace)
  
  )
};

