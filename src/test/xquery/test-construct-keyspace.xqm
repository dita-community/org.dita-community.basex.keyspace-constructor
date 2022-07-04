module namespace test="http://basex.org/modules/unit";

import module namespace keyspace = "http://dita-community.org/basex/keyspace/xquery/module/construct-keyspace";

declare variable $test:rootMap as element() := db:open('test-data', 'simple-scoped-map/simple_scoped_map.ditamap')/*;

declare %unit:test function test:testScopedMap() {
  let $keyspace as element(keyspace:keyspace) := keyspace:constructKeySpace($test:rootMap)
  let $keyScopes as element(keyspace:keyscope)* := $keyspace//keyspace:keyscope
  return (
    unit:assert(exists($keyspace), 'Expected a keyspace'),
    unit:assert(count($keyScopes eq 4), 'Expected 4 keyscopes, got ' || count($keyScopes)),
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