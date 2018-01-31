# opsmon::sensu_rabbitmq
#
# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include opsmon::sensu_rabbitmq
class opsmon::sensu_rabbitmq {

  class { 'erlang': epel_enable => true}

  exec { 'yum-update':
    command => '/usr/bin/yum update -y'  # command this resource will run
  }

  exec { 'yum groupinstall Development Tools':
    command => '/usr/bin/yum -y --disableexcludes=all groupinstall "Development Tools"',
    unless  => '/usr/bin/yum grouplist "Development Tools" | /bin/grep "^Installed"',
    timeout => 600,
  }

  ## Generate the sensu rabbitmq self signed certs using sensu's tool
  archive { '/tmp/sensu_ssl_tool.tar':
    ensure        => present,
    extract       => true,
    extract_path  => '/etc/ssl',
    source        => 'https://sensuapp.org/docs/1.2/files/sensu_ssl_tool.tar',
    checksum      => '930896025099e3be7bcf719a9f55d92d4a3ebf65',
    checksum_type => 'sha1',
    creates       => '/etc/ssl/sensu_ssl_tool',
    cleanup       => true,
  } ->

  exec { 'sensu_ssl_generate':
    cwd         => '/etc/ssl/sensu_ssl_tool',
    command     => '/etc/ssl/sensu_ssl_tool/ssl_certs.sh generate',
    creates     => [ "/etc/ssl/sensu_ssl_tool/sensu_ca/cacert.pem", "/etc/ssl/sensu_ssl_tool/server/cert.pem", "/etc/ssl/sensu_ssl_tool/server/key.pem" ],
    timeout     => 60,
    require     => Archive['/tmp/sensu_ssl_tool.tar'],
  } ->

  class { 'rabbitmq':
    service_manage    => true,
    #port              => 5672,
    ssl               => true,
    ssl_port          => 5671,
    ssl_cacert        => '/etc/ssl/sensu_ssl_tool/sensu_ca/cacert.pem',
    ssl_cert          => '/etc/ssl/sensu_ssl_tool/server/cert.pem',
    ssl_key           => '/etc/ssl/sensu_ssl_tool/server/key.pem',
    ssl_verify        => 'verify_peer',
    ssl_fail_if_no_peer_cert => true,
    delete_guest_user => true,
    require           => Class['erlang'],
  }

  service {"rabbitmq-server":
    ensure     => running,
    enable     => true,
  }

  package {"redis":
    ensure    => present,
    require   => Class['erlang'],
  }


}

