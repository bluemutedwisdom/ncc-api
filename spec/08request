#!/usr/bin/env rspec
# -*- mode: ruby -*-

$LOAD_PATH.unshift 'test/lib'
require 'rubygems'
require 'ncc_spec_helper'
require 'noms/cmdb'
require 'ncc'

Fog.mock!
NOMS::CMDB.mock!

def next_name(inv)
    highest = inv.query('system').map { |s| s['fqdn'] }.sort.last
    m = /([^\.]+)\.(.*)/.match highest
    m[1].succ + '.' + m[2]
end

def inv_get(inv, fqdn)
    inv.query('system', 'fqdn=' + fqdn).first
end

describe NCC do

    before(:all) { setup_fixture }
    after(:all) { cleanup_fixture }

    before :all do
        $ncc = NCC.new('test/data/etc')
    end

    describe "#inventory" do

        it "returns a NOMS::CMDB object" do
            $ncc.inventory.should be_a NOMS::CMDB
        end

    end

end

describe NCC::Instance do

    before(:all) { setup_fixture }
    after(:all) { cleanup_fixture }

    before :all do
        $logger = LogCatcher.new
        $ncc = NCC.new('test/data/etc', :logger => $logger)
        $ncc.clouds('awscloud').fog.
            register_image('testimg', 'testimg', '/dev/sda')
        image_id = $ncc.clouds('awscloud').fog.images.first
        $ncc.config[:clouds]['awscloud']['images'] = { 'centos5.6' => image_id }
    end

    describe "#to_hash" do
        before :all do
            $instance = NCC::Instance.new($ncc.config, {
                                              'id' => 'i-deadbeef',
                                              'name' => 'test-server-0',
                                              'size' => 'm1.medium',
                                              'image' => 'centos5.6' })
        end

        specify { $instance.to_hash.should be_a Hash }
        specify { $instance.to_hash['id'].should == 'i-deadbeef' }
        specify { $instance.to_hash['name'].should == 'test-server-0' }
        specify { $instance.to_hash['size'].should == 'm1.medium' }
        specify { $instance.to_hash['image'].should == 'centos5.6' }
    end

end

describe NCC::Connection do

    before(:all) { setup_fixture }
    after(:all) { cleanup_fixture }

    before :all do
        $logger = LogCatcher.new
        $ncc = NCC.new('test/data/etc', :logger => $logger)
        $ncc.clouds('awscloud').fog.
            register_image('testimg', 'testimg', '/dev/sda')
        $aws_image_id = $ncc.clouds('awscloud').fog.images.first.id
        $ncc.config[:clouds]['awscloud']['images'] = {
            'centos5.6' => $aws_image_id }
    end

    describe "#provider_request" do

        before :each do
            $instance = NCC::Instance.new($ncc.config,
                                      'name' => 'test-server-0',
                                      'size' => 'm1.medium',
                                      'extra' => {
                                              'aws' => {
                                                  'availability_zone' =>
                                                  'us-east-1a' } },
                                      'image' => 'centos5.6')
        end

        context "in AWS" do

            before :each do
                $request = $ncc.clouds('awscloud').provider_request($instance)
            end

            it "produces provider-specific fields" do
                $request[:name].should == 'test-server-0'
                $request[:tags]['Name'].should == 'test-server-0'
                $request[:flavor_id].should == 'm1.medium'
                $request[:image_id].should == $aws_image_id
            end

            it "selects extra parameters" do
                $request[:availability_zone].should == 'us-east-1a'
            end

            it "merges in cloud configuration" do
                $ncc.config[:clouds]['awscloud']['defaults'] =
                    { 'extra' => { 'aws' => { 'subnet_id' => 'subnet-123' } }
                }
                request = $ncc.clouds('awscloud').provider_request($instance)
                request[:subnet_id].should == 'subnet-123'
            end

            it "merges in provider configuration" do
                $ncc.config[:clouds]['awscloud'].delete('defaults')
                $ncc.config[:providers]['aws']['defaults'] =
                    { 'extra' => { 'aws' => { 'subnet_id' => 'subnet-345' } }
                }
                request = $ncc.clouds('awscloud').provider_request($instance)
                request[:subnet_id].should == 'subnet-345'
            end

        end

        context "in OpenStack" do

            before :each do
                $request = $ncc.clouds('openstack0').provider_request($instance)
                $os_image_id = $ncc.clouds('openstack0').fog.images.first.id
            end

            it "produces provider-specific fields" do
                $request[:name].should == 'test-server-0'
                $request[:flavor_ref].should == '5'
                $request[:image_ref].should == $os_image_id
            end

            it "merges in extra" do
                $instance.extra = { 'openstack' => {
                        'os_scheduler_hints' => { 'same_host' =>
                            ['deadbeef'] } } }
                request =
                    $ncc.clouds('openstack0').provider_request($instance)
                request[:os_scheduler_hints].should == {
                    :same_host => ['deadbeef'] }
            end

        end

    end

    # Inventory should be something similar to a cloud provider
    # And these names should probably be CMDB something
    # And it should be part of an integration hook chain
    # that could include event posting, &c. -jbrinkley/20130412
    describe "#inventory_request" do
        before :each do
            $instance = NCC::Instance.new($ncc.config,
                                      'id' => 'i-deadbeef',
                                      'name' => 'test-server-0',
                                      'size' => 'm1.medium',
                                      'environment' => 'lab',
                                      'role' => ['ncc-api-v2::role',
                                              'core::build'],
                                      'host' => 'm0002299',
                                      'ip_address' => '10.0.0.2',
                                      'extra' => {
                                              'inventory' => {
                                                  'created_by' => 'user0'
                                              },
                                              'aws' => {
                                                  'availability_zone' =>
                                                  'us-east-1a' } },
                                      'image' => 'centos5.6')
        end

        it "returns a system hash" do
            $ncc.config[:clouds]['awscloud']['defaults'] =
                { 'image' => 'centos5.6' }
            system = $ncc.clouds('awscloud').inventory_request($instance)
            system['fqdn'].should == 'test-server-0'
            system['serial_number'].should == 'i-deadbeef'
            system['environment_name'].should == 'lab'
            system['roles'].should == 'core::build,ncc-api-v2::role'
            system['image'].should == 'centos5.6'
            system['size'].should == 'm1.medium'
            system['created_by'].should == 'user0'
            system['ip_address'].should == '10.0.0.2'
            system['host_fqdn'].should == 'm0002299'
        end

    end

    describe "#create_instance" do

        context "in AWS" do

            before :all do
                $instance = NCC::Instance.new($ncc.config,
                                          'size' => 'm1.medium',
                                          'environment' => 'lab',
                                          'role' => 'ncc-api-v2::role',
                                          'extra' => {
                                                  'inventory' => {
                                                      'created_by' => 'user0'
                                                  }
                                              },
                                          'image' => 'centos5.6')
            end

            before :each do
                $ncc.clouds('awscloud').fog.servers.each { |s| s.destroy }
            end

            it "should create an instance" do
                instance = $ncc.clouds('awscloud').create_instance($instance)
                server = $ncc.clouds('awscloud').fog.servers.first
                instance.id.should == server.id
                instance.name.should == server.tags['Name']
                instance.size.should == 'm1.medium'
                instance.image.should == 'centos5.6'
                instance.role.should be_empty
                instance.environment.should be_nil
                instance.extra.should be_nil
                instance.status.should == 'active'
                instance.ip_address.should_not be_nil
                instance.ip_address.should == server.private_ip_address
                server.flavor_id.should == 'm1.medium'
                server.image_id.should == $aws_image_id
                server.state.should == 'running'
            end

            it "should update inventory" do
                target_fqdn = next_name($ncc.inventory)
                instance = $ncc.clouds('awscloud').create_instance($instance)
                instance.name.should == target_fqdn
                system = inv_get($ncc.inventory, target_fqdn)
                system['status'].should == 'building'
                system['cloud'].should == 'awscloud'
                system['environment_name'].should == 'lab'
                system['roles'].should == 'ncc-api-v2::role'
                system['image'].should == 'centos5.6'
                system['size'].should == 'm1.medium'
                system['serial_number'].should == instance.id
                system['ip_address'].should == instance.ip_address
            end

            it "should update inventory upon error" do
                target_fqdn = next_name($ncc.inventory)
                expect do
                    instance = $ncc.clouds('awscloud').
                        create_instance({ 'status' => 'nonexistent' })
                end.to raise_error NCC::Error
                system = $ncc.inventory.query('system',
                                        'fqdn=' + target_fqdn).first
                system['status'].should == 'decommissioned'
            end

        end

        context "in OpenStack" do
            # Server creation does not work in OpenStack mocks

        end

    end

    describe "#reboot_instance" do

        context "in AWS" do

        end

        context "in OpenStack" do

        end

    end

    describe "#instance_console_log" do

        context "in AWS" do

        end

        context "in OpenStack" do

        end

    end

end
