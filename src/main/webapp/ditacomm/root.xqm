module namespace ditacomm="http://dita-community.org/xquery/webapp";

declare
  %rest:GET
  %rest:path('/ditacomm')
  %output:method('html')
function ditacomm:root()
as element(html) {
  <html>
    <head>
      <title>DITA Community Namespace Constructor Application</title>
      <link href="/static/ditacomm/ditacomm.css" rel="stylesheet"/>
    </head>
    <body>
      <h1>DITA Community Namespace Constructor Application</h1>
    </body>
  </html>
};