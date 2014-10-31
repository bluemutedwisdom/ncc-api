NCC-API Roadmap
===============

Various features and fixups need to be added into the NCC-API.

Operations
----------

* NCC-API needs a clean way to use authentication and incorporate it into actions (e.g. "created_by").
* The logger interface needs to align with typical Rack and Ruby logging classes, and then use them.

User Data
---------

Need a "first class" way to specify user data for cloud-init.

CMDB
----

Factor Inventory/CMDB calls into isolated hook or plugin classes and separate the "naming authority" function. Provide ability to plug other CMDB-type providers (or other integrations like DNS) into important points in the NCC-API instance lifecycle.

Code
----

The instance type should be more cleanly encapsulated and sizes, images should probably.

Networks
--------

NCC-API should have a notion of networks on which to locate instances. You should be able to discover them and set them in a "first-level" way when creating instances.

Roles
-----

When specifying a role, NCC-API should have a way of understanding a role specification that affects instance provisioning, such as:

* Network location
* Instance size and image

This should probably take the form of a role specification that can be plugged and is written in a Ruby DSL that transforms or rejects the instance request.

Questions
~~~~~~~~~

* NCC-API roles should probably be considered immutable?
* Should NCC-API attempt to store the roles in the cloud provider (probably--this makes it much more capable if no CMDB is used)?
  * In which case it should return them--*from the cloud provider*.

Cloud Providers
---------------

More cloud providers supported (fogdocker, softlayer)

Actions
-------

You should be able to do more than reboot instances.

The ``console_log`` sub-object of instances is not "discoverable". A URL for the console_log should be provided as (as probably should be the console itself) an attribute of the instance. In fact, more REST entities should be discoverable.

Vague Features
--------------

The following are more vague features potentially useful for inclusion in NCC-API:

* Storage (provisioning, "linking" to instances)
