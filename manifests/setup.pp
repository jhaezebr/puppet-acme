# set up acme and folders
class acme::setup {
  User { $acme::user:
    gid        => $acme::group,
    home       => $acme::base_dir,
    shell      => $acme::shell,
    managehome => false,
    password   => '!!',
    system     => true,
  }

  group { $acme::group:
    ensure => present,
    system => true,
  }

  File {
    ensure  => directory,
    owner   => $acme::user,
    group   => $acme::group,
    mode    => '0755',
    require => Group[$acme::group],
  }

  File { $acme::base_dir :
    ensure => directory,
    mode   => '0755',
    owner  => $acme::user,
    group  => $acme::group,
  }

  File { $acme::key_dir :
    ensure => directory,
    mode   => '0750',
    owner  => $acme::user,
    group  => $acme::group,
  }

  File { $acme::crt_dir :
    ensure => directory,
    mode   => '0755',
    owner  => $acme::user,
    group  => $acme::group,
  }

  File { $acme::acme_dir :
    ensure => directory,
    mode   => '0750',
    owner  => $acme::user,
    group  => $acme::group,
  }

  File { $acme::acct_dir :
    ensure => directory,
    mode   => '0700',
    owner  => $acme::user,
    group  => $acme::group,
  }

  File { $acme::cfg_dir :
    ensure => directory,
    mode   => '0700',
    owner  => $acme::user,
    group  => $acme::group,
  }

  File { $acme::acme_install_dir:
    ensure => directory,
    mode   => '0755',
  }

  File { $acme::csr_dir:
    ensure => directory,
    owner  => $acme::user,
    group  => $acme::group,
    mode   => '0755',
  }

  File { $acme::log_dir:
    ensure => directory,
    owner  => $acme::user,
    group  => $acme::group,
    mode   => '0755',
  }

  File { $acme::results_dir:
    ensure => directory,
    owner  => $acme::user,
    group  => $acme::group,
    mode   => '0755',
  }

  if ($acme::manage_packages) {
    if !defined(Package['git']) {
      ensure_packages('git')
    }
    $vcsrepo_require = [File[$acme::acme_install_dir],Package['git']]
  } else {
    $vcsrepo_require = File[$acme::acme_install_dir]
  }

  # Checkout aka "install" acme.sh.
  Vcsrepo { $acme::acme_install_dir:
    ensure   => latest,
    revision => $acme::acme_revision,
    provider => git,
    source   => $acme::acme_git_url,
    user     => root,
    force    => $acme::acme_git_force,
    require  => $vcsrepo_require,
  }
}
