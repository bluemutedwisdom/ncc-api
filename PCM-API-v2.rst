PRISM Cloud Management API (PCM-API) is a server providing a remote API aggregating and abstracting the differences between cloud providers.

Interface
---------

* `PCM-API-v2-Interface`_
* `PCM-API-v2-Roadmap`_

Source Code and Technologies
----------------------------

* Ruby (1.8.7+)
* Fog_ |http://fog.io/]
* Sinatra_ |http://sinatrarb.com/]

.. _Fog: http://fog.io/

.. _Sinatra: http://sinatrarb.com

Configuration
-------------

PCM-API expects a configuration in {{/etc}} consisting of directories and files in JSON format. This is documented in the README.rst file in the source code repository.

This configuration is deployed using Puppet based on service instances.
