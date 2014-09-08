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

class NCC::Connection::AWS < NCC::Connection

    def translate_size(flavor)
        generic_translate(:size, flavor).
            merge({
                      'ram' => flavor.ram,
                      'disk' => flavor.disk,
                      'cores' => flavor.cores,
                      'description' => flavor.name
                  })
    end

    def translate_image(provider_image)
        generic_translate(:image, provider_image).
            merge({
                      'description' => provider_image.description,
                      'ramdisk_id' => provider_image.ramdisk_id,
                      'kernel_id' => provider_image.kernel_id
                  })
    end

    def provider
        'aws'
    end

    def use_only_mapped(type)
        case type
        when :image
            true
        when :size
            false
        end
    end

    def connection_params
        ['aws_access_key_id', 'aws_secret_access_key']
    end

    def instance_name(server)
        if ! server.tags.nil? and server.tags.has_key? 'Name'
            server.tags['Name']
        else
            nil
        end
    end

    def instance_size(server)
        map_from_raw_provider_id(:size, server.flavor_id)
    end

    def instance_image(server)
        map_from_raw_provider_id(:image, server.image_id)
    end

    def instance_status(server)
        map_to_status(server.state)
    end

    def instance_ip_address(server)
        server.private_ip_address
    end

    def console_log(instance_id)
        begin
            @fog.get_console_output(instance_id).body
        rescue Fog::Compute::AWS::NotFound
            instance_not_found instance_id
        rescue Exception => e
            communication_error e.message
        end
    end

    def provider_request_of(instance)
        {
                      :name => instance.name,
                      :flavor_id => sizes(instance.size)['provider_id'],
                      :image_id => images(instance.image)['provider_id'],
                      :tags => { 'Name' => instance.name }
        }.merge(instance.extra provider)
    end

    def map_to_status(aws_status)
        case aws_status
        when 'running'
            'active'
        when 'pending'
            'build'
        when 'terminated'
            'terminated'
        when 'shutting-down'
            'shutting-down'
        when 'stopping'
            'suspending'
        when 'stopped'
            'suspend'
        else
            'unknown'
        end
    end

    def map_to_provider_status(abstract_status)
        case abstract_status
        when 'active', 'error', 'hard-reboot', 'reboot', 'provider-operation',
            'unknown', 'needs-verify'
            'running'
        when 'build'
            'pending'
        when 'terminated'
            'terminated'
        when 'shutting-down'
            'shutting-down'
        when 'suspending'
            'stopping'
        when 'suspend'
            'stopped'
        else
            'running'
        end
    end

end
