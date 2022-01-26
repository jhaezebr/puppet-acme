# @summary Gather all data and use acme.sh to create accounts and sign certificates.
#
# @api private
class acme::request::handler {
  File {
    owner => 'root',
    group => 0,
  }

  # Store config for profiles in filesystem, if we support them.
  # (Otherwise the user needs to manually create the required files.)
  $acme::profiles.each |$profile_name, $profile_config| {
    # Simple validation of profile config
    if ($profile_config != undef) and (type($profile_config) =~ Type[Hash]) {
      $challengetype = $profile_config['challengetype']
      $hook = $profile_config['hook']
    } else {
      fail("Module ${module_name}: profile \"${profile_name}\" config must be of type Hash")
    }

    # Basic validation for ALL profiles.
    if !$challengetype or !$hook {
      fail("Module ${module_name}: profile \"${profile_name}\" is incomplete,",
        "missing either \"challengetype\" or \"hook\"")
    }

    # DNS-01: nsupdate hook
    if ($challengetype == 'dns-01') and ($hook == 'nsupdate') {
      $nsupdate_id = $profile_config['options']['nsupdate_id']
      $nsupdate_key = $profile_config['options']['nsupdate_key']
      $nsupdate_type = $profile_config['options']['nsupdate_type']

      # Make sure all required values are available.
      if ($nsupdate_id and $nsupdate_key and $nsupdate_type) {
        # Create config file for hook script.
        $hook_dir = "${acme::cfg_dir}/profile_${profile_name}"
        $hook_conf_file = "${hook_dir}/hook.cnf"

        file { $hook_dir:
          ensure => directory,
          owner  => $acme::user,
          group  => $acme::group,
          mode   => '0600',
        }

        file { $hook_conf_file:
          owner   => $acme::user,
          group   => $acme::group,
          mode    => '0600',
          content => epp("${module_name}/hooks/${hook}.epp", {
            nsupdate_id   => $nsupdate_id,
            nsupdate_key  => $nsupdate_key,
            nsupdate_type => $nsupdate_type,
            }),
          require => File[$hook_dir],
        }
      }
    }
  }

  # needed for the openssl ocsp -header flag
  $old_openssl = versioncmp($::openssl_version, '1.1.0') < 0

  file { $acme::ocsp_request:
    ensure  => file,
    owner   => 'root',
    group   => $acme::group,
    mode    => '0755',
    content => epp("${module_name}/get_certificate_ocsp.sh.epp", {
      old_openssl => $old_openssl,
      path        => $acme::path,
      proxy       => $acme::proxy,
      }),
  }

  # Get all certificate signing requests that were tagged to be processed on
  # this host. Usually you want them all to run on the Puppet Server.
  Acme::Request<<| tag == "master_${::fqdn}" |>>
}
