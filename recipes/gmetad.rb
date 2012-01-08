case node[:platform]
when "ubuntu", "debian"
  %w{ rrdtool gmetad }.each do |pkg|
    package pkg
  end
when "redhat", "centos", "fedora"
  include_recipe "ganglia::source"
  execute "copy gmetad init script" do
    command "cp " +
      "/usr/src/ganglia-#{node[:ganglia][:version]}/gmetad/gmetad.init " +
      "/etc/init.d/gmetad"
    not_if "test -f /etc/init.d/gmetad"
  end
end

directory "/var/lib/ganglia/rrds" do
  owner "nobody"
  recursive true
end

query  = 'recipes:ganglia'
if node[:ganglia][:cluster_role]
  query += " AND roles:#{node[:ganglia][:cluster_role]}"
end
ips = search(:node, query).map {|node| (node[:cloud] || {})[:local_ipv4] || node[:ipaddress] }

template "/etc/ganglia/gmetad.conf" do
  source "gmetad.conf.erb"
  variables( :hosts => ips.join(" "),
             :cluster_name => node[:ganglia][:cluster_name])
  notifies :restart, "service[gmetad]"
end

service "gmetad" do
  supports :restart => true
  action [ :enable, :start ]
end
