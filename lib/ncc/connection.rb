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

require 'rubygems'
require 'fog'
require 'uuidtools'

class NCC

end

class NCC::Connection

    attr_reader :fog

    def self.connect(ncc, cloud=:default, opt={})
        cfg = ncc.config
        provider = cfg[:clouds][cloud]['provider']
        case provider
        when 'aws'
            require 'ncc/connection/aws'
            NCC::Connection::AWS.new(ncc, cloud, opt)
        when 'openstack'
            require 'ncc/connection/openstack'
            NCC::Connection::OpenStack.new(ncc, cloud, opt)
        end
    end

    def initialize(ncc, cloud, opt={})
        @ncc = ncc
        @cache = { }
        @cfg = ncc.config
        @cfg_mtime = @cfg[:clouds][cloud].mtime
        @cloud = cloud
        @logger = opt[:logger] if opt.has_key? :logger
        @cache_timeout = opt[:cache_timeout] || 600
        @auth_retry_limit = opt[:auth_retry_limit] || 1
        @create_timeout = opt[:create_timeout] || 160
        do_connect
    end

    def current?
        provider == @cfg[:clouds][@cloud]['provider'] and
            @cfg_mtime == @cfg[:clouds][@cloud].mtime
    end

    def maybe_invalidate(type)
        if @cache.has_key? type
            @cache.delete(type) if
                (Time.now - @cache[type][:timestamp]) > @cache_timeout
        end
    end

    def me
        [self.class, provider, @cloud].join(' ')
    end

    def to_s
        '#<' + me + '>'
    end

    def warn(msg)
        if @logger and @logger.respond_to? :warn
            @logger.warn "#{self} #{msg}"
        end
    end

    def debug(msg=nil)
        msg ||= yield if block_given?
        if @logger and @logger.respond_to? :debug
            @logger.debug "#{self} #{msg}"
        end
    end

    def notice(msg)
        if @logger and @logger.respond_to? :info
            @logger.info "#{self} #{msg}"
        end
    end

    def info(msg)
        if @logger and @logger.respond_to? :info
            @logger.info "#{self} #{msg}"
        end
    end

    def error(msg)
        if @logger and @logger.respond_to? :error
            @logger.error "#{self} #{msg}"
        end
    end

    def fatal(msg)
        if @logger and @logger.respond_to? :fatal
            @logger.error "#{self} #{msg}"
        end
    end

    def connection_params
        []
    end

    def do_connect
        info "Connecting to #{provider} cloud #{@cloud}"
        cloud_config = @cfg[:clouds][@cloud]
        pnames = connection_params + ['provider']
        params = Hash[cloud_config.to_hash(*pnames).map do |k, v|
                          [k.intern, v]
                      end ]
        @fog = Fog::Compute.new(params)
    end

    def do_fog
        remaining_tries = @auth_retry_limit
        begin
            unless @fog
                debug "do_fog: connecting because @fog is nil (@auth_retry_limit=#{@auth_retry_limit})"
                do_connect
            end
            debug "do_fog: beginning fog operation"
            yield @fog
        rescue Excon::Errors::Unauthorized => err
            # might be an expired auth token, retry
            if remaining_tries > 0
                do_connect
                remaining_tries -= 1
                retry
            else
                @fog = nil
                raise NCC::Error::Cloud, "Error communicating with #{provider} " +
                    "cloud #{@cloud} (#{e.class}): #{e.message}"
            end
        rescue NCC::Error::Cloud => err
            @fog = nil
            raise err
        rescue NCC::Error => err
            raise err
        rescue StandardError => err
            debug "Unknown error [#{err.class}]: #{err.message} #{err.backtrace.join("\n   ")}"
            @fog = nil
            raise NCC::Error::Cloud, "Error communicating with #{provider} " +
                "cloud #{@cloud} [#{err.class}]: #{err.message}"
        end
    end

    # Warning. use_only_mapped is ignored for types with
    # alternate id fields
    def use_only_mapped(type)
        false
    end

    def fields(obj, *flist)
        Hash[flist.map { |f| [f, obj.send(f)] }]
    end

    def ids(a)
        Hash[a.map { |e| [e['id'], e] }]
    end

    def provider
        generic
    end

    def keyname_for(type)
        case type
        when :size
            'sizes'
        when :image
            'images'
        end
    end

    # Something like "images" => { "$abstract_id" => x }
    # can have an x where it's the provider id, or an x
    # which is a hash. If the hash has an id key, than that
    # is used as a mapped id, if it doesn't, it's ignored
    # (for the purposes of id mapping) -jbrinkley/20130410
    def id_map_hash(h)
        Hash[
        h.map do |k, v|
                 if v.respond_to? :has_key?
                     if v.has_key? 'id'
                         [k, v['id']]
                     end
                 else
                     [k, v]
                 end
             end.reject { |p| p.nil? }
                           ]
    end

    def id_map(type)
        debug "making id_map for #{type.inspect}"
        keyname = keyname_for(type)
        r = { }
        debug "keyname = #{keyname} (for #{type.inspect})"
        debug "provider map: #{@cfg[:providers][provider].to_hash.inspect}"
        r.update(id_map_hash(@cfg[:providers][provider][keyname].to_hash)) if
            @cfg[:providers][provider].has_key? keyname
        #debug "cloud map: #{@cfg[:clouds][@cloud][keyname].to_hash}"
        r.update(id_map_hash(@cfg[:clouds][@cloud][keyname].to_hash)) if
            @cfg[:clouds][@cloud].has_key? keyname
        debug "  >> #{r.inspect}"
        r
    end

    def provider_id_map(type)
        debug "making provider_id_map for #{type.inspect}"
        keyname = keyname_for(type)
        r = { }
        r.update(id_map_hash(@cfg[:providers][provider][keyname].
                             to_hash).invert) if
            @cfg[:providers][provider].has_key? keyname
        r.update(id_map_hash(@cfg[:clouds][@cloud][keyname].
                             to_hash).invert) if
            @cfg[:clouds][@cloud].has_key? keyname
        debug "  >>> #{r.inspect}"
        r
    end

    def map_to_id(type, provider_id)
        debug "provider_id_map = #{provider_id_map(type).inspect}"
        provider_id_map(type)[provider_id] || provider_id
    end

    def map_to_provider_id(type, abstract_id)
        id_map(type)[abstract_id] || abstract_id
    end

    # raw meaning not using "our" notion of id_field
    def map_from_raw_provider_id(type, raw_provider_id)
        # Using collection here for cache
        provider_object = collection(type).find do |item|
            item.id == raw_provider_id
        end
        id_of(type, provider_object)
    end

    def map_to_status(provider_status)
        provider_status
    end

    def map_to_provider_status(abstract_status)
        abstract_status
    end

    def sizes(size_id=nil)
        debug "sizes(#{size_id.inspect})"
        if size_id.nil?
            collection(:size).find_all do |flavor|
                    @cfg[:sizes].has_key? id_of(:size, flavor)
                end.map { |f| object_of(:size, f) }
        else
            object_of(:size,
                   get_provider_object(:size => size_id))
        end
    end

    def images(image_id=nil)
        if image_id.nil?
            collection(:image).find_all do |provider_image|
                    @cfg[:images].has_key? id_of(:image, provider_image)
                end.map { |i| object_of(:image, i) }
        else
            object_of(:image,
                   get_provider_object(:image => image_id))
        end
    end

    def id_field(abstract_object_type)
        methodname = abstract_object_type.to_s + '_id_field'
        if self.respond_to? methodname
            self.send methodname
        else
            :id
        end
    end

    def id_of(abstract_object_type, obj)
        map_to_id(abstract_object_type,
               translated_id_of(abstract_object_type, obj))
    end

    def translated_id_of(abstract_object_type, obj)
        id_fielder = id_field abstract_object_type
        if id_fielder.kind_of? Proc
            id_fielder.call obj
        elsif obj.nil?
            nil
        else
            obj.send id_fielder
        end
    end

    def collection(type, key=nil)
        maybe_invalidate type
        @cache[type] ||= {
            :timestamp => Time.now,
            :data => Hash[get_provider_objects(type).map { |o| [o.id, o] }]
        }
        if key.nil?
            @cache[type][:data].values
        else
            @cache[type][:data][key]
        end
    end

    def get_provider_objects(type)
        enum = case type
               when :size
                   :flavors
               when :image
                   :images
               end
        if use_only_mapped(type) and id_field(type) == :id
            id_map(type).values.map do |id|
                do_fog { |fog| fog.send(enum).get(id) }
            end
        else
            do_fog { |fog| fog.send(enum).map { |e| e } }
        end
    end

    def get_provider_object(provider_object_spec)
        abstract_object_type, abstract_object_id = provider_object_spec.first
        if id_field(abstract_object_type) != :id
            collection(abstract_object_type).find do |provider_object|
                id_of(abstract_object_type, provider_object) ==
                    abstract_object_id
            end
        else
            provider_object_id = map_to_provider_id(abstract_object_type,
                                                 abstract_object_id)
            collection(abstract_object_type, provider_object_id)
        end
    end

    def translate(abstract_object_type, provider_object)
        debug "translate(#{abstract_object_type.inspect}, #{provider_object})"
        methodname = 'translate_' + abstract_object_type.to_s
        if self.respond_to? methodname
            self.send(methodname, provider_object)
        else
            generic_translate(abstract_object_type, provider_object)
        end
    end

    def merge_configured(abstract_object, data)
        if data.respond_to? :each_pair
            data.each_pair { |k, v| abstract_object[k] ||= v }
        else
            abstract_object['provider_id'] ||= data
        end
    end

    def object_of(abstract_object_type, provider_object)
        debug "object_of(#{abstract_object_type.inspect}, #{provider_object})"
        abstract_object = translate(abstract_object_type, provider_object)
        keyname = keyname_for abstract_object_type
        id = abstract_object['id']
        [@cfg[:clouds][@cloud], @cfg[:providers][provider]].each do |cfg|
            if cfg.has_key? keyname and cfg[keyname].has_key? id
                debug "merging cloud/provider data: cfg[#{keyname}][#{id}]"
                merge_configured(abstract_object, cfg[keyname][id])
            end
        end
        if @cfg.has_key? keyname.intern and @cfg[keyname.intern].has_key? id
            debug "merging abstract data: " +
                "@cfg[#{keyname.intern.inspect}][#{id}]"
            merge_configured(abstract_object, @cfg[keyname.intern][id].to_hash)
        end
        debug "object_of returns: #{abstract_object.inspect}"
        abstract_object
    end

    def generic_translate(abstract_object_type, provider_object)
        abstract_object =  {
            'id' => id_of(abstract_object_type, provider_object),
            'provider_id' => provider_object.id
        }
        [:name, :description].each do |field|
            abstract_object[field.to_s] = provider_object.send(field) if
                provider_object.respond_to? field
        end
        abstract_object
    end

    def instance_for(server)
        instance = NCC::Instance.new(@cfg, :logger => @logger)
        instance.set_without_validation(:id => server.id)
        instance.set_without_validation(:name => instance_name(server))
        instance.set_without_validation(:size => instance_size(server))
        instance.set_without_validation(:image => instance_image(server))
        instance.set_without_validation(:ip_address =>
                             instance_ip_address(server))
        instance.set_without_validation(:host => instance_host(server))
        instance.set_without_validation(:status => instance_status(server))
        instance
    end

    def instance_name(server)
        server.name
    end

    def instance_size(server)
        map_to_id(:size, server.size)
    end

    def instance_image(server)
        map_to_id(:image, server.image)
    end

    def instance_status(server)
        map_to_status(server.status)
    end

    def instance_host(server)
        nil
    end

    def instance_ip_address(server)
        server.ip_address.to_s
    end

    def instances(instance_id=nil)
        debug "instances(#{instance_id.inspect})"
        if instance_id.nil?
            do_fog { |fog| fog.servers.map { |server| instance_for server } }
        else
            server = do_fog { |fog| fog.servers.get instance_id }
            if server.nil?
                instance_not_found instance_id
            end
            instance_for server
        end
    end

    def provider_request(instance)
        keyintern(
        provider_request_of(instance.
                         with_defaults(@cfg[:clouds][@cloud]['defaults'],
                              @cfg[:providers][provider]['defaults']))
        )
    end

    def provider_request_of(instance)
        generic_provider_request(instance)
    end

    def generic_provider_request(instance)
        {
            :name => instance.name,
            :flavor => map_to_provider_id(:size, instance.size),
            :size => map_to_provider_id(:image, instance.image),
        }.merge(instance.extra provider)
    end

    def keyintern(h)
        Hash[h.map do |k, v|
                 [k.to_sym,
                     ((v.is_a? Hash and (k.to_sym != :tags)) ?
                         keyintern(v) : v)]
             end]
    end

    def inventory_request(instance)
        i = instance.with_defaults(@cfg[:clouds][@cloud]['defaults'],
                          @cfg[:providers][provider]['defaults'])
        {
            'fqdn' => i.name,
            'size' => i.size,
            'image' => i.image,
            'serial_number' => i.id,
            'uuid' => i.id,
            'roles' => i.role.sort.join(','),
            'ipaddress' => i.ip_address,
            'host_fqdn' => host_fqdn(i.host),
            'environment_name' => i.environment
        }.merge(instance.extra 'inventory')
    end

    def host_fqdn(host)
        if @cfg[:clouds][@cloud].has_key? 'host_domain'
            host + '.' + @cfg[:clouds][@cloud]['host_domain']
        else
            host
        end
    end

    def modify_instance_request(instance)
        instance
    end

    def create_instance(instance_spec, wait_for_ip=nil)
        wait_for_ip ||= @create_timeout

        if ! instance_spec.kind_of? NCC::Instance
            instance_spec = NCC::Instance.new(@cfg, instance_spec)
        end
        req_id = ['ncc',
            @cloud,
            UUIDTools::UUID.random_create.to_s].join('-')
        begin
            info "#{@cloud} requesting name from inventory using #{req_id}"
            fqdn = @ncc.inventory.get_or_assign_system_name(req_id)['fqdn']
        rescue StandardError => e
            raise NCC::Error::Cloud, "Error [#{e.class}] " +
                "communicating with inventory to " +
                "assign name using (ncc_req_id=#{req_id}): #{e.message}"
        end
        instance_spec.name = fqdn
        begin
            req = provider_request(instance_spec)
            t0 = Time.now
            info "#{@cloud} sending request: #{req.inspect}"
            server = do_fog { |fog| fog.servers.create(req) }
            # The reason we wait for an IP is so we can add it to
            # inventory, which then calculates the datacenter
            if wait_for_ip > 0 and instance_ip_address(server).nil?
                info "#{@cloud} waiting for ip on #{server.id}"
                this = self
                server.wait_for(wait_for_ip) { ready? and this.instance_ip_address(server)  }
            end
        rescue StandardError => err
            debug "Error [#{err.class}]: #{err.message} #{err.backtrace.join("\n   ")}"
            inv_update = { 'fqdn' => fqdn, 'status' => 'decommissioned' }
            if ! server.nil? and server.id
                inv_update['uuid'] = server.id
                inv_update['serial_number'] = server.id
            end
            @ncc.inventory.update('system', inv_update, fqdn)
            server_id = (server.nil? ? 'nil' : server.id)
            communication_error "[#{err.class}] (ncc_req_id=#{req_id} " +
                "instance_id=#{server_id}): #{err.message}"
        end
        elapsed = Time.now - t0
        info "Created instance instance_id=#{server.id} at #{provider} cloud #{@cloud} in #{elapsed}s"
        instance = instance_for server
        instance_spec.id = instance.id
        instance_spec.ip_address = instance.ip_address
        instance_spec.host = instance.host
        inv_req = inventory_request(instance_spec)
        inv_req['cloud'] = @cloud
        inv_req['status'] = 'building'
        begin
            info "#{@cloud} updating inventory #{fqdn}/#{req_id} -> #{inv_req.inspect}"
            @ncc.inventory.update('system', inv_req, fqdn)
        rescue StandardError => e
            raise NCC::Error::Cloud, "Error [#{e.class}] updating inventory " +
                "system #{fqdn} " +
                "(cloud=#{@cloud} ncc_req_id=#{req_id} " +
                "instance_id=#{server.id}): " + e.message
        end
        instance
    end

    def instance_not_found(instance_id)
        raise NCC::Error::NotFound, "Instance #{instance_id.inspect} not " +
            "found in #{provider} cloud #{@cloud}"
    end

    def communication_error(message)
        raise NCC::Error::Cloud,
        "Error communicating with #{provider} cloud #{@cloud}: " + message unless
            /Error .*communicating with/.match(message)
    end

    def delete(instance_id)
        server = do_fog { |fog| fog.servers.get(instance_id) }
        if server.nil?
            instance_not_found instance_id
        else
            begin
                instance = instance_for server
                server.destroy
                inv_update = { 'fqdn' => instance.name,
                    'status' => 'decommissioned' }
                @ncc.inventory.update('system', inv_update, instance.name)
            rescue StandardError => e
                communication_error "deleting fqdn=#{instance.name} " +
                    "instance_id=#{server.id}: #{e.message}"
            end
        end
    end

    def console_log(instance_id)
        raise NCC::Error::NotFound, "Cloud #{@cloud} provider " +
            "#{provider} does not support console logs"
    end

    def console(instance_id)
        raise NCC::Error::NotFound, "Cloud #{@cloud} provider " +
            "#{provider} does not support interactive console"
    end

    def reboot(instance_id)
        server = do_fog { |fog| fog.servers.get(instance_id) }
        if server.nil?
            instance_not_found instance_id
        else
            server.reboot
        end
    end

end
