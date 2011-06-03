#
# Cookbook Name:: ganglia
# Recipe:: web2
#
# Copyright 2011, Cramer Development
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

# "Web 2.0" interface for ganglia
# NOTE: This recipe does not install an apache config, just puts the files in
#       /var/www/ and sets them up.

include_recipe 'apache2'
include_recipe 'ganglia::gmetad'

package 'subversion'
path = '/var/www/ganglia-misc'

# Config and template directories
%w{ conf dwoo }.each do |dir|
  directory "/var/lib/ganglia/#{dir}" do
    owner node[:apache][:user]
    group node[:apache][:user]
    mode '0755'
    recursive true
  end
end

git path do
  repository 'git://github.com/vvuksan/ganglia-misc.git'
  action :export
end

path += '/ganglia-web'

directory path do
  owner node[:apache][:user]
  group node[:apache][:user]
  mode '0755'
  recursive true
end

directory "#{path}/graph.d" do
  owner node[:apache][:user]
  group node[:apache][:user]
  mode '0755'
  recursive true
end

template "#{path}/conf_default.php" do
  source 'conf_default.php.erb'
  owner node[:apache][:user]
  group node[:apache][:user]
  mode '0644'
end
