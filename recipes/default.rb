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
v = node[:ganglia][:version]
service_name = 'ganglia-monitor'

case node[:platform]
when "ubuntu", "debian"
  apt_repository 'ganglia' do
    uri 'http://ppa.launchpad.net/rufustfirefly/ganglia/ubuntu'
    distribution node[:lsb][:codename]
    components [:main]
    keyserver 'keyserver.ubuntu.com'
    key 'A93EFBE2'
    action :add
end

execute "apt-get-update"

package "ganglia-monitor"
when "redhat", "centos", "fedora"
    user 'ganglia'
    group 'ganglia'

    # FIXME: See https://github.com/ganglia/monitor-core/issues/28
    include_recipe 'ganglia::source'
end

# Set up a route for multicast
unless node[:ganglia][:unicast]
    # avahi allow host name resolution
    case node[:platform]
    when "ubuntu", "debian"
        package 'avahi-daemon'
    when "redhat", "centos", "fedora"
        package 'avahi'
    end
    # Add mdns route
    route '239.2.11.71' do
        device node[:ganglia][:network_interface]
    end
end

# IP address to bind
ip = (((node[:network][:interfaces][node[:ganglia][:network_interface]] || {})[:addresses] || {}).find {|a, i| i[:family] == 'inet'} || []).first || node[:ipaddress]

# Set up send hosts for non-multicast nodes
send_hosts = []
if node[:ganglia][:unicast]
    if Chef::Config[:solo]
        Chef::Log.warn("This recipe uses search. Chef Solo does not support search.")
    else
        send_hosts = search(:node, "ganglia_receiver:true AND ganglia_cluster_name:#{node[:ganglia][:cluster_name]}").map do |n|
            n[:network][:interfaces][n[:ganglia][:receiver_network_interface]][:addresses].find {|a, i| i[:family] == 'inet'}.first
        end
    end
end

# Set up a 'receiver' or node that accepts connections from an allowed list of
# udp senders
recv_addr = nil

if node[:ganglia][:receiver]
    # Find the reciever network interface ipv4 IP from the node data
    recv_iface = node[:ganglia][:receiver_network_interface]
    recv_addr = node[:network][:interfaces][recv_iface][:addresses].find {|a, i| i[:family] == 'inet'}.first

    if Chef::Config[:solo]
        Chef::Log.warn("This recipe uses search. Chef Solo does not support search.")
    else
        recv_hosts = search(:node, "recipes:ganglia AND ganglia_cluster_name:#{node[:ganglia][:cluster_name]} AND ganglia_multicast:false").map do |n|
            if n[:cloud] && n[:cloud][:public_ipv4]
                n[:cloud][:public_ipv4]
            else
                n[:ipaddress]
            end
        end
    end
end

# Weirdness. See https://github.com/ganglia/monitor-core/issues/49
name_match = node.name.match(/\d+/)
valid_number = name_match.nil? || name_match[0].to_i <= 1
override_hostname = node[:ganglia][:override_hostname] #&& valid_number
template "/etc/ganglia/gmond.conf" do
    source "gmond.conf.erb"
    variables({ :ip      => ip,
      :recv_bind_addr    => recv_addr,
      :recv_hosts        => recv_hosts,
      :send_hosts        => send_hosts,
      :override_hostname => override_hostname
    })
    notifies :restart, "service[#{service_name}]"
end

service service_name do
    pattern "gmond"
    supports :restart => true
    action [ :enable, :start ]
end

# gmond DSO modules
python_modules = []

directory '/etc/ganglia/conf.d'  do
    recursive true
end

remote_directory '/usr/lib/ganglia/python_modules' do
    source 'gmond_python_modules'
end

if node[:recipes].include?('apache2')
    python_modules << 'apache_status'
    template '/etc/ganglia/conf.d/apache_status.pyconf' do
        source 'gmond_python_modules_conf.d/apache_status.pyconf.erb'
        owner 'ganglia'
        group 'ganglia'
        notifies :restart, "service[#{service_name}]"
    end
end

if node[:recipes].include?('nginx::passenger')
    python_modules << 'passenger'
    template '/etc/ganglia/conf.d/passenger.pyconf' do
        source 'gmond_python_modules_conf.d/passenger.pyconf.erb'
        owner 'ganglia'
        group 'ganglia'
        notifies :restart, "service[#{service_name}]"
    end
end

if node[:recipes].include?('redis')
    python_modules << 'redis'
    template '/etc/ganglia/conf.d/redis.pyconf' do
        source 'gmond_python_modules_conf.d/redis.pyconf.erb'
        owner 'ganglia'
        group 'ganglia'
        notifies :restart, "service[#{service_name}]"
    end
end

if node[:recipes].include?('rabbitmq')
    python_modules << 'rabbitmq'
    template '/etc/ganglia/conf.d/rabbitmq.pyconf' do
        source 'gmond_python_modules_conf.d/rabbitmq.pyconf.erb'
        owner 'ganglia'
        group 'ganglia'
        notifies :restart, "service[#{service_name}]"
    end
end

if node[:recipes].include?('php-fpm')
    python_modules << 'php_fpm'
    template '/etc/ganglia/conf.d/php_fpm.pyconf' do
        source 'gmond_python_modules_conf.d/php_fpm.pyconf.erb'
        owner 'ganglia'
        group 'ganglia'
        notifies :restart, "service[#{service_name}]"
    end
end

if node[:recipes].include?('nginx')
    python_modules << 'nginx_status'
    template '/etc/ganglia/conf.d/nginx_status.pyconf' do
        source 'gmond_python_modules_conf.d/nginx_status.pyconf.erb'
        owner 'ganglia'
        group 'ganglia'
        notifies :restart, "service[#{service_name}]"
    end
end

# Uses the cookbook from https://github.com/phlipper/chef-postgresql
if node[:recipes].include?('postgresql::server')
    python_modules << 'postgresql'
    package 'python-psycopg2'

    pg_user 'ganglia' do
        priviliges :superuser => true, :createdb => false, :login => true
        password node[:ganglia][:postgresql][:password]
    end

    template '/etc/ganglia/conf.d/postgresql.pyconf' do
        source 'gmond_python_modules_conf.d/postgresql.pyconf.erb'
        owner 'ganglia'
        group 'ganglia'
        notifies :restart, "service[#{service_name}]"
    end
end

unless python_modules.empty?
    template '/etc/ganglia/conf.d/modpython.conf' do
        source 'gmond_python_modules_conf.d/modpython.conf.erb'
        owner 'ganglia'
        group 'ganglia'
        notifies :restart, "service[#{service_name}]"
    end

    # ganglia needs sudo access for passenger status
    group 'admin' do
        members 'ganglia'
        append true
    end
end
