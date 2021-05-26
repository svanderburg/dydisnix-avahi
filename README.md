Dynamic Disnix Avahi publisher
==============================
This package contains a simple prototype service and client to automatically
discover machine configurations and to generate Disnix infrastructure models
from them.

Moreover, it can be used to automatically notify clients in case of configuration
changes so the a system can be automatically redeployed (by using components
of the [Dynamic Disnix](https://github.com/svanderburg/dydisnix) toolset), if
needed.

It is based on the protocols implemented by the Avahi package (mDNS and DNS-SD).

Prerequisites
=============
In order to build Dynamic Disnix Avahi publisher from source code, the following
packages are required:

* [Dysnomia](http://nixos.org/disnix)
* [Disnix](http://nixos.org/disnix)
* [Avahi](http://avahi.org)

Installation
============
Dynamic Disnix is a typical GNU Autotools based package which can be compiled and
installed by running the following commands in a shell session:

```bash
$ ./configure
$ make
$ make install
```

When building from the Git repository, you should run the bootstrap script
first:

```bash
$ ./bootstrap
```

Usage
=====
This package contains both a server and a client.

Running the server
------------------
To make a target machine in the network discoverable, you should run the server
on it:

```bash
$ dydisnix-publishinfra-avahi
```

The above command publishes its properties through mDNS. It uses the output
of the following Dysnomia command to retrieve the machines properties:

```bash
$ dysnomia-containers --capture-infra
```

Consult the Dysnomia documentation for more information on how to configure
machine and container properties.

Running the client
------------------
To automatically discover the configurations of all machines (having the server
component installed) and generate an infrastructure model from it, run:

```bash
$ dydisnix-geninfra-avahi
{
  "machine1" = {
    properties."hostname"="machine1";
    properties."mem"="377648";
    properties."supportedTypes"=[ "process" "wrapper" ];
  };
  "machine2" = {
    properties."hostname"="machine2";
    properties."mem"="377648";
    properties."supportedTypes"=[ "process" "tomcat-webapplication" "wrapper" ];
  };
}
```

License
=======
Disnix is free software; you can redistribute it and/or modify it under the terms
of the [GNU Lesser General Public License](http://www.gnu.org/licenses/lgpl.html)
as published by the [Free Software Foundation](http://www.fsf.org) either version
2.1 of the License, or (at your option) any later version. Disnix is distributed
in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the
implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU Lesser General Public License for more details.
