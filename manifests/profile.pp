# acme request profile
define acme::profile (
  Hash $profile_config,
  String $profile_name = $name,
){
  File {
    owner => 'root',
    group => 0,
  }

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
