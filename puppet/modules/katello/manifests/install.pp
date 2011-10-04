class katello::install {
  include katello
  include pulp::install
  include candlepin::install
  include postgres::install
  include apache2::install
  include qpid::install

  $os_type = $operatingsystem ? {
    "Fedora" => "fedora-${operatingsystemrelease}",
    default  => "\$releasever"
  }

  yumrepo { "fedora-katello":
    descr    => 'integrates together a series of open source systems management tools',
    baseurl  => "http://repos.fedorapeople.org/repos/katello/katello/$os_type/\$basearch/",
    enabled  => "1",
    gpgcheck => "0"
  }
  yumrepo { "fedora-katello-source":
    descr    => 'integrates together a series of open source systems management tools',
    baseurl  => "http://repos.fedorapeople.org/repos/katello/katello/$os_type/\$basearch/SRPMS",
    enabled  => "0",
    gpgcheck => "0"
  }

	package{["katello", "katello-cli"]:
    require => [Yumrepo["fedora-katello"],Class["pulp::install"],Class["candlepin::install"]],
    before  => [Class["candlepin::config"], Class["pulp::config"] ], #avoid some funny post rpm scripts
    ensure  => installed
  }
  Class["katello::install"] -> File["/var/log/katello"]
  Class["katello::install"] -> File["${katello::params::config_dir}/thin.yml"]
  Class["katello::install"] -> File["${katello::params::config_dir}/katello.yml"]
  Class["katello::install"] -> File["/etc/httpd/conf.d/katello.conf"]
}
