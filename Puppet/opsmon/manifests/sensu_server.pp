# opsmon::sensu_server
#
# A description of what this class does
#
# @summary A short summary of the purpose of this class
#
# @example
#   include opsmon::sensu_server
class opsmon::sensu_server {

  rabbitmq_user { 'sensu':
    admin    => true,
    password => 'secret',
  } ->

  rabbitmq_vhost { '/sensu':
    ensure   => present,
  } ->

  rabbitmq_user_permissions { 'sensu@/sensu':
    configure_permission => '.*',
    read_permission      => '.*',
    write_permission     => '.*',
  }


  class { 'sensu':
    install_repo      => true,
    manage_services   => true,
    manage_user       => true,
    rabbitmq_password => 'secret',
    rabbitmq_host     => '127.0.0.1',
    rabbitmq_vhost    => '/sensu',
    rabbitmq_port     => 5671,
    rabbitmq_ssl_cert_chain  => '/etc/ssl/sensu_ssl_tool/client/cert.pem',
    rabbitmq_ssl_private_key => '/etc/ssl/sensu_ssl_tool/client/key.pem',
    server            => true,
    api               => true,
    api_user          => 'admin',
    api_password      => 'secret',
    client_address    => $::ipaddress_eth1,
    redis_host        => '127.0.0.1',
    redis_port        => 6379,
    plugins           => [
      'puppet:///modules/opsmon/plugins/ntp.rb',
      'puppet:///modules/opsmon/plugins/postfix.rb'
    ]
  }

  package { 'mail':
    ensure            => 'installed',
    provider          => sensu_gem,
  }

  sensu::handler { 'default':
    command => 'mail -s \'sensu alert\' ops@foo.com',
  }

  sensu::check { 'check_ntp':
    command     => 'PATH=$PATH:/usr/lib/nagios/plugins check_ntp_time -H pool.ntp.org -w 30 -c 60',
    handlers    => 'default',
    subscribers => 'sensu-test'
  }
  exec {'create_self_signed_sslcert':
    command => "openssl req -newkey rsa:2048 -nodes -keyout ${::fqdn}.key  -x509 -days 365 -out ${::fqdn}.crt -subj '/CN=${::fqdn}'",
    cwd     => $certdir,
    creates => [ "${certdir}/${::fqdn}.key", "${certdir}/${::fqdn}.crt", ],
    path    => ["/usr/bin", "/usr/sbin"]
  }

  exec {'create_self_signed_sslcert_uchiwa':
    command => "openssl req -newkey rsa:2048 -nodes -keyout uchiwa.key  -x509 -days 365 -out uchiwa.pem -subj '/CN=${::fqdn}'",
    cwd     => '/etc/ssl',
    creates => [ "/etc/ssl/uchiwa.key", "/etc/ssl/uchiwa.pem", ],
    path    => ["/usr/bin", "/usr/sbin"]
  }

  package { 'uchiwa':
    ensure        => present,
  } ->


    file { '/etc/sensu/uchiwa.json':
      ensure  => present,
      content => '
    {
      "sensu": [
        {
          "name": "Cloud Aware",
          "host": "127.0.0.1",
          "port": 4567,
          "timeout": 10
        }
      ],
      "uchiwa": {
        "host": "0.0.0.0",
        "port": 3000,
        "ssl": {
           "certfile": "/etc/ssl/uchiwa.pem",
           "keyfile": "/etc/ssl/uchiwa.key"
        },
        "user": "uchiwa",
        "pass": "uchiwa",
        "stats": 10,
        "refresh": 10000,
        "interval": 5
      }
    }',
      require => Package['uchiwa'],
      notify  => Service['uchiwa'],
    }

    service { 'uchiwa':
      ensure     => running,
      enable     => true,
      require    => [ File['/etc/sensu/uchiwa.json'],Package['uchiwa'] ]
    }
}
