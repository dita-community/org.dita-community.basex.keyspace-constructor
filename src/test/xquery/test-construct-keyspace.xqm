module namespace test="http://basex.org/modules/unit";

import module namespace keyspace = "http://dita-community.org/basex/keyspace/xquery/module/construct-keyspace";

declare variable $test:rootMap as element() := db:open('test-data', 'simple-scoped-map/simple_scoped_map.ditamap')/*;

declare %unit:test function test:testScopedMap() {
  let $keyspace as element(keyspace:keyspace) := keyspace:constructKeySpace($test:rootMap)
  let $debug := prof:dump($keyspace)
  let $keyScopes as element(keyspace:keyscope)* := $keyspace//keyspace:keyscope
  let $keydef01 as element(keyspace:key)? := ($keyspace//keyspace:key[@keyname eq 'key-01'])[1]
  let $keydef02 as element(keyspace:key)? := ($keyspace//keyspace:key[@keyname eq 'key-02'])[1]
  let $keydefScope01 as element(keyspace:keyscope)? := $keydef01/ancestor::keyspace:keyscope[1]
  let $keyscopeA as element(keyspace:keyscope)? := 
       $keyspace//keyspace:keyscope[(keyspace:scope-names/keyspace:scope-name ! string(.)) = 'scope-A']
  let $keyscopeB as element(keyspace:keyscope)? := 
       $keyspace//keyspace:keyscope[(keyspace:scope-names/keyspace:scope-name ! string(.)) = 'scope-B']
  return (
    unit:assert(exists($keyspace), 'Expected a keyspace'),
    unit:assert(count($keyScopes) eq 4, 'Expected 4 keyscopes, got ' || count($keyScopes)),
    unit:assert(exists($keydef01), 'Expected a keydef for key "key-01"'),
    unit:assert($keydefScope01 is $keyspace/keyspace:keyscope, 'Expected key-01 to be in root scope'),
    unit:assert(exists(($keydef02/keyspace:keydef)[1]/@nodeid), 'Expected a @nodeid attribute'),
    unit:assert(exists($keyscopeA), 'Didn''t find scope-A'),
    unit:assert(exists($keyscopeB), 'Didn''t find scope-B'),
    unit:assert($keyscopeA << $keyscopeB, 'Expected scope A to precede scope B'),
    
    ()
  )
};

declare %unit:test function test:testPass1() {
  let $keySpace as map(*) := keyspace:pass1($test:rootMap)
  let $rootScope as map(*)? := $keySpace('keyscopes')($keySpace('root-scope'))
  let $keymap as map(*) := $rootScope('keydefs')
  let $keyName as xs:string := map:keys($keymap)[1]
  let $keydef-01 as element()? :=  $keymap($keyName)[1]
  let $scopeA as map(*)* := keyspace:getScopesByName($keySpace, 'scope-A')
  let $debug := (prof:dump('keySpace map:'), prof:dump($keySpace))
  return (
    unit:assert(exists($keySpace), 'Expected a keyspace'),
    for $key in ('root-scope', 'keyscopes', 'source-ditamap', 'timestamp')
    return
      unit:assert(map:contains($keySpace, $key), 'Expected ' || $key || ' key in keySpace map'),
    unit:assert(map:contains($keySpace, 'root-scope'), 'Expected root-scope key in key space map'),
    for $key in ('scope-key', 'scope-def', 'keydefs', 'scope-names', 'child-scopes', 'ancestor-scopes')
    return
      unit:assert(map:contains($rootScope, $key), 'Expected ' || $key || ' key in keyscope map'),
    unit:assert(exists($scopeA), 'Expected to have found scope-A by name'),
    unit:assert(exists($keydef-01), 'Expected a keydef element'),
    unit:assert(string($keydef-01/@href) eq 'topic-01-1.dita', 'Expected topic-01-1.dita, found "' || $keydef-01/@href || '"'),
    ()
  )
};