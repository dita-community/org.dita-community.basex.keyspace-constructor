module namespace keyspace = "http://dita-community.org/basex/keyspace/xquery/module/construct-keyspace";

(:~ 
 : Construct the XML representation of a key space  from a root map
 : @param rootMap The root map to construct the key space from
 : @return The key space document.
 :)
declare function keyspace:constructKeySpace($rootMap as element()) as element(keyspace:keyspace) {
  let $pass1keySpace as map(*) := keyspace:pass1($rootMap)
  let $pass2keySpace as map(*) := keyspace:pass2($pass1keySpace)
  let $keySpace as map(*) := $pass1keySpace (: Replace with pass 2 once pass 2 is working. :)
  let $keyspacePass1 as element(keyspace:keyspace) :=
  <keyspace:keyspace
    timestamp="{$keySpace('timestamp')}"
    source-ditamap="{$keySpace('source-ditamap')}"
  >{
    keyspace:serializeKeyscopeToXml(keyspace:getRootScope($keySpace), $keySpace)
  }</keyspace:keyspace>
  let $keyspacePass2 as element(keyspace:keyspace) :=
      keyspace:pullUpKeydefs($keyspacePass1)
  return $keyspacePass2
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
        <keyspace:keydef nodeid="{db:node-id($keydef)}">{
          ($keydef/@*, $keydef/*[contains-token(@class, 'topic/navtitle')])
        }</keyspace:keydef>
      }</keyspace:key>
    }</keyspace:keys>
    {
      let $childScopes as map(*)* := ($keyScope('child-scopes') ! $keySpace('keyscopes')(.))
      (: Put the scope-defining elements in document order :)
      let $scopeDefs as element()* := $childScopes?scope-def => util:ddo()
      return
      for $scopeDef in $scopeDefs
      let $nodeId as xs:integer := db:node-id($scopeDef)
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

  let $keydefs as element()* := $rootMap//*[@keys]
  let $rootScopeKey as xs:integer := db:node-id($rootMap)
  
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
          'ancestor-scopes' : 
          if ($scopeKey eq $rootScopeKey)
          then ()
          else
            (($scopeDef/ancestor::*[@keyscope], root($scopeDef)/*)) ! db:node-id(.),
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
  let $rootScope as map(*) := $keySpace('keyscopes')($keySpace('root-scope'))
  let $resultKeySpace := keyspace:pullDescendantScopes($rootScope, $keySpace)
  return $resultKeySpace
};

(:~ 
 : Pulls descendant keys up into this key scope's key space.
 : @param keyScope The key scope to process
 : @param keySpace Pass 1 key space map
 : @param keyDefs Sequence of key-to-keydef maps pulled from descendants.
 : @return The key scope with pulled-up keydefs added to it.
 :)
declare function keyspace:pullDescendantScopes(
  $keyScope as map(*), 
  $keySpace as map(*)) 
  as map(*) 
{
  let $childScopes as map(*)* := ($keyScope('child-scopes') ! $keySpace(.))
  (: let $debug := (prof:dump('keySpace'), prof:dump($keySpace)) :)
  let $pulledKeydefs as map(*)* := () (: keyspace:pullKeydefsFromScopes($childScopes, $keySpace, map{}) :)
  let $newKeydefs as map(*) := 
     map:merge(
       ($keyScope('keydefs'),
        $pulledKeydefs), 
       map{'duplicates' : 'combine'})
  return map:put($keyScope, 'keydefs', $newKeydefs)
  
};

(:~ 
 : Collect scope-qualified key names from a sequence of key scopes
 : @param childScopes Zero or more key scopes to get the keys from.
 : @param keySpace The key space that contains the scopes
 : @param keyDefs The accumulated key definitions from any ancestor scopes.
 : @return Sequence of key definition maps, one for each key-defining topicref
 :)
declare function keyspace:pullKeydefsFromScopes(
  $childScopes as map(*)*,
  $keySpace as map(*),
  $keyDefs as map(*)*) 
    as map(*)* {
  let $newKeydefs as map(*)* := 
  for $scope in $childScopes
  return keyspace:getScopeQualifiedKeydefsForScope($scope, $keySpace)
  let $resultKeydefs as map(*) := (
    $keyDefs,
    $newKeydefs
  )  
  return $resultKeydefs
};

(:~ 
 : Gets the scope-qualified key definitions from a key scope
 : @param keyScope The key scope to get the key definitions for
 : @param keySpace The key space that contains the scope
 : @return Sequence of key definition maps(*)
 :)
declare function keyspace:getScopeQualifiedKeydefsForScope(
  $keyScope as map(*), 
  $keySpace as map(*)) 
    as map(*)* {
  let $scopeNames as xs:string+ := $keyScope('scope-names')
  let $descendantKeys as map(*)* :=
    for $childScope in ($keyScope('child-scopes') ! $keySpace(.))
    return keyspace:getScopeQualifiedKeydefsForScope($childScope, $keySpace)
  let $resultKeydefs as map(*)* :=
    for $scopeName in $scopeNames
    return
    for $key in map:keys($keyScope('keydefs'))
    return map{ string-join(($scopeName, $key) , '.') : $keyScope('keydefs')($key)}
  return $resultKeydefs
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
 : Pull descendant keydefs up into ancestor keydefs
 :)
declare function keyspace:pullUpKeydefs($keyspacePass1 as element(keyspace:keyspace)) 
    as element(keyspace:keyspace) {
   let $debug := prof:dump('keyspace:pullUpKeydefs(): Starting')
   let $result as element(keyspace:keyspace) :=
   <keyspace:keyspace>
   {
     $keyspacePass1/@*
   }
   {
     for $keyscope as element(keyspace:keyscope)* in $keyspacePass1/keyspace:keyscope
     return keyspace:pullUpKeydefsForKeyscope($keyscope)
   }
   </keyspace:keyspace>
   let $debug := prof:dump('keyspace:pullUpKeydefs(): Done')
   return $result
};

(:~ 
 : Pull descendant keydefs up into ancestor keydefs
 :)
declare function keyspace:pullUpKeydefsForKeyscope($keyscope as element(keyspace:keyscope)) 
    as element(keyspace:keyscope) {
   let $result :=
   <keyspace:keyscope>
     {
       $keyscope/@*,
       $keyscope/keyspace:scope-names
     }
     <keyspace:keys>
       {
         (: This scope's key definitions :)
         $keyscope/keyspace:keys/node()
       }      
       {
         (: Descendant key scopes' key definitions, with prefixes added :)
         for $key in $keyscope//keyspace:keyscope/keyspace:keys/keyspace:key
         let $keyscopes as element()+ := $key/ancestor::keyspace:keyscope[. >> $keyscope]
         (: FIXME: Need to account for multiple keyscope names:)
         let $scopePrefix as xs:string := $keyscopes/keyspace:scope-names/keyspace:scope-name[1] ! string(.) => 
                                          string-join('.')
         return 
         <keyspace:key>{
             attribute keyname { string-join(($scopePrefix, string($key/@keyname)), '.')}
           }
           {
             $key/node()
         }</keyspace:key>
       }
     </keyspace:keys>
     {
       (: Now process descendant key scopes :)
       for $childKeyscope as element(keyspace:keyscope)* in $keyscope/keyspace:keyscope
       return keyspace:pullUpKeydefsForKeyscope($childKeyscope)
     }
   </keyspace:keyscope>
   return $result
};

