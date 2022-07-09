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
  let $keySpaceXml as element() := keyspace:constructKeySpace($rootMap)
  let $rootScope as element(keyspace:keyscope) := $keySpaceXml/keyspace:keyscope
  return
  <div class="keyspace-report">
    <h2>Key Space for map {db:path($rootMap)}</h2>
    <div>{
       ditacomm:reportKeyScope($rootScope)
    }{     
    }
    </div>
  </div>
};

(:~ 
 : Reports the XML representation of a key space
 :)
declare function ditacomm:reportKeyScope($keyScope as element(keyspace:keyscope)) as node()* {
  let $childScopes as element(keyspace:keyscope)* := $keyScope/keyspace:keyscope
  let $keys as element(keyspace:key)* := $keyScope/keyspace:keys/keyspace:key
  (: let $debug := (prof:dump('keyScope:'), prof:dump($keyScope)) :)
  return (
  <div class="key-scope-report" id="{$keyScope/@id}">
    <h3>{$keyScope/keyspace:scope-names/keyspace:scope-name ! string(.) => string-join(', ')}</h3>
    <table class="key-scope">
      <thead>
        <tr>
          <th>Key Name</th>
          <th>Resource</th>
          <th>Conditions</th>
        </tr>
      </thead>    
      <tbody>{
        for $key in $keys
        return
        for $keyName as xs:string in ($key/@keyname ! tokenize(., '\s+'))
        let $keydefs as element()* := $key/keyspace:keydef
        return
        ( 
        <tr>
          <td>
            {if (count($keydefs) gt 1)
             then attribute rowspan {count($keydefs)}
             else ()
            }
            {$keyName}
          </td>         
          <td>{$keydefs[1]/@href ! string(.)}</td>
          <td>{
            ditacomm:formatConditionalAttributes($keydefs[1])
          }</td>
        </tr>
        ,
        for $keydef in tail($keydefs)
        return
        <tr>
          <td>{$keydef/@href ! string(.)}</td>
          <td>{ditacomm:formatConditionalAttributes($keydef)}</td>
        </tr>
      )
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
        <li><a href="#{$scope/@id ! string(.)}">{($scope/keyspace:scope-names/*) => string-join(', ')}</a></li>
      }</ul>
    }
  </div>
   ,
  ($childScopes ! ditacomm:reportKeyScope(.)) 
  )
};

(:~ 
 : Format conditional attributes 
 :)
declare function ditacomm:formatConditionalAttributes($elem as element()) as node()* {
  let $atts as attribute()* := $elem/(@props | @deliveryTarget | @product | @audience | @platform | @otherprops)
  return
  if (exists($atts))
  then
    <div class="conditional-attributes">{
      for $att in $atts
      return
      <div class="conditional-attribute">
        <span class="condition-name">{name($att)}</span>
        <span class="condition-values">{string($att)}</span>
      </div>
    }</div>
  else ()
};

(:~ 
 : Report the XQuery map representation of a key space
 :)
declare function ditacomm:reportKeyScopeMap($keyScope as map(*), $keySpace as map(*)) as node()* {
  let $childScopes as map(*)* := $keyScope('child-scopes') ! $keySpace('keyscopes')(.)
  let $keydefs as map(*) := $keyScope('keydefs')
  
  return (
  <div class="key-scope-report" id="{keyspace:getScopeId($keyScope)}">
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
  ($childScopes ! ditacomm:reportKeyScopeMap(., $keySpace)) 
  )
};

