name             "ganglia"
maintainer       "Heavy Water Software Inc."
maintainer_email "darrin@heavywater.ca"
license          "Apache 2.0"
description      "Installs/Configures ganglia"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.1.3"

%w{ debian ubuntu redhat centos fedora }.each do |os|
  supports os
end

depends "graphite"
depends "iptables"
depends "apache2"
