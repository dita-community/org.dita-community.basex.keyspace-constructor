module namespace keyspace = "http://dita-community.org/basex/keyspace/xquery/module/construct-keyspace";

(:~ 
 : Construct a key space from a root map
 : @param rootMap The root map to construct the key space from
 : @return The key space document.
 :)
declare function keyspace:constructKeySpace($rootMap as element()) as element(keyspace:keyspace) {
  let $pass1keySpace as map(*) := keyspace:pass1($rootMap)
  return
  <keyspace:keyspace timestamp="{current-dateTime()}">{
    (: $pass1keySpace :)
  }</keyspace:keyspace>
};

(:~ 
 : Constructs map that reflects the key scope tree for the input map.
 : @param rootMap The root map to construct the scopes from
 : @return Map of key scopes where the top-level entry is for the root map's
 : annonymous key scope.
 :)
declare function keyspace:pass1($rootMap as element()) as map(*) {
  let $db as xs:string := db:name($rootMap)

  let $keydefs as element()* := $rootMap//*[@keys]
  
  let $entries as map(*)* := 
    for $keydef in $keydefs
    return
    let $keyScope as element() := ($keydef/ancestor::*[@keyscope][1], root($keydef)/*)[1]
    let $scopeKey as xs:integer := db:node-id($keyScope)
    return map{ $scopeKey : $keydef}
  
  let $scopeDefiners as element()+ := ($rootMap, $rootMap//*[@keyscope])
  
  (: Map indexed by scope key of key scope maps :)
  let $scopes as map(*) :=
  map:merge(
    for $entry as map(*) in $entries
      group by $scopeKey as xs:integer := map:keys($entry)
      let $scopeDef as element() := db:open-id($db, $scopeKey)
      return 
      map { $scopeKey :
        map { 
          'scope-key' : $scopeKey,
          'scope-def' : $scopeDef,
          'scope-names' : if (exists($scopeDef/@keyscope)) then ($scopeDef/@keyscope ! tokenize(., '\s+')) else '#root',
          'ancestor-scopes' : (($scopeDef/ancestor::*[@keyscope], root($scopeDef)/*)) ! db:node-id(.),
          'keydefs' : for $e in $entry return $e(map:keys($e))
        }
      }
  )
  return $scopes
};

