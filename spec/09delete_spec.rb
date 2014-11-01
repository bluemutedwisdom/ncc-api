#!/usr/bin/env rspec
# -*- mode: ruby -*-

$LOAD_PATH.unshift 'test/lib'
require 'rubygems'
require 'ncc_spec_helper'
require 'ncc'
require 'noms/cmdb'

Fog.mock!
NOMS::CMDB.mock!

describe NCC::Connection do

    before(:all) { setup_fixture }
    after(:all) { cleanup_fixture }

    before :all do
        $logger = LogCatcher.new
        $ncc = NCC.new('test/data/etc', :logger => $logger)
        $aws = $ncc.clouds('awscloud')
        $aws.fog.register_image('testimg', 'testimg', '/dev/sda0')
        image_id = $aws.fog.images.first.id
        $ncc.config[:clouds]['awscloud']['images'] =
            { 'centos5.6' => image_id }
    end

    context "in AWS" do

        before :each do
            $instance = $aws.
                create_instance(
                       { 'size' => 'm1.medium', 'image' => 'centos5.6' })
        end

        describe "#delete" do
            it "destroys an instance" do
                $aws.instances.should have(1).item
                $aws.instances.first.id.should == $instance.id
                $aws.delete($instance.id)
                server = $aws.fog.servers.get($instance.id)
                server.wait_for(5) { ['terminating',
                        'terminated'].include? server.state }
                $aws.instances.should have(0).items
            end

            it "updates inventory" do
                system0 = inv_get($ncc.inventory, $instance.name)
                system0['status'].should_not == 'decommissioned'
                $aws.delete($instance.id)
                system1 = $ncc.inventory.query('system',
                                         'fqdn=' + $instance.name).first
                system1['status'].should == 'decommissioned'
            end

            it "raises an error for a nonexistent instance" do
                expect { $aws.delete('i-deadbeef') }.
                    to raise_error NCC::Error, /not found/
            end
        end

    end

end
