module namespace keyspace = "http://dita-community.org/basex/keyspace/xquery/module/construct-keyspace";

(:~ 
 : Construct a key space from a root map
 : @param rootMap The root map to construct the key space from
 : @return The key space document.
 :)
declare function keyspace:constructKeySpace($rootMap as element()) as element(keyspace:keyspace) {
  <keyspace:keyspace></keyspace:keyspace>
};
