DESCRIPTION
===========
Installs and configures Ganglia (http://ganglia.sourceforge.net/).

REQUIREMENTS
============
* SELinux must be disabled on CentOS
* iptables must allow access to port 80 (if iptables is installed)

ATTRIBUTES
==========
## Default (defaults in parenthesis)
* node['ganglia']['version'] - version to install (3.4.0)
* node['ganglia']['uri'] - alternate URL to download package from

* node['ganglia']['location'] - cluster location (unspecified)
* node['ganglia']['network_interface'] - network interface to bind to (eth0)
* node['ganglia']['cluster_name'] - cluster name for Gmetad (default)
* node['ganglia']['multicast'] - whether to use multicast or unicast (true)
* node['ganglia']['override_hostname'] - if true, the Ganglia hostname will be set to the node's FQDN (true)
* node['ganglia']['override_ip'] - if true, the IP address reported by Ganglia will be the node's first NIC's IP (true)
* node['ganglia']['receiver'] - sets the node to be a central receiver, required when node['ganglia']['multicast'] is set to _false_ (false)
* node['ganglia']['enable\_receiver\_acl'] - whether to restrict access to the receiver's port by node's IP address, generated dynamically from the list of nodes with "recipe[ganglia]" in their run lists (true)
* node['ganglia']['receiver\_network\_interface'] - network interface to listen for data when in receiver mode (eth1)
* node['ganglia']['send\_to\_graphite'] - if set to _true_, the recipe will configure Gmetad to send data to node['graphite']['url'] (false)
* node['ganglia']['graphite_prefix'] - default namespace for Graphite integration (ganglia)

## Web interface
* node['ganglia']['web']['version'] - version of Ganglia Web (3.5.2)
* node['ganglia']['web']['graph_engine'] - storage mechanism (rrdtool)
* node['ganglia']['web']['auth_system'] - authentication system (readonly)
* node['ganglia']['web']['path'] - default path to install Ganglia Web (/opt/ganglia-web)


## USAGE:
Add "recipe[ganglia]" to enable monitoring.
Add "recipe[ganglia::web]" to enable the web interface. Includes "recipe[ganglia::gmetad]."
Add "recipe[ganglia::gmetad]" to enable the metric aggregation daemon (Gmetad).

## CAVEATS: 
This cookbook has been tested on Ubuntu 10.04, 12.04 and Centos 5.5.

Search seems to takes a moment or two to index.
You may need to converge again to see recently added nodes.

CONTRIBUTORS
============
* Cramer Development (http://cramerdev.com)
* Rafael Fonseca (http://twitter.com/rafaelmagu)