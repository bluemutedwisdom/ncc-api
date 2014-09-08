#!/usr/bin/env rspec
# -*- mode: ruby -*-

$LOAD_PATH.unshift 'test/lib'
require 'ncc_spec_helper'
require 'ncc'

Fog.mock!

$ncc_from_aws = {
    'running' => 'active',
    'pending' => 'build',
    'terminated' => 'terminated',
    'shutting-down' => 'shutting-down',
    'stopping' => 'suspending',
    'stopped' => 'suspend'
}
$aws_from_ncc = {
    'active' => 'running',
    'build' => 'pending',
    'terminated' => 'terminated',
    'error' => 'running',
    'hard-reboot' => 'running',
    'reboot' => 'running',
    'provider-operation' => 'running',
    'shutting-down' => 'shutting-down',
    'suspending' => 'stopping',
    'suspend' => 'stopped',
    'unknown' => 'running',
    'needs-verify' => 'running'
}
$ncc_from_os = {
    'ACTIVE' => 'active',
    'BUILD' => 'build',
    'DELETED' => 'terminated',
    'ERROR' => 'error',
    'HARD_REBOOT' => 'hard-reboot',
    'PASSWORD' => 'active',
    'REBOOT' => 'reboot',
    'REBUILD' => 'provider-operation',
    'RESCUE' => 'provider-operation',
    'RESIZE' => 'provider-operation',
    'REVERT_RESIZE' => 'provider-operation',
    'SHUTOFF' => 'active',
    'SUSPENDED' => 'suspend',
    'UNKNOWN' => 'unknown',
    'VERIFY_RESIZE' => 'needs-verify'
}
$os_from_ncc = {
    'active' => 'ACTIVE',
    'build' => 'BUILD',
    'terminated' => 'DELETED',
    'error' => 'ERROR',
    'hard-reboot' => 'HARD_REBOOT',
    'reboot' => 'REBOOT',
    'provider-operation' => 'ACTIVE',
    'shutting-down' => 'ACTIVE',
    'suspending' => 'ACTIVE',
    'suspend' => 'SUSPENDED',
    'unknown' => 'UNKNOWN',
    'needs-verify' => 'VERIFY_RESIZE'
}

describe "NCC::Connection" do

    before(:all) { setup_fixture }
    after(:all) { cleanup_fixture}

    before :all do
        $ncc = NCC.new('test/data/etc')
        $aws = $ncc.clouds('awscloud')
        $os  = $ncc.clouds('openstack0')
    end

    describe "#map_to_status" do

        context "in AWS" do
            $ncc_from_aws.each_pair do |aws_status, ncc_status|
                specify { $aws.map_to_status(aws_status).should == ncc_status }
            end
            specify { $aws.map_to_status('nonsense').should == 'unknown' }

        end

        context "in OpenStack" do
            $ncc_from_os.each_pair do |os_status, ncc_status|
                specify { $os.map_to_status(os_status).should == ncc_status }
            end
            specify { $os.map_to_status('nonsense').should == 'unknown' }
        end

    end

    describe "#map_to_provider_status" do

        context "in AWS" do
            $aws_from_ncc.each_pair do |ncc_status, aws_status|
                specify do
                    $aws.map_to_provider_status(ncc_status).
                        should == aws_status
                end
            end
            specify do
                $aws.map_to_provider_status('nonsense').should == 'running'
            end
        end

        context "in OpenStack" do
            $os_from_ncc.each_pair do |ncc_status, os_status|
                specify do
                    $os.map_to_provider_status(ncc_status).
                        should == os_status
                end
            end
        end
        specify do
            $os.map_to_provider_status('nonsense').should == 'UNKNOWN'
        end

    end

end
