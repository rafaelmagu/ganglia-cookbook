# Workaround for not having the newest version in packages
default['ganglia']['version'] = '3.4.0'
default[:ganglia][:uri] = "http://sourceforge.net/projects/ganglia/files/ganglia%20monitoring%20core/3.4.0/ganglia-3.4.0.tar.gz/download"
default[:ganglia][:checksum] = '3734a381f6fa652a8b957b63f144b397'

default['ganglia']['location'] = 'unspecified'
default[:ganglia][:network_interface] = 'eth0'
default['ganglia']['cluster_name'] = 'default'
default['ganglia']['multicast'] = true
default['ganglia']['override_hostname'] = true
default['ganglia']['receiver'] = false
default['ganglia']['receiver_network_interface'] = 'eth1'
default['ganglia']['send_to_graphite'] = false
default['ganglia']['graphite_prefix'] = 'ganglia'

default[:ganglia][:web][:version] = '4.0.0'
default[:ganglia][:web][:graph_engine] = 'rrdtool'
default[:ganglia][:web][:auth_system] = 'readonly'
default[:ganglia][:web][:path] = '/opt/ganglia-web'
