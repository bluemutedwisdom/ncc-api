#!ruby
# /* Copyright 2013 Proofpoint, Inc. All rights reserved.
#    Copyright 2014 Evernote Corporation. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# */

class NCC::Connection::OpenStack < NCC::Connection

    def size_id_field
        :name
    end

    def image_id_field
        :name
    end

    def translate_size(flavor)
        generic_translate(:size, flavor).
            merge({
                      'ram' => flavor.ram,
                      'cores' => flavor.vcpus,
                      'description' => size_desc(flavor),
                      'disk' => flavor.disk + flavor.ephemeral
                  })
    end

    def translate_image(pimage)
        image = generic_translate(:image, pimage)
        pimage.metadata.each do |metadatum|
            if %(ramdisk_id kernel_id).include? metadatum.key
                image[metadatum.key] = metadatum.value
            end
        end
        image
    end

    def provider
        'openstack'
    end

    def size_desc(f)
        (f.vcpus > 1 ? "#{f.vcpus}CPU " : "") +
            "#{(f.ram / 1024).round}GB RAM #{f.disk + f.ephemeral}GB disk"
    end

    def connection_params
        ['openstack_auth_url', 'openstack_username', 'openstack_api_key', 'openstack_tenant']
    end

    def map_to_status(provider_status)
        case provider_status
        when 'ACTIVE', 'PASSWORD', 'SHUTOFF'
            'active'
        when 'BUILD'
            'build'
        when 'DELETED'
            'terminated'
        when 'ERROR'
            'error'
        when 'HARD_REBOOT'
            'hard-reboot'
        when 'REBOOT'
            'reboot'
        when 'REBUILD', 'RESCUE', 'RESIZE', 'REVERT_RESIZE'
            'provider-operation'
        when 'SUSPENDED'
            'suspend'
        when 'UNKNOWN'
            'unknown'
        when 'VERIFY_RESIZE'
            'needs-verify'
        else
            'unknown'
        end
    end

    def instance_image(server)
        map_from_raw_provider_id(:image, server.image['id'])
    end

    def instance_size(server)
        map_from_raw_provider_id(:size, server.flavor['id'])
    end

    def instance_status(server)
        map_to_status(server.state)
    end

    def instance_ip_address(server)
        server.private_ip_address.to_s
    end

    def instance_host(server)
        server.os_ext_srv_attr_host
    end

    def console_log(instance_id)
        server = @fog.servers.get(instance_id)
        if server.nil?
            instance_not_found instance_id
        else
            begin
                server.console.body
            rescue Exception => e
                communication_error e.message
            end
        end
    end

    def provider_request_of(instance)
        {
            :name => instance.name,
            :flavor_ref => sizes(instance.size)['provider_id'],
            :image_ref => images(instance.image)['provider_id'],
        }.merge(instance.extra provider)
    end

    def reboot(instance_id)
        server = @fog.servers.get(instance_id)
        if server.nil?
            instance_not_found instance_id
        else
            server.reboot 'HARD'
        end
    end

    def map_to_provider_status(abstract_status)
        case abstract_status
        when 'active', 'provider-operation', 'shutting-down', 'suspending'
            'ACTIVE'
        when 'build'
            'BUILD'
        when 'terminated'
            'DELETED'
        when 'error'
            'ERROR'
        when 'hard-reboot'
            'HARD_REBOOT'
        when 'reboot'
            'REBOOT'
        when 'suspend'
            'SUSPENDED'
        when 'unknown'
            'UNKNOWN'
        when 'needs-verify'
            'VERIFY_RESIZE'
        else
            'UNKNOWN'
        end
    end

end
