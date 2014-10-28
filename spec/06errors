#!/usr/bin/env rspec
# -*- mode: ruby -*-

$LOAD_PATH.unshift 'test/lib'
require 'ncc_spec_helper'
require 'ncc'
require 'noms/cmdb'

Fog.mock!
NOMS::CMDB.mock!

describe "NCC::Error" do

    describe ".new" do

        subject { NCC::Error.new("error message") }
        it { should be_a StandardError }
        it { should be_a NCC::Error }

    end

end

describe "NCC" do

    before :all do
        setup_fixture
        $logger = LogCatcher.new
        $ncc = NCC.new('test/data/etc')
    end

    after :all do
        cleanup_fixture
    end

    describe "#images" do

        it "raises NCC::Error::NotFound for nonexistent image" do
            expect {
                $ncc.images('foo')
            }.to raise_error NCC::Error::NotFound
        end

    end

    describe "#sizes" do

        it "raises NCC::Error::NotFound for nonexistent size" do
            expect {
                $ncc.sizes('foo')
            }.to raise_error NCC::Error::NotFound
        end

    end

    describe "#clouds" do

        it "raises NCC::Error::NotFound for nonexistent cloud" do

            expect {
                $ncc.clouds('foo')
            }.to raise_error NCC::Error::NotFound

        end

    end

end
