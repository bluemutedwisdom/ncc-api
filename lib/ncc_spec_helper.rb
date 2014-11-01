#!/usr/bin/env rspec
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

# -*- mode: ruby -*-

require 'rubygems'
require 'fileutils'
require 'pp'
require 'net/http'
require 'json'

require 'rspec/collection_matchers'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
end

def set_testvalue(s, k='test', subkey='testkey')
    File.open("test/data/etc/#{k}.conf", 'w') do |fh|
        fh << "{ \"#{subkey}\": \"#{s}\" }\n"
    end
end

def cleanup_fixture
    FileUtils.rm_r 'test/data' if File.directory? 'test/data'
end

def setup_fixture
    cleanup_fixture
    FileUtils.cp_r('test/fixture', 'test/data')
end

def inv_get(inv, fqdn)
    # NOMS::CMDB mocking doesn't mock query searching
    # inv.query('system', 'fqdn=' + fqdn).first
    inv.do_request(:GET => "system/#{fqdn}")
end

class LogCatcher < Hash

    def initialize(opts={})
        showdebug = opts[:showdebug] if opts.has_key? :showdebug
        @show = { }
    end

    def showdebug=(val)
        show('debug', val)
    end

    def show(level, pattern=true)
        if level.kind_of? Array
            level.each { |l| show(l, pattern) }
        else
            @show[level] = pattern
        end
    end

    def shouldshow(level, msg)
        pattern = @show[level]
        if pattern
            if pattern.respond_to? :match
                pattern.match msg
            elsif pattern.respond_to? :include
                pattern.include? msg
            else
                pattern
            end
        end
    end

    def log(level, msg, store=true)
        ts = Time.now.strftime('%Y-%m-%dT%H:%M:%S')
        text = "[#{ts}] #{level}: #{msg}"
        puts text if shouldshow(level, msg)
        if store
            self[level] = [] unless self.has_key? level
            self[level] << text
        end
    end

    def warn(msg)
        log('warn', msg)
    end

    def debug(msg)
        log('debug', msg, false)
    end

    def notice(msg)
        log('notice', msg)
    end

    def info(msg)
        log('info', msg)
    end

end

class RestResponse
    attr_accessor :data, :status, :http_response

    def initialize(httpr)
        @http_response = httpr
        @status = httpr.code.to_i
        if httpr.body
            @data = JSON.parse(httpr.body)
        end
    end

end
