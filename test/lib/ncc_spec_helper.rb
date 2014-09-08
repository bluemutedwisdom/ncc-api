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

def trim(s, c='/', dir=:both)
    case dir
    when :both
        trim(trim(s, c, :right), c, :left)
    when :right
        s.sub(Regexp.new(c + '+/'), '')
    when :left
        s.sub(Regexp.new('^' + c + '+'), '')
    end
end

def ltrim(s, c='/')
    trim(s, c, :left)
end

def rtrim(s, c='/')
    trim(s, c, :right)
end

def do_request(opt)
    method = [:GET, :PUT, :POST, :DELETE].find do |m|
        opt.has_key? m
    end
    method ||= :GET
    rel_uri = opt[method]
    url = URI.parse($nccapi_url)
    url.path = rtrim(url.path) + '/' + ltrim(rel_uri)
    url.query = opt[:query] if opt.has_key? :query
    http = Net::HTTP.new(url.host, url.port)
    reqclass = case method
               when :GET
                   Net::HTTP::Get
               when :PUT
                   Net::HTTP::Put
               when :POST
                   Net::HTTP::Post
               when :DELETE
                   Net::HTTP::Delete
               end
    request = reqclass.new(url.request_uri)
    if opt.has_key? :username
        request.basic_auth(opt[:username], opt[:password])
    end
    request.body = opt[:body].to_json if opt.has_key? :body
    response = http.request(request)
    RestResponse.new(response)
end

def get(url)
    do_request :GET => url
end

def post(url, data)
    do_request :POST => url, :body => data
end

def put(url, data)
    do_request :PUT => url, :body => data
end

def delete(url)
    do_request :DELETE => url
end
