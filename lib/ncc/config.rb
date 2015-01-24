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
require 'json'

class NCC

end

class NCC::Config
    include Enumerable

    Infinite = +1.0/0.0     # Not really *math*, per se, but Lewis
                            # Carroll would have liked it
                            # -jbrinkley/20130403

    attr_reader :mtime, :file

    def initialize(source = ["/etc/ncc-api",
                       "#{ENV['NCCAPI_HOME']}/etc"], opt={})
        @opt = opt
        @file = { }
        @mtime = nil
	source = [source] unless source.respond_to? :select
        @file = source.select { |f| File.exist? f }.first
        unless @file
            raise ArgumentError.new("Can't locate configuration in " +
                                "#{source.inspect}")
        end
        debug "Creating configuration from #{@file}"
        update_config
    end

    def opt(optname)
        if @opt.has_key? optname
            @opt[optname]
        else
            nil
        end
    end

    def update_config(tolerant=false)
        debug "updating config"
        if File.directory? @file
            debug "#{@file} is a directory"
            @data ||= { }
            data = { }
            Dir.open(@file) do |dirh|
                @mtime = File.stat(@file).mtime
                debug "storing mtime: #{@mtime}"
                dirh.each do |entry|
                    debug "considering #{entry}"
                    next if entry[0] == "."[0]
                    if File.directory? File.join(@file, entry) or
                            m = /(.*)\.conf$/.match(entry)
                        debug "#{entry} is further configuration"
                        key = m.nil? ? entry.intern : m[1]
                        if @data.has_key? key
                            data[key] = @data[key]
                        else
                            data[key] =
                                NCC::Config.new(File.join(@file, entry),
                                            @opt)
                        end
                    end
                end
            end
            @data = data
        else
            debug "#{@file} is not a directory"
            begin
                File.open(@file, 'r') do |fh|
                    @mtime = fh.stat.mtime
                    @data = JSON.load(fh)
                end
            rescue Errno::ENOENT
                @mtime = Time.now
                @data = { }
            rescue JSON::ParserError => err
                do_warn "Error parsing JSON in #{@file}, not updating config"
            end
        end
    end

    def do_warn(msg)
        if opt :logger
            opt(:logger).warn msg
        end
    end

    def debug(msg)
        # This produces a *lot* of debug logging, thus it's best to be
        # able to use something else to control its log level.
        if ENV.has_key? 'NCC_CONFIG_DEBUG' and not ENV['NCC_CONFIG_DEBUG'].empty?
            if opt(:logger) and opt(:logger).respond_to? :debug
                opt(:logger).debug "#<#{me}>: #{msg}"
            end
        end
    end

    def me
        "#{self.class}:#{@file}"
    end

    def to_s
        "#<#{me} #{@data.inspect}>"
    end

    def to_hash(*keys)
        update_config unless current?
        if keys.length > 0
            Hash[
            @data.select do |k, v|
                     keys.include? k
                 end.map { |k, v| [k, value_of(v)] }
                                ]
        else
            Hash[
            @data.map { |k, v| [k, value_of(v)] }
                                  ]
        end
    end

    def to_array(*keys)
        update_config unless current?
        if keys.length > 0
            @data.select do |k, v|
                     keys.include? k
                 end.map { |k, v| value_of(v) }
        else
            @data.map { |k, v| value_of(v) }
        end
    end

    def value_of(v)
        if v.respond_to? :to_hash
            v.to_hash
        else
            v
        end
    end

    def to_json
        self.to_hash.to_json
    end

    def current?
        debug "checking currency (mtime=#{@mtime} " +
            "file=#{File.exist?(@file) ? File.stat(@file).mtime : nil})"
        case opt :staleness_threshold
        when 0, nil
            debug "staleness_threshold is 0 or nil, always checking"
            File.exist? @file and @mtime >= File.stat(@file).mtime
        when Infinite
            true
        else
            Time.now <= (@mtime + opt(:staleness_threshold)) or
                (File.exist? @file and @mtime >= File.stat(@file).mtime)
        end
    end

    def [](key)
        update_config unless current?
        @data[key]
    end

    def []=(key, value)
        update_config unless current?
        @mtime = Time.now
        @data[key] = value
    end

    def has_key?(key)
        update_config unless current?
        @data.has_key? key
    end

    def keys
        update_config unless current?
        @data.keys
    end

    def each
        update_config unless current?
        @data.each do |k, v|
            yield k, v
        end
    end

    def delete(k)
        update_config unless current?
        @data.delete(k)
    end

end
