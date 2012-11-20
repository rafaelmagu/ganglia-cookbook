maintainer       "Heavy Water Software Inc."
maintainer_email "darrin@heavywater.ca"
license          "Apache 2.0"
description      "Installs/Configures ganglia"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.rdoc'))
version          "0.0.3"
depends 'apt'
depends 'openssl'
depends 'postgresql'
supports "debian"
supports "ubuntu"
supports "redhat"
supports "centos"
supports "fedora"
