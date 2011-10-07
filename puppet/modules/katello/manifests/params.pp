class katello::params {
  # database settings
  $db_user = "katello"
  $db_name = "katello"
  $db_pass = "katello"

  # system settings
  $user        = "katello"
  $group       = "katello"
  $config_dir  = "/etc/katello"
  $katello_dir = "/usr/share/katello"
  $environment = "production"
  $migrate_log = "${katello_dir}/log/db_migrate.log"
  $seed_log    = "${katello_dir}/log/db_seed.log"

  # SSL settings
  $ssl_certificate_file     = "/etc/candlepin/certs/candlepin-ca.crt"
  $ssl_certificate_key_file = "/etc/candlepin/certs/candlepin-ca.key"
  $ssl_certificate_ca_file  = $ssl_certificate_file

  # apache settings
  $thin_start_port = "5000"
  $thin_log        = "/var/log/katello/thin-log.log"

  # LDAP settings
  $ldap_server = "localhost"
  $ldap_basedn = "ou=People,dc=company,dc=com"

  # OAUTH settings
  $oauth_key    = "katello"
  $oauth_secret = regsubst(generate('/usr/bin/openssl', 'rand', '-base64', '24'), '^(.{24}).*', '\1')

  # Subsystems settings
  $candlepin_url = "https://localhost:8443/candlepin"
  $pulp_url      = "https://localhost/pulp/api"
  $foreman_url   = "https://localhost/foreman"
}
