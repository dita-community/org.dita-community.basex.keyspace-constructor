(:~ 
 : General DITA map processing
 :)
module namespace mapproc = "http://dita-community.org/basex/keyspace/xquery/module/map-processing";

import module namespace relpath="http://dita-community.org/basex/keyspace/xquery/module/relpath-utils";

(:~ 
 : Resolves map references to create a resolved map as a single XML instance.
 : @param rootMap The DITA map to resolve
 : @return Document node that is the resolved map
 :)
declare function mapproc:resolveMap($rootMap as element()?) as document-node()? {
  if (empty($rootMap))
  then ()
  else
    let $maprefs as element()* := $rootMap//*[string(@format) eq 'ditamap']
    return
    if (empty($maprefs))
    then document {$rootMap}
    else
    let $db as xs:string := db:name($rootMap)
    return
    document {
      mapproc:dispatchHandler($db, $rootMap)
    }
};

(:~ 
 : Applies the resolution processing to the 
 :)
declare function mapproc:dispatchHandler($db as xs:string, $node as node()) as node()* {
  let $debug := () (: prof:dump('mapproc:dispatchHandler(): node [' || db:node-id($node) || ']') :)
  return
  typeswitch ($node)
  case element() return
    if (string($node/@format) eq 'ditamap' and not(matches($node/@href, '^\s*$')))
    then mapproc:resolveMap($db, $node)
    else mapproc:copyElement($db, $node)
  default return $node  
};

(:~ 
 : Resolve a map reference
 : @param db Database name
 : @param elem Map referencing element
 : @return Submap element containing the resolved content
 :)
declare function mapproc:resolveMap($db as xs:string, $elem as element()) as node()* {
  (: let $debug := prof:dump('mapproc:resolveMap(): element ' || name($elem) || ' [' || db:node-id($elem) || ']') :)
  let $submapPath := relpath:resolveURI(string($elem/@href), '/' || db:path($elem))
  (: let $debug := prof:dump('mapproc:resolveMap(): submapPath="' || $submapPath || '"') :)
  let $submap as element()? := db:open($db, $submapPath)/*
  let $keyScopes as xs:string* := (tokenize($elem/@keyscope, '\s+'), tokenize($submap/@keyscope, '\s+'))
  return
  <submap orig-mapref="{$elem/@href}" class="+ map/topicref mapgroup-d/topicgroup mapproc-d/submap "
          xml:base="{'/' || (base-uri($elem) ! tokenize(., '/') => tail() => tail() => string-join('/'))}"
          nodeid="{db:node-id($submap)}"
  >
  {
    if (exists($keyScopes))
    then attribute {'keyscope'} {$keyScopes => string-join(' ')}
    else ()
  }
  {
    (: Put the map title into topicmeta/navtitle :)
    if (exists($submap/*[contains-token(@class, 'topic/title')]))
    then
    <topicmeta class="- map/topicmeta ">
      <navtitle class="- topic/navtitle ">{
         $submap/*[contains-token(@class, 'topic/title')]/node() ! mapproc:dispatchHandler($db, .)
      }</navtitle></topicmeta>
    else ()
  }
  {
    (: Process subnodes except any title :)
    ($submap/node() except ($submap/*[contains-token(@class, 'topic/title')])) ! mapproc:dispatchHandler($db, .)
  }</submap>
};

(:~ 
 : Make a shallow copy of an element
 : @param db Database name
 : @param elem Element to copy
 :)
declare function mapproc:copyElement($db as xs:string, $elem as element()) as node()* {
  let $debug := () (: prof:dump('mapproc:copyElement(): element ' || name($elem) || ' [' || db:node-id($elem) || ']') :)
  return
  element {name($elem)} {
    ($elem/@*,
     attribute {'nodeid'} {db:node-id($elem)},
     $elem/node() ! mapproc:dispatchHandler($db, .)
    )
  }
};