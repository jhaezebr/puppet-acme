# acme account
define acme::account (
  String $account_email = $name
){
  File {
    owner => 'root',
    group => 0,
  }

  $account_dir = "${acme::acct_dir}/${account_email}"

  # Create a directory for each account.
  file { $account_dir:
    ensure => directory,
    owner  => $acme::user,
    group  => $acme::group,
    mode   => '0750',
  }

  # Register accounts for all whitelisted ACME CAs.
  # (Because we just don't know for which it will be used later.)
  $acme_cas = $acme::ca_whitelist
  $acme_cas.each |$acme_ca| {

    # Evaluate how the CA should be represented in filenames.
    # This is a compatibility layer. It ensures that old files that
    # were generated for the Let's Encrypt Production/Staging CA
    # can still be used.
    case $acme_ca {
      'letsencrypt': {
        $acme_ca_compat = 'production'
      }
      'letsencrypt_test': {
        $acme_ca_compat = 'staging'
      }
      'buypass', 'buypass_test', 'sslcom', 'zerossl': {
        $acme_ca_compat = $acme_ca
      }
      default: {
        $acme_ca_compat = 'custom'
      }
    }

    # Handle switching CAs with different account keys.
    $account_key_file = "${account_dir}/private_${acme_ca_compat}.key"
    $account_conf_file = "${account_dir}/account_${acme_ca_compat}.conf"

    # Create account config file for acme.sh.
    file { $account_conf_file:
      ensure  => present,
      owner   => $acme::user,
      group   => $acme::group,
      mode    => '0640',
      require => File[$account_dir],
    }
    # Use Augeas to set the configuration, because acme.sh will also make
    # changes to this file and we don't want to overwrite them without reason.
    -> augeas { "update account conf: ${account_conf_file}":
      lens    => 'Shellvars.lns',
      incl    => $account_conf_file,
      context => "/files${account_conf_file}",
      changes => [
        "set CERT_HOME \"'${acme::acme_dir}'\"",
        "set LOG_FILE \"'${acme::acmelog}'\"",
        "set ACCOUNT_KEY_PATH \"'${account_key_file}'\"",
        "set ACCOUNT_EMAIL \"'${account_email}'\"",
        "set LOG_LEVEL \"'2'\"",
        "set USER_PATH \"'${acme::path}'\"",
        ]
    }

    # Some status files so we avoid useless runs of acme.sh.
    $account_created_file = "${account_dir}/${acme_ca_compat}.created"
    $account_registered_file = "${account_dir}/${acme_ca_compat}.registered"

    $le_create_command = join([
      $acme::acmecmd,
      '--create-account-key',
      '--accountkeylength 4096',
      '--log-level 2',
      "--log ${acme::acmelog}",
      "--home ${acme::acme_dir}",
      "--accountconf ${account_conf_file}",
      "--server ${acme_ca}",
      '>/dev/null',
      '&&',
      "touch ${account_created_file}",
    ], ' ')

    # Run acme.sh to create the account key.
    exec { "create-account-${acme_ca}-${account_email}" :
      user    => $acme::user,
      cwd     => $acme::base_dir,
      group   => $acme::group,
      path    => $acme::path,
      command => $le_create_command,
      creates => $account_created_file,
      require => [
        User[$acme::user],
        Group[$acme::group],
        File[$account_conf_file],
      ],
    }

    $le_register_command = join([
      $acme::acmecmd,
      '--registeraccount',
      '--log-level 2',
      "--log ${acme::acmelog}",
      "--home ${acme::acme_dir}",
      "--accountconf ${account_conf_file}",
      "--server ${acme_ca}",
      '>/dev/null',
      '&&',
      "touch ${account_registered_file}",
    ], ' ')

    # Run acme.sh to register the account.
    exec { "register-account-${acme_ca}-${account_email}" :
      user    => $acme::user,
      cwd     => $acme::base_dir,
      group   => $acme::group,
      path    => $acme::path,
      command => $le_register_command,
      creates => $account_registered_file,
      require => [
        User[$acme::user],
        Group[$acme::group],
        File[$account_conf_file],
      ],
    }
  }
}
