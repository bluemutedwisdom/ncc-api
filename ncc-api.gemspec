Gem::Specification.new do |s|
    s.name        = 'ncc-api'
    s.version     = '1.0.0'
    s.summary     = 'NOMS Cloud Controller API'
    s.description = 'The NOMS cloud controller API provides a ReSTful API abstracting and aggregating a set of specific cloud computing providers (called "clouds").'
    s.authors     = ["Jeremy Brinkley"]
    s.email       = 'jbrinkley@evernote.com'
    s.homepage    = 'https://github.com/evernote/ncc-api'
    s.licenses    = ['Apache-2']
    s.files       = %w(
        lib/ncc/config.rb
        lib/ncc/connection/aws.rb
        lib/ncc/connection/openstack.rb
        lib/ncc/connection.rb
        lib/ncc/error.rb
        lib/ncc/instance.rb
        lib/ncc-api.rb
        lib/ncc.rb)

    s.executables << 'ncc-api'
    s.add_runtime_dependency 'fog'
    s.add_runtime_dependency 'sinatra'
    s.add_runtime_dependency 'uuidtools'
end
