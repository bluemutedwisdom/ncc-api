#!ruby
# /* Copyright 2013 Proofpoint, Inc. All rights reserved.
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


require 'ncc/config'
require 'ncc/connection'
require 'ncc/instance'
require 'ncc/error'
require 'cmdbclient'

class NCC
    attr_reader :config, :inventory

    def initialize(config_path=nil, opt={})
        @logger = opt[:logger] if opt.has_key? :logger
        config_path ||= [
            '/etc/ncc-api']
        config_path = [config_path] unless config_path.respond_to? :unshift
        config_path.unshift(File.join(ENV['NCCAPI_HOME'], 'etc')) if
            ENV['NCCAPI_HOME']
        @config = NCC::Config.new(config_path, :logger => @logger)
        @inventory = CMDBclient.new(@config)
        @clouds = { }
    end

    def debug(msg)
        if @logger.respond_to? :debug
            @logger.debug "#{me}: #{msg}"
        end
    end

    def me
        self.class
    end

    def connect(cloud, opt={})
        if ! @config[:clouds].has_key? cloud
            raise NCC::Error::NotFound, "Cloud #{cloud} not provided"
        end
        @clouds[cloud] ||= NCC::Connection.connect(self, cloud, opt)
        if @clouds[cloud].nil? or ! @clouds[cloud].current?
            @clouds[cloud] = NCC::Connection.connect(self, cloud, opt)
        end
        @clouds[cloud]
    end

    def clouds(cloud=nil, opt={})
        if cloud.nil?
            @config[:clouds].keys
        else
            connect(cloud, :logger => @logger)
        end
    end

    def sizes(size=nil)
        if size.nil?
            @config[:sizes].to_array
        else
            if @config[:sizes].has_key? size
                @config[:sizes][size].to_hash
            else
                raise NCC::Error::NotFound, "No such size #{size.inspect}"
            end
        end
    end

    def images(image=nil)
        if image.nil?
            @config[:images].to_array
        else
            if @config[:images].has_key? image
                @config[:images][image].to_hash
            else
                raise NCC::Error::NotFound, "No such image #{image.inspect}"
            end
        end
    end

    def api_url
        if @config['services'].has_key? 'v2api'
            @config['services']['v2api']
        else
            'http://localhost/ncc_api/v2'
        end
    end

end

