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

case node[:platform]
when "ubuntu", "debian"
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
  include_recipe "ganglia::source"

  execute "copy ganglia-monitor init script" do
    command "cp " +
      "/usr/src/ganglia-#{node[:ganglia][:version]}/gmond/gmond.init " +
      "/etc/init.d/ganglia-monitor"
    not_if "test -f /etc/init.d/ganglia-monitor"
  end

  user "ganglia"
end

# Set up a route for multicast
if node['ganglia']['multicast']
  route '239.2.11.71' do
    device node[:ganglia][:network_interface]
  end
end

directory "/etc/ganglia"

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
  variables({ :recv_bind_addr => recv_addr,
              :recv_hosts     => recv_hosts,
              :send_hosts     => send_hosts
           })
  notifies :restart, "service[ganglia-monitor]"
end

service "ganglia-monitor" do
  pattern "gmond"
  supports :restart => true
  action [ :enable, :start ]
end

