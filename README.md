# BaseX DITA Key Space Constructor

This project implements a simple DITA key space constructor that demonstrates a basic three-pass algorithm for constructing scoped key spaces.

The project consists of a set of XQuery modules that do the key space construction and access and a simple RESTXQ web application that lets you view and explore the resulting key spaces.

## Installation and setup

NOTE: These instructions reflect using macOS, linux, or a linux-style command line under Windows.

### Prerequisites

This code requires the `ant` command and Java. If you do not have `ant` installed you will need to install it. If you have the OxygenXML editor installed you can use Ant from the Oxygen installation (it's in the `tools/ant` directory under the main Oxygen installation directory).

On macOS you can use Homebrew to install Java and ant. On Windows you'll have to figure it out.

### Setup and run the web application

To run the code perform the following steps:

1. Clone this repository to your machine 
1. Download the [BaseX Zip package](https://basex.org/download/). You want the Zip package, not the jar, because you need the BaseX HTTP server
1. Unzip the package in an appropriate place, i.e., `~/apps/basex`.
1. In either your home directory or in the working directory for your clone of this project, create a file named `.build.properties` (note the leading `.`) and put the following entries in it
    ```
    # For BaseX stuff:
    basex.home.dir=${user.home}/apps/basex
    basex.repo.dir=${user.home}/apps/basex/repo
    basex.webapp.dir=${user.home}/apps/basex/webapp
    ```

    Where `${user.home}/apps/basex` is wherever you unpacked the BaseX zip to
1. Cd to the `org.dita-community.basex.keyspace-constructor/src/main` directory
1. Run the command `ant` with no parameters.

   This command uses the values in the `.build.properties` file to deploy the XQuery code to BaseX.
1. From the BaseX `bin` directory run the `basexhttp` command as a background task:
   ```
   % basexhttp &
   %
   ```
1. From the BaseX `bin` directory run the `basexgui` command as a backgroud task:
   ```
   % basexgui &
   %   
   ```

   This opens the BaseX GUI
1. From the BaseX GUI select _Database_ -> _New..._ to open the Create Database dialog
1. Set the dialog fields as follows:
   * Parsing tab:
     * Parse DTDs and entities: Checked
     * Use XML Catalog file: Checked
     * Catalog file to use: Select the `catalog-dita.xml` file from a 3.x Open Toolkit (to make sure you're using DITA 1.3 DTDs). The    * General tab:
     * Input file or directory: Choose the `org.dita-community.basex.keyspace-constructor/src/test/resources/dita/` directory
     * Name of database: "test-data"
     * Input format: XML
     * File patterns: `*.xml,*.dita*`
     * Skip corrupt: Checked
     * Parse files in archives: Unchecked
Open Toolkit included with Oxygen XML will serve (`frameworks/dita/DITA-OT3.x` under the Oxygen installation directory).
     
   Make sure the "Name of database" field is set to "test-data" and select "OK" to create the database. It should take a few seconds to load the database.
   
   You can inspect the database from the BaseX GUI Manage Databases dialog. It should show that there are about 272 nodes in the database (nodes in this context meaning XML nodes: elements, text nodes, etc.).
1. Open a browser window to `localhost:8984/ditacomm
  
   You should see the "DITA Community Key Space Constructor Application" page with the key space report for the `simple_scoped_map.ditamap`.

If you get any errors, check your configuration to make sure the properties in `.build.properties` are correct. If you change the properties, re-run the `ant` command from the `src/main` directory to redeploy the web application to BaseX.

### Looking at the code

The best way to inspect the XQuery code is to use the BaseX GUI after you have deployed the web application. BaseX will be able to resolve the module references in the code where OxygenXML or some other XQuery editor probably will not be able to.

The relevant source files are:

* `src/main/xquery/modules/construct-keyspace.xqm` -- XQuery module that implements key space construction.
* `src/main/webapp/ditacomm/root.xqm` -- RESTXQ module that implements the `/ditacomm` URL to produce an HTML report for key spaces.
* `src/test/xquery/test-construct-keyspace.xqm` -- BaseX unit test module for `contruct-keyspace.xqm` 

## How it works

The XQuery module `construct-keyspace.xqm` provides the functions that take a DITA map as input and produces an XML representation of the map's key space.

By using XML to represent the key space, rather than XQuery maps, it is easy to use normal XPath expressions to find the correct binding for a given key in a given key scope.

In the XML, each key scope is represented by a keyscope element and the scopes are nested in the order they occurred in the input DITA map. In addition, each scope's keys occur in the XML before any nested child scopes. For each unique key name with a scope, the topicrefs that name that key are put in document order as they occurred in the input DITA map. This all ensures that selecting a key by key name will select the binding with the highest priority per the DITA key precedence rules using normal XPath selection. 

To construct the final key space, the XQuery code first uses a three-pass process using XQuery maps to populate the key scopes with all the necessary key bindings and then uses the XQuery map to construct the final XML representation of the key space.

The three pass process using XQuery maps operates as follows:

1. The first pass constructs an XQuery map where the main field is a map of key scopes, where each key scope is identified by the BaseX node ID of the DITA element that declares the scope. The key space map also records the ID of the root scope. Each key scope is represented by an XQuery map that captures the key scope names, the IDs of any ancestor or child scopes, and an XQuery map of key names to DITA key-defining elements. After pass one, each key scope reflects the keys directly defined in that scope.
1. The second pass "pulls up" key definitions from descendant scopes to ancestor scopes, adding scope names to create scope-qualified key definitions for all keys from descendant scopes. After pass two each key scope reflects its directly-defined keys and the keys from descendant scopes.
1. The third pass "pushes down" key definitions from ancestor scopes to descendant scopes so that each scope reflects all keys defined directly in the scope as well as any keys pulled up from descedant scopes in pass two. After pass three each scope reflects the full set of key definitions, including definitions imposed from ancestor scopes as well as scope-qualified keys pushed down from ancestors after having been pulled up from descendant scopes.

At this point the XQuery key space map reflects the full key space ready to be serialized into an XML form from which key definitions can be quickly and easily looked up. The function `keyspace:constructKeySpace()` constructs the XQuery key space map using the three-pass process and then generates the XML for the key space. The function `keyspace:serializeKeyscopeToXml()` serializes a key scope to XML, including serializing any child scopes. Thus, calling it with the root scope entry from the XQuery key space map results in the full XML serialization of all the scopes (because the root scope necessarily includes all descendant scopes).

