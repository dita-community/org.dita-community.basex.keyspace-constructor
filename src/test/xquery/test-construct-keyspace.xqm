module namespace test="http://basex.org/modules/unit";

import module namespace keyspace="http://dita-community.org/basex/keyspace/xquery/module/construct-keyspace";

declare variable $test:rootMap as element() := 
<map>
  <title>Simple scoped map</title>
  <topicref keys="key-01" href="topic-01-1.dita"/>
  <topicgroup keyscope="scope-A">
    <topicref keys="key-01" href="topic-01-A.dita"/>
    <topicref keys="key-02" href="topic-02-A.dita"/>
    <topicgroup keyscope="scope-C">
      <topicref keys="key-01" href="topic-01-C.dita"/>
      <topicref keys="key-02" href="topic-02-C.dita"/>
    </topicgroup>    
  </topicgroup>
  <topicgroup keyscope="scope-B">
    <topicref keys="key-01" href="topic-01-B.dita"/>    
    <topicref keys="key-02" href="topic-02-B.dita"/>
    <topicref keys="key-03" href="topic-02-B.dita"/>
  </topicgroup>
</map>
;

declare %unit:test function test:testScopedMap() {
  let $keyspace as element(keyspace:keyspace) := keyspace:constructKeySpace($test:rootMap)
  return (
    unit:assert(exists($keyspace), 'Expected a keyspace'),
    ()
  )
};