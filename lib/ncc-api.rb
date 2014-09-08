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
require 'ncc'
require 'json'
require 'sinatra'
require 'fog'
require 'rack/logger'


configure :development do
    set :logging, Logger::DEBUG
end

$ncc = NCC.new

def error_message(status, err)
    status_message = case status
                     when 400
                         "400 Bad Request"
                     when 404
                         "404 Not Found"
                     when 500
                         "500 Internal Server Error"
                     when 503
                         "503 Service Unavailable"
                     end
    status_message ||= status.to_s
    data = { "status" => status_message, "message" => err.message }
    if params.has_key? 'details'
        data['details'] = err.backtrace
        data['error'] = err.class
    end
    body = (params.has_key?('pretty') ? (JSON.pretty_generate(data) +
            "\n") : data.to_json)
    [status, { "content-type" => "application/json" }, body]
end

def respond(status, header={}, &block)
    header.merge({ "content-type" => "application/json" })
    begin
        obj = yield
        body = if header["content-type"] == "text/plain"
                   obj
               else
                   params.has_key?('pretty') ? (JSON.pretty_generate(obj) + "\n") : obj.to_json
               end
        return [status, header, body]
    rescue NCC::Error::NotFound => error
        halt error_message(404, error)
    rescue NCC::Error::Cloud => error
        halt error_message(503, error)
    rescue NCC::Error::Client => error
        halt error_message(400, error)
    rescue Exception => error
        halt error_message(500, error)
    end
end

get '/ncc_api' do
    respond 200 do
        $ncc.config['services'].to_hash.merge({ 'v2api' => $ncc.api_url })
    end
end

get '/ncc_api/v2' do
    respond 200 do
        {
            "clouds" => "/ncc_api/v2/clouds",
            "images" => "/ncc_api/v2/images",
            "sizes" => "/ncc_api/v2/sizes",
        }
    end
end

get '/ncc_api/v2/clouds' do
    respond(200) { $ncc.clouds }
end

get '/ncc_api/v2/sizes' do
    respond(200) { $ncc.sizes }
end

get '/ncc_api/v2/images' do
    respond(200) { $ncc.images }
end

get '/ncc_api/v2/sizes/:size_id' do |size_id|
    respond(200) { $ncc.sizes(size_id) }
end

get '/ncc_api/v2/images/:image_id' do |image_id|
    respond(200) { $ncc.images(image_id) }
end

get '/ncc_api/v2/clouds/:cloud' do |cloud|
    respond 200 do
        {
            'name' => cloud,
            'status' => 'ok',
            'provider' => $ncc.clouds(cloud).provider,
            'service' => $ncc.clouds(cloud).fog.class.to_s
        }
    end
end

get '/ncc_api/v2/clouds/:cloud/sizes' do |cloud|
    respond(200) { $ncc.clouds(cloud).sizes }
end

get '/ncc_api/v2/clouds/:cloud/sizes/:size_id' do |cloud, size_id|
    respond(200) { $ncc.clouds(cloud).sizes(size_id) }
end

get '/ncc_api/v2/clouds/:cloud/images' do |cloud|
    respond(200) { $ncc.clouds(cloud).images }
end

get '/ncc_api/v2/clouds/:cloud/images/:image_id' do |cloud, image_id|
    respond(200) { $ncc.clouds(cloud).images(image_id) }
end

get '/ncc_api/v2/clouds/:cloud/instances' do |cloud|
    respond(200) { $ncc.clouds(cloud).instances.map { |i| i.to_hash } }
end


get '/ncc_api/v2/clouds/:cloud/instances/:instance_id/console_log' do |cloud,
    instance_id|
    respond(200, 'content-type' => 'text/plain') do
        # TODO influence last-modified with console log timestamp
        $ncc.clouds(cloud).console_log(instance_id)['output']
    end
end

post '/ncc_api/v2/clouds/:cloud/instances' do |cloud|
    respond 201 do
        begin
            request.body.rewind
            instance_spec = JSON.parse(request.body.read)
            instance_req = instance_spec
            $ncc.clouds(cloud).create_instance(instance_req)
        rescue JSON::ParserError => e
            raise NCC::Error::Client, "Error parsing request: #{e.message}"
        end
    end
end

get '/ncc_api/v2/clouds/:cloud/instances/:instance_id' do |cloud, instance_id|
    respond(200) do
        $ncc.clouds(cloud).instances(instance_id).to_hash
    end
end


delete '/ncc_api/v2/clouds/:cloud/instances/:instance_id' do |cloud,
    instance_id|
    respond 204 do
        $ncc.clouds(cloud).delete(instance_id)
        nil
    end
end

put '/ncc_api/v2/clouds/:cloud/instances/:instance_id' do |cloud, instance_id|
    respond 202 do
        instance = $ncc.clouds(cloud).instances(instance_id)
        begin
            request.body.rewind
            update_spec = JSON.parse(request.body.read)
        rescue JSON::ParserError => e
            raise NCC::Error::Client, "Error parsing request #{e.message}"
        end
        actions = []
        update_spec.each_pair do |key, value|
            case key
            when 'status'
                if value == 'reboot'
                    actions << lambda { instance.status = 'reboot' }
                    $ncc.clouds(cloud).reboot(instance.id)
                else
                    raise NCC::Error::Client,
                    "Cannot update to status #{value.inspect}"
                end
            else
                raise NCC::Error::Client,
                "Cannot update field #{key.inspect}"
            end
        end
        actions.each { |action| action.call }
        instance
    end
end

# This is not doing the right thing, it's overwriting
# the body when it gets invoked after a normal route
# not_found do
#     respond(404) do
#         {
#             "status" => "404 Not Found",
#             "message" => "Not a supported resource type"
#         }
#     end
# end
