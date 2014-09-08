#!/usr/bin/env rspec
# -*- mode: ruby -*-

$LOAD_PATH.unshift 'test/lib'
require 'ncc_spec_helper'
require 'rubygems'
require 'ncc'
require 'fog'

Fog.mock!

describe NCC::Connection do

    before :all do
        setup_fixture
        $ncc = NCC.new('test/data/etc')
        $cfg = $ncc.config
        $ncc.clouds('awscloud').fog.
            register_image('testimg', 'testimg', '/dev/sda0')
        aws_image_id = $ncc.clouds('awscloud').fog.images.first.id
        $ncc.config[:clouds]['awscloud']['images'] = {
            'centos5.6' => aws_image_id
        }
    end

    after(:all) { cleanup_fixture }

    describe ".connect" do

        before :each do
            $os = NCC::Connection.connect($ncc, 'openstack0')
            $aws = NCC::Connection.connect($ncc, 'awscloud')
        end

        context "accessing AWS" do
            specify { $aws.should be_a NCC::Connection }
            specify { $aws.should be_a NCC::Connection::AWS }
            specify { $aws.fog.service.should be Fog::Compute::AWS }
        end

        context "accessing OpenStack" do
            specify { $os.should be_a NCC::Connection::OpenStack }
            specify { $os.fog.service.should be Fog::Compute::OpenStack }
        end
    end

end
