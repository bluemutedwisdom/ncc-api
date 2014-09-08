ncc-api
=======

The NOMS cloud controller API provides a ReSTful API abstracting and aggregating a set of
specific cloud computing providers (called "clouds").

Definitions
-----------

========= ===========================================================
Term      Definition
========= ===========================================================
cloud     The object in ncc-api that refers to an external cloud
          provider instance (e.g. a particular relationships with
          Amazon AWS or OpenStack cluster).
--------- -----------------------------------------------------------
provider  A type of cloud (e.g., "openstack" or "aws")
--------- -----------------------------------------------------------
size      An abstract notion of a machine size, corresponding to
          roughly equivalent memory, CPU and disk configurations in
          each cloud.
--------- -----------------------------------------------------------
image     An abstract notion of an image, mapped to equivalent
          OS/platform images in each cloud.
--------- -----------------------------------------------------------
instance  A cloud computing instance, virtual machine or server
--------- -----------------------------------------------------------
cmdb      A system asset store that gets updated when instances are
          created or destroyed
========= ===========================================================

Technologies
------------

The **ncc-api** is built using fog_ and sinatra_. It includes a library for
managing a possibly-changing compex hierarchical file-based configuration,
ensuring current values for the configuration items within.

.. _fog: http://fog.io/

.. _sinatra: http://sinatrarb.com/

Configuration
-------------

**ncc-api** expects its configuration to be composed of the following
  structure:

* ``services.conf`` - includes other services to advertise at root (e.g. other
ncc-api versions)
* ``inventory.conf`` - cmdb configuration
* ``sizes/`` - A file for each size to be offered by **ncc-api**
* ``images/`` - A file for each image to be offered by **ncc-api**
* ``providers/`` - A file for each provider, specifying configuration for all
clouds of that type
* ``clouds/`` - A file for each cloud, specifying configuration for that cloud

All files are JSON-serialized configuration files containing a single JSON
object.
