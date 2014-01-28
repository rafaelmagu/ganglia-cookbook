include_recipe "iptables"

iptables_rule "http"
iptables_rule "https"

if Chef::Config[:solo]
    Chef::Log.warn("This recipe uses search. Chef Solo does not support search.")
    workers = []
else
    workers = search(:node, "*:*")  || []
end
subnets = []

workers.each do |w|
  subnets << [ w.name, "#{w['ipaddress']}/32" ]
end

subnets.each do |h|
  template "/etc/iptables.d/#{h[0]}" do
    source "whitelist.erb"
    mode "644"
    variables :subnet => h[1]
    notifies :run, "execute[rebuild-iptables]"
  end
end
