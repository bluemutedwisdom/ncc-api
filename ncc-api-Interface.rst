Operations
==========

Create Instance
---------------

.. ::

   HTTP: POST /ncc_api/v2/clouds/_cloud_/instances

============== =============================================================
Parameter      Description
============== =============================================================
size           An abstract size. Configuration will map abstract sizes to
               provider-specific sizing.
role           The role of the server living on the instance. This can be
               used by configurable logic to inform compute node scheduling,
               check allowed sizes and platform images.
environment    The noms environment which will be associated with the
               instance
image          The (abstractly-named) boot image. Configuration will
               translate abstract image names to provider-specific image
               names or Ids.
-subnet-       -The named subnet on which to create the instance. This
               allows instance placement on specific networks if supported
               by the cloud.-
extra          Extra request parameters to be passed to the underlying
               cloud provider.
============== =============================================================

The *subnet* parameter will be added in a future version.

Result: 202 Accepted

============== =============================================================
Parameter      Description
============== =============================================================
name           The name of the instance
id             The identifier of the instance
role           Role (if it was given)
-subnet-       -Subnet (will be default if not given)-
size*          Size (will be default if not given)
image*         Image (will be default if not given)
environment*   Environment (will be default if not given)
status         An abstract status (translated from provider-specific
               statuses)
============== =============================================================

Errors: 503 Service Unavailable

Creates the instance, returns an error if the instance can't be created/scheduled.

The *extra* paramater is structured to pass in provider-specific extensions to
the request. It is an object, the members of which identify the provider type
to which the options apply. For example, to pass the extended request parameter
*different_hosts* to an OpenStack provider, set *extra* like so::

   { "extra": {
       "openstack": {
            "os_scheduler_hints": {
            "different_host": ["214cc582-0041-46d8-9158-a1459a8233d7"]
         }
       }
     }
   }

Terminate Instance
------------------

.. ::

   HTTP: DELETE /ncc_api/v2/clouds/_cloud_/instances/_id_

Result: 202 Accepted

Errors: 404 Not Found
   503 Service Unavailable

Instance Information
--------------------

.. ::

   HTTP: GET /ncc_api/v2/clouds/_cloud_/instances/_id_
   -GET /ncc_api/v2/clouds/_cloud_/instances/_name_-

============== =============================================================
Parameter      Description
============== =============================================================
name           The name of the instance
id             The identifier of the instance
size           Size
subnet         Subnet
image          Image
status         An abstract status (translated from provider-specific
               statuses)
============== =============================================================

Console Log
-----------

.. ::

   HTTP: GET /ncc_api/v2/clouds/_cloud_/instances/_id_/console_log

Returns plain text of console log.


Reboot
------

Reboot the OS of an instance.

.. ::

   HTTP: PUT /ncc_api/v2/locations/_location_/instances/_id_

============== =============================================================
Parameter      Description
============== =============================================================
status         ``reboot``
============== =============================================================

Location Information
--------------------

Use cases:

* List clouds (GET /ncc_api/v2/clouds)
* Get status for all locations (GET /ncc_api/v2/clouds)
* Get status for a specific location (GET /ncc_api/v2/cloud/_cloud_)
* Get available instance sizes (GET /ncc_api/v2/sizes)
* Get available instance sizes for this location (GET /ncc_api/v2/clouds/_cloud_/sizes)
* Get available images (GET /ncc_api/v2/images)
* Get available images for this location (GET /ncc_api/v2/clouds/_cloud_/images)

Instance Status
---------------

Statuses marked with (+) can be updated by the client, which causes the action
listed.

=================== ============== ============ == ==============================
NCC Status          Openstack_     `AWS EC2`_      Description
=================== ============== ============ == ==============================
active              ACTIVE         running         The instance is active
build               BUILD          pending         The instance has not finished
                                                   the original build process
terminated          DELETED        terminated      The instance is deleted
error               ERROR                          The instance is in error
hard-reboot (+)     HARD_REBOOT                    The instance is hard rebooting
active              PASSWORD                       The password is being reset on
                                                   the instance
reboot (+)          REBOOT                         The instance is in a soft
                                                   reboot state
provider-operation  REBUILD                        The instance is currently
                                                   being rebuilt from an image
provider-operation  RESCUE                         The server is in rescue mode
provider-operation  RESIZE                         Server is performing the
                                                   differential copy of data that
                                                   changed during its initial
                                                   copy
provider-operation  REVERT_RESIZE                  The resize or migration of a
                                                   instance failed for some
                                                   reason. The destination
                                                   instance is being cleaned up
                                                   and the original source
                                                   instance is restarting
active              SHUTOFF                        The instance was powered down
                                                   by the user
shutting-down                      shutting-down
suspending                         stopping
suspend (+)         SUSPENDED      stopped         The instance is suspended
unknown             UNKNOWN                        The state of the instance is
                                                   unknown
needs-verify        VERIFY_RESIZE                  System is awaiting confirmation
                                                   that the server is operational
                                                   after a move or resize
=================== ============== ============ == ==============================

.. _Openstack: http://docs.openstack.org/api/openstack-compute/2/content/List_Servers-d1e2078.html

.. _`AWS EC2`: http://docs.aws.amazon.com/AWSEC2/latest/APIReference/ApiReference-ItemType-InstanceStateType.html


Errors
------

Errors should be presented with customary HTTP response codes and include an
error object including helpful messages describing the specifics of the error.
For example::

   404 Not Found
   Content-type: application/json

   { "error": "404",
     "message": "Instance a50eb0d4-64bf-11e2-a2be-57c6bf471819 does not exist in cloud SNV-LAB-1"
   }

   507 Insufficient storage
   Content-type: application/json

   { "error": "507",
     "message": "Requested instance of size c1.large exceeds limits for cloud AWSLAB-1"
   }

When additional detail is called for (e.g. by query parameter) a "details"
attribute will also be provided with additional information (debugging, stack
trace, &c.).

Configuration
-------------

The heart of the NCC API will be in configuration, which will configure plugins
to load for providers, all the clouds, mapping between abstract size and image
names, etc.

The configuration should be re-read on demand so that new clouds can be added
and removed dynamically.

Request Flow
------------

Client -> ncc-api: POST /v2/../instance
note left of Client
Create
end note
ncc-api -> CMDB: request for name
CMDB -> ncc-api: response with name
ncc-api -> Cloud: translated request
Cloud -> ncc-api: response with Id
ncc-api -> CMDB: system update
ncc-api -> Client: 201 Created

note left of Client
GET
end note
Client -> ncc-api: GET /v2/../id
ncc-api -> Cloud: get status
Cloud -> ncc-api: response
ncc-api -> Client: response

