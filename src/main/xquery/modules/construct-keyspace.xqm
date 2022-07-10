module namespace keyspace = "http://dita-community.org/basex/keyspace/xquery/module/construct-keyspace";

import module namespace mapproc = "http://dita-community.org/basex/keyspace/xquery/module/map-processing";

(:~ 
 : Construct the XML representation of a key space  from a root map
 : @param rootMap The root map to construct the key space from
 : @return The key space document.
 :)
declare function keyspace:constructKeySpace($rootMap as element()) as element(keyspace:keyspace) {
  let $pass1keySpace as map(*) := keyspace:pass1($rootMap)
  let $pass2keySpace as map(*) := keyspace:pass2($pass1keySpace)
  let $pass3keySpace as map(*) := keyspace:pass3($pass2keySpace)
  let $keySpaceMap as map(*) := $pass3keySpace 
  let $keySpace as element(keyspace:keyspace) :=
  <keyspace:keyspace
    timestamp="{$keySpaceMap('timestamp')}"
    source-ditamap="{$keySpaceMap('source-ditamap')}"
  >{
    keyspace:serializeKeyscopeToXml(keyspace:getRootScope($keySpaceMap), $keySpaceMap)
  }</keyspace:keyspace>
  return $keySpace
};

(:~ 
 : Construct the XML representation of a key space
 : @param keyScope The key scope to serialize
 : @param keySpace The key space that contains the scope.
 : @return The XML for the key scope and any descendant scopes
 :)
declare function keyspace:serializeKeyscopeToXml($keyScope as map(*), $keySpace as map(*)) as node()* {
  (: let $debug := (prof:dump('serializeKeyscopeToXml(): keyScope:'), prof:dump($keyScope)) :)
  let $scopeNames as xs:string+ := $keyScope('scope-names')
  let $keydefs as map(*) := $keyScope('keydefs')
  return
  <keyspace:keyscope id="{keyspace:getScopeId($keyScope)}">
    <keyspace:scope-names>{
      for $name in $scopeNames
      return <keyspace:scope-name>{$name}</keyspace:scope-name>      
    }</keyspace:scope-names> 
    <keyspace:keys>{
      for $key in map:keys($keydefs)
      return 
      <keyspace:key keyname="{$key}">{
        for $keydef in $keydefs($key)
        return
        <keyspace:keydef nodeid="{keyspace:getNodeId($keydef)}">{
          ($keydef/@* except($keydef/@nodeid), $keydef/*[contains-token(@class, 'topic/navtitle')])
        }</keyspace:keydef>
      }</keyspace:key>
    }</keyspace:keys>
    {
      let $childScopes as map(*)* := ($keyScope('child-scopes') ! $keySpace('keyscopes')(.))
      (: Put the scope-defining elements in document order :)
      let $scopeDefs as element()* := $childScopes?scope-def => util:ddo()
      return
      for $scopeDef in $scopeDefs
      let $nodeId as xs:integer := keyspace:getNodeId($scopeDef)
      let $scope := $keySpace('keyscopes')($nodeId)
      return keyspace:serializeKeyscopeToXml($scope, $keySpace)
    }
  </keyspace:keyscope>
};

(:~ 
 : Get the XML ID for a key scope
 :)
declare function keyspace:getScopeId($keyScope as map(*)) as xs:string {
  'scope_' || $keyScope('scope-key')
};

(:~ 
 : Gets the root key scope for the specified key space
 : @param keySpace The key space to get the root scope for
 : @return The root key space. A key space always has a root scope.
 :)
declare function keyspace:getRootScope($keySpace as map(*)) as map(*) {
   $keySpace('keyscopes')($keySpace('root-scope'))
};

(:~ 
 : Constructs map that reflects the key scope tree for the input map.
 : @param rootMap The root map to construct the scopes from
 : @return Map of key scopes where the top-level entry is for the root map's
 : annonymous key scope.
 :)
declare function keyspace:pass1($rootMap as element()) as map(*)* {
  let $db as xs:string := db:name($rootMap)
  let $resolvedMap as element() := mapproc:resolveMap($rootMap)/*
  let $keydefs as element()* := $resolvedMap//*[@keys]
  let $rootScopeKey as xs:integer :=  keyspace:getNodeId($resolvedMap)
  
  let $entries as map(*)* := 
    for $keydef in $keydefs
    return
    let $keyScope as element() := ($keydef/ancestor::*[@keyscope][1], root($keydef)/*)[1]
    let $debug := (prof:dump('keyScope:'), prof:dump($keyScope))
    let $scopeKey as xs:integer := keyspace:getNodeId($keyScope)
    let $debug := prof:dump('$scopeKey="' || $scopeKey || '"')
    return map{ $scopeKey : $keydef}
  
  let $scopeDefiners as element()+ := ($resolvedMap, $resolvedMap//*[@keyscope])
  
  (: Map indexed by scope key of key scope maps :)
  let $scopes as map(*) :=
  map:merge(    
    for $entry as map(*) in $entries
      group by $scopeKey as xs:integer := map:keys($entry)
      let $debug := prof:dump('$scopeKey="' || $scopeKey || '"')
      let $scopeDef as element() := db:open-id($db, $scopeKey)
      return 
      map { $scopeKey :
        map { 
          'scope-key' : $scopeKey,
          'scope-def' : $scopeDef,
          'scope-names' : if (exists($scopeDef/@keyscope)) then ($scopeDef/@keyscope ! tokenize(., '\s+')) else '#root',
          'ancestor-scopes' : 
          if ($scopeKey eq $rootScopeKey)
          then ()
          else
            (($scopeDef/ancestor::*[@keyscope], root($scopeDef)/*)) ! keyspace:getNodeId(.),
          (: Because of the grouping, $entry is actualy a sequence of maps of scope 
             key to topicref, representing all the key definitions directly defined 
             by the scope:)
          'keydefs' :
          let $keydefs as element()* := $entry ! map:get(., $scopeKey)
          let $unsortedKeyMap as map(*) :=
            map:merge(
              for $keydef in $keydefs
              let $keyNames as xs:string* := tokenize($keydef/@keys, '\s+')
              return
              for $keyName in $keyNames
              return 
              map {
                $keyName : $keydef
              },
              map{'duplicates' : 'combine'}
            )
          return 
          map:merge(
            for $key in map:keys($unsortedKeyMap)
            (: Put the key definitions in document order :)
            let $keydefs := $unsortedKeyMap($key) => util:ddo() 
            return map { $key : $keydefs}
          )        
        }
      }
  )
  
  (: Now add the child scope pointers to each key scope :)
  
  let $keyScopesMap as map(*) := keyspace:addChildScopes($scopes)
  let $pass1 as map(*) := 
    map{
      'root-scope' : $rootScopeKey, 
      'timestamp' : current-dateTime(),
      'source-ditamap' : db:path($rootMap),
      'keyscopes' : $keyScopesMap }
  
  return $pass1
};

(:~ 
 : Builds the scope tree by adding child scopes to each scope in the initial scope set, recursively.
 : @param keyScope Map for the key scope to add child scopes to
 : @param keySpace Map with all the key scopes in it.
 : @return Key scope map with the any child scopes added it.
 :)
declare function keyspace:addChildScopes($keySpace as map(*)) as map(*) {
  let $resultKeySpace as map(*) :=
  map:merge(
    for $scopeKey in map:keys($keySpace)
      let $keyScope as map(*) := $keySpace($scopeKey)
      let $childScopes as xs:integer* :=
          for $key in map:keys($keySpace)
          let $cand as map(*) := $keySpace($key)
          let $nearestAncestor as xs:integer? := $cand('ancestor-scopes')[1]
          return
            if ($nearestAncestor eq $scopeKey)
            then $key
            else ()
      let $newScope as map(*) := map:put($keyScope, 'child-scopes', $childScopes)
      return map{ $scopeKey : $newScope}
  )
  return $resultKeySpace
};

(:~ 
 : Perform pass 2 to pull key definitions up from descendant scopes to ancestor scopes.
 : @param keySpace Pass 1 key space map
 : @param resultKeySpace Key space with descendant keys pulled up.
 : @param Pass 2 key space map with descendant key definitions pulled up.
 :)
declare function keyspace:pass2($keySpace as map(*)) as map(*) {
  let $debug := prof:dump('keyspace:pass2: Starting...')
  let $rootScope as map(*) := $keySpace('keyscopes')($keySpace('root-scope'))
  let $keyScopesMap as map(*) := keyspace:pullDescendantScopes($rootScope, $keySpace, map{})
  let $debug := prof:dump('keyspace:pass2: Done.')
  return map:put($keySpace, 'keyscopes', $keyScopesMap)
};

(:~ 
 : Pulls descendant keys up into this key scope's key space.
 : @param keyScope The key scope to process
 : @param keySpace Pass 1 key space map
 : @param keyDefs Sequence of key-to-keydef maps pulled from descendants.
 : @return Map of key scope IDs to key scopes
 :)
declare function keyspace:pullDescendantScopes(
  $keyScope as map(*), 
  $keySpace as map(*),
  $resultKeyScopes as map(*)
)
  as map(*)
{
  let $childScopes as map(*)* := ($keyScope('child-scopes') ! $keySpace('keyscopes')(.))
  return
  if (exists($childScopes))
  then (: Process the children then add their key defs to this scope :)
    let $myKeydefs as map(*) := $keyScope('keydefs')
    (: Result is a new keyspaces map :)
    let $newChildScopes as map(*) :=
      map:merge(
        for $childScope in $childScopes 
        return keyspace:pullDescendantScopes($childScope, $keySpace, $resultKeyScopes)
      )
    let $pulledKeys as map(*)* :=
        for $childScope in ($keyScope('child-scopes') ! $newChildScopes(.))
        let $keydefsMap as map(*) := $childScope('keydefs')
        return
        for $key in map:keys($keydefsMap)
        return
        for $scopeName in ($childScope?scope-names)
        return
        map { 
           string-join(($scopeName, $key), '.') : $keydefsMap($key)
        }
    let $newKeydefs as map(*) := 
      map:merge(
        ($keyScope?keydefs,
         $pulledKeys
        ),
        map{ 'duplicates' : 'combine'}
      )
    let $newKeyscope as map(*) :=
       map{
         $keyScope('scope-key') :
         map:put($keyScope, 'keydefs', $newKeydefs)
       }
    return
    map:merge(($newChildScopes, $newKeyscope))
  else 
    let $newKeyscopesMap as map(*) := map:merge(($resultKeyScopes, map{$keyScope('scope-key') : $keyScope}))
    return $newKeyscopesMap
  
};

(:~ 
 : Perform pass 3 to push key definitions down from parent to child scopes
 : @param keySpace Pass 2 key space map
 : @param resultKeySpace Key space with ancestor keys pushed down
 : @param Pass 3 key space map with ancestor keys pushed down.
 :)
declare function keyspace:pass3($keySpace as map(*)) as map(*) {
  let $debug := prof:dump('keyspace:pass3: Starting...')
  let $rootScope as map(*) := $keySpace('keyscopes')($keySpace('root-scope'))
  let $keyScopesMap as map(*) := keyspace:pushKeysToDescendantScopes($rootScope, $keySpace('keyscopes'))
  let $debug := prof:dump('keyspace:pass3: Done.')
  return map:put($keySpace, 'keyscopes', $keyScopesMap)
};

(:~ 
 : Push keys from input keyscope to its child scopes
 : @param keyScope The key scope to push keys from
 : @param keyScopesMap The map of scope IDs to keyscopes
 : @return Result key scopes map with update key scopes
 :)
declare function keyspace:pushKeysToDescendantScopes($keyScope as map(*), $keyScopesMap as map(*))
  as map(*) {
  let $debug := prof:dump('keyspace:pushKeysToDescendantScopes(): Handling key scope ' || $keyScope('scope-id') || '...')
  let $childScopes as map(*)* := ($keyScope('child-scopes') ! $keyScopesMap(.)) 
  return
  if (exists($childScopes))
  then 
    let $myKeyDefs as map(*) := $keyScope('keydefs')
    let $newChildScopes as map(*) := 
      map:merge(
        for $childScope in $childScopes
        let $newKeyDefs as map(*) :=
          map:merge(
            ($myKeyDefs, $childScope('keydefs')), 
            map{'duplicates' : 'combine'}
          )
        return 
          map{
            $childScope('scope-key') :
            map:put($childScope, 'keydefs', $newKeyDefs)
          }
      )
    let $newKeyScopesMap as map(*) := map:merge(($keyScopesMap, $newChildScopes), map{'duplicates' : 'use-last'})
    (: Now apply push to each descendant :)
    return 
      map:merge(
        for $childScope in ($keyScope('child-scopes') ! $newKeyScopesMap(.)) 
        return keyspace:pushKeysToDescendantScopes($childScope, $newKeyScopesMap)
      )
  else
    $keyScopesMap
};


(:~ 
 : Get the key scopes with the specified name.
 : @param keySpace The key space to get the key scope from
 : @param scopeName The name of the scope to look up.
 : @return Zero or more key scopes. When key scopes are returned, their order
 : is undefined. Use the scope-def values to establish the document order of 
 : the scopes.
 :)
declare function keyspace:getScopesByName(
  $keySpace as map(*), 
  $scopeName as xs:string) as map(*)* {

  let $keyScopes as map(*) := $keySpace('keyscopes')
  for $key as xs:integer in map:keys($keyScopes)
  let $keyScope as map(*) :=  $keyScopes($key)
  let $scopeNames as xs:string+ := $keyScope('scope-names')
  where $scopeName = $scopeNames
  return map:get($keyScopes, $key)      
};

(:~ 
 : Get the node ID of an element, either from its @nodeid attribute or from
 : the database.
 : @param node The node to get the node ID for
 : @return The node ID as an integer
 :)
declare function keyspace:getNodeId($node as node()) as xs:integer {
  (: let $debug := (prof:dump('keyspace:getNodeId(): node:'), prof:dump($node)) :)
  let $attNodeid := xs:integer($node/@nodeid)
  let $debug := prof:dump('nodes db: ' || db:name($node))
  let $dbNodeId := db:node-id($node)
  (: let $debug := prof:dump('attNodeid: ' || $attNodeid || ', dbNodeId: ' || $dbNodeId) :)
  return ($attNodeid, $dbNodeId)[1]
};