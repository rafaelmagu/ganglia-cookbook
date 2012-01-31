#
# Cookbook Name:: ganglia
# Recipe:: default
#
# Copyright 2011, Heavy Water Software Inc.
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
#

gem_package 'gmetric'
v = node['ganglia']['version']

case node[:platform]
when "ubuntu", "debian"
  service_name = 'ganglia-monitor'
  apt_repository 'ganglia' do
    uri 'http://ppa.launchpad.net/rufustfirefly/ganglia/ubuntu'
    distribution node['lsb']['codename']
    components ['main']
    keyserver 'keyserver.ubuntu.com'
    key 'A93EFBE2'
    action :add
  end

  package "ganglia-monitor"
when "redhat", "centos", "fedora"
  service_name = 'gmond'

  user 'ganglia'

  remote_file '/usr/src/libconfuse-2.6-1.x86_64.rpm' do
    source 'http://vuksan.com/centos/RPMS/x86_64/libconfuse-2.6-1.x86_64.rpm'
  end
  rpm_package 'libconfuse' do
    source '/usr/src/libconfuse-2.6-1.x86_64.rpm'
  end
  remote_file "/usr/src/libganglia-#{v}-1.x86_64.rpm" do
    source "http://vuksan.com/centos/RPMS/x86_64/libganglia-#{v}-1.x86_64.rpm"
  end
  rpm_package 'libganglia' do
    source "/usr/src/libganglia-#{v}-1.x86_64.rpm"
    version "#{v}-1"
  end
  remote_file "/usr/src/ganglia-gmond-#{v}-1.x86_64.rpm" do
    source "http://vuksan.com/centos/RPMS/x86_64/ganglia-gmond-#{v}-1.x86_64.rpm"
  end
  rpm_package 'ganglia-gmond' do
    source "/usr/src/ganglia-gmond-#{v}-1.x86_64.rpm"
    version "#{v}-1"
  end
  link '/usr/lib/ganglia' do
    to '/usr/lib64/ganglia'
  end
  remote_file "/usr/src/ganglia-gmond-modules-python-#{v}-1.x86_64.rpm" do
    source "http://vuksan.com/centos/RPMS/x86_64/ganglia-gmond-modules-python-#{v}-1.x86_64.rpm"
  end
  rpm_package 'ganglia-gmond-modules-python' do
    source "/usr/src/ganglia-gmond-modules-python-#{v}-1.x86_64.rpm"
    version "#{v}-1"
  end
end

# Set up a route for multicast
if node['ganglia']['multicast']
  # avahi allow host name resolution
  case node['platform']
  when "ubuntu", "debian"
    package 'avahi-daemon'
  when "redhat", "centos", "fedora"
    package 'avahi-daemon'
  end
  # Add mdns route
  route '239.2.11.71' do
    device node[:ganglia][:network_interface]
  end
end

# IP address to bind
ip = ((node['network']['interfaces'][node['ganglia']['network_interface']] || {})['addresses'] || {}).find {|a, i|
      i['family'] == 'inet'
    }.first || node['ipaddress']

# Set up send hosts for non-multicast nodes
send_hosts = []
unless node['ganglia']['multicast']
  send_hosts = search(:node, "ganglia_receiver:true AND ganglia_cluster_name:#{node['ganglia']['cluster_name']}").map do |n|
    n['network']['interfaces'][n['ganglia']['receiver_network_interface']]['addresses'].find {|a, i|
      i['family'] == 'inet'
    }.first
  end
end

# Set up a 'receiver' or node that accepts connections from an allowed list of
# udp senders
recv_addr = nil

if node['ganglia']['receiver']
  # Find the reciever network interface ipv4 IP from the node data
  recv_iface = node['ganglia']['receiver_network_interface']
  recv_addr = node['network']['interfaces'][recv_iface]['addresses'].find {|a, i|
    i['family'] == 'inet'
  }.first

  recv_hosts = search(:node, "recipes:ganglia AND ganglia_cluster_name:#{node['ganglia']['cluster_name']} AND ganglia_multicast:false").map do |n|
    n['ipaddress']
  end
end

template "/etc/ganglia/gmond.conf" do
  source "gmond.conf.erb"
  variables({ :ip             => ip,
              :recv_bind_addr => recv_addr,
              :recv_hosts     => recv_hosts,
              :send_hosts     => send_hosts
           })
  notifies :restart, "service[#{service_name}]"
end

service service_name do
  pattern "gmond"
  supports :restart => true
  action [ :enable, :start ]
end

# gmond DSO modules
directory '/etc/ganglia/conf.d'  do
  recursive true
end

remote_directory '/usr/lib/ganglia/python_modules' do
  source 'gmond_python_modules'
end

template '/etc/ganglia/conf.d/modpython.conf' do
  source 'gmond_python_modules_conf.d/modpython.conf.erb'
  notifies :restart, "service[#{service_name}]"
end

if node.recipes.include?('apache2')
  template '/etc/ganglia/conf.d/apache_status.pyconf' do
    source 'gmond_python_modules_conf.d/apache_status.pyconf.erb'
    notifies :restart, "service[#{service_name}]"
  end
end

