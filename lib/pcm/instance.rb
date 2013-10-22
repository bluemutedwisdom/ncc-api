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


class Hash

    def deep_soft_merge(other)
        r = self.dup
        other.each_pair do |key, value|
            if r.has_key? key
                if r[key].respond_to? :to_hash and
                        other[key].respond_to? :to_hash
                    r[key] =
                        r[key].to_hash.deep_soft_merge(other[key].to_hash)
                end
            else
                r[key] = value
            end
        end
        r
    end

    def delete_nil_values
        self.keys.each { |k| delete(k) if self[k].nil? }
        self
    end

end

class PCM

end

class PCM::Instance

    @@valid_statuses = %w(active build terminated error hard-reboot
                          reboot provider-operation shutting-down
                          suspending suspend unknown needs-verify)

    attr_accessor :name, :environment, :id, :ip_address, :host,
                  :console_log
    attr_reader :image, :size, :status

    # Should be mixed in
    def debug(msg=nil)
        msg ||= yield
        log 'debug', msg
    end

    def warn(msg)
        log 'warn', msg
    end

    def log(level, msg)
        @logger.send(level.intern, "#<#{me}>: #{msg}") if
            @logger.respond_to? level.intern
    end

    def initialize(cfg, opt={})
        @cfg = cfg
        @logger = opt[:logger] if opt.has_key? :logger
        self.id = opt['id']
        self.name = opt['name']
        self.size = opt['size']
        self.image = opt['image']
        self.environment = opt['environment']
        self.role = opt['role']
        self.host = opt['host']
        self.ip_address = opt['ip_address']
        self.console_log = opt['console_log']
        self.extra = opt['extra']
    end

    def with_defaults(*defaults)
        obj = self.dup
        defaults.each do |d|
            next if d.nil?
            obj.name ||= d['name']
            obj.size ||= d['size']
            obj.image ||= d['image']
            obj.environment ||= d['environment']
            obj.role ||= d['role']
            obj.extra = d['extra']
        end
        obj
    end

    def role
        @role
    end

    def role=(value)
        if value.nil?
            @role = []
        elsif value.respond_to? :join
            @role = value
        else
            @role = value.split(/, */)
        end
    end

    def set_without_validation(fields)
        fields.each_pair do |field, value|
            case field
            when :id
                @id = value
            when :name
                @name = value
            when :size
                @size = value
            when :image
                @image = value
            when :environment
                @environment = value
            when :role
                self.role = value
            when :extra
                @extra = value
            when :status
                self.status = value
            when :ip_address
                @ip_address = value
            when :host
                @host = value
            when :console_log
                @console_log = value
            else
                raise PCM::Error, "Invalid field #{field.inspect}"
            end
        end
    end

    def image=(newimage)
        raise PCM::Error, "Invalid image #{newimage.inspect}" unless
            newimage.nil? or @cfg[:images].has_key? newimage
        @image = newimage
    end

    def size=(newsize)
        raise PCM::Error, "Invalid size ${newsize.inspect}" unless
            newsize.nil? or @cfg[:sizes].has_key? newsize
        @size = newsize
    end

    def clear_extra
        @extra = nil
    end

    def extra(param=nil)
        if param.nil?
            @extra
        else
            if !@extra.nil? and @extra.has_key? param
                @extra[param]
            else
                { }
            end
        end
    end

    def extra=(newextra)
        if !newextra.nil?
            raise PCM::Error, "Invalid extra parameter of type " +
                "#{newextra.class} (must be Hash)" unless
                newextra.respond_to? :to_hash
            if @extra.nil?
                @extra = newextra.to_hash
            else
                @extra = @extra.deep_soft_merge(newextra.to_hash)
            end
        end
    end

    def status=(newstatus)
        raise PCM::Error, "Invalid status #{newstatus.inspect}" unless
            @@valid_statuses.include? newstatus
        @status = newstatus
    end

    def to_hash
        {
            'name' => name,
            'id' => id,
            'extra' => extra,
            'environment' => environment,
            'role' => role,
            'size' => size,
            'image' => image,
            'ip_address' => ip_address,
            'host' => host,
            'status' => status
        }.delete_nil_values
    end

    def to_json
        to_hash.to_json
    end

end
