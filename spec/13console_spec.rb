#!/usr/bin/env rspec
# -*- mode: ruby -*-

$LOAD_PATH.unshift 'test/lib'
require 'rubygems'
require 'ncc_spec_helper'
require 'noms/cmdb'
require 'ncc'

Fog.mock!
NOMS::CMDB.mock!

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

    describe "#console" do

        context "in AWS" do

            before :all do
                $instance_spec = NCC::Instance.new($ncc.config,
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
                @instance = $ncc.clouds('awscloud').create_instance($instance_spec)
            end

            it "should error out" do
                expect do
                    $ncc.clouds('awscloud').
                        console(@instance.id)
                end.to raise_error NCC::Error
            end

        end

        context "in OpenStack" do

            before :all do
                $instance_spec = NCC::Instance.new($ncc.config,
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
                $ncc.clouds('openstack0').fog.servers.each { |s| s.destroy }
                @instance = $ncc.clouds('openstack0').create_instance($instance_spec)
            end

            it "should return a console log novnc URL" do
                console_spec = $ncc.clouds('openstack0').console(@instance.id)
                expect(console_spec).to have_key 'url'
            end

        end

    end

end
