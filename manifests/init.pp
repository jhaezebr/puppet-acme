# @summary Install and configure acme.sh to manage SSL certificates
#
# @param certificates
#   Array of full qualified domain names you want to request a certificate for.
#   For SAN certificates you need to pass space seperated strings,
#   for example ['foo.example.com fuzz.example.com', 'blub.example.com']
#
# @param profiles
#   A hash of profiles that contain information how acme.sh should sign
#   certificates. A profile defines not only the challenge type, but also all
#   required parameters and credentials used by acme.sh to sign the certificate.
#   Should only be defined on $acme_host.
#
# @param accounts
#   An array of e-mail addresses that acme.sh may use during the ACME
#   account registration. Should only be defined on $acme_host.
#
# @param acme_host
#   The host you want to run acme.sh on.
#   For now it needs to be a puppetmaster, as it needs direct access
#   to the certificates using functions in Puppet.
#
# @param acme_git_url
#   URL to the acme.sh GIT repository. Defaults to the official GitHub project.
#   Feel free to use a local mirror or fork.
#
# @param acme_git_force
#   Force repository creation, destroying any files on the path in the process.
#   Useful when the repo URL has changed.
#
# @param acme_revision
#   The GIT revision of the acme.sh repository. Defaults to `master` which should
#   contain a stable version of acme.sh.
#
# @param ca_whitelist
#   Specifies the CAs that may be used on `$acme_host`. The module will register
#   any account specified in `$accounts` with all specified CAs. This ensure that
#   these accounts are ready for use.
#
# @param default_ca
#   The default ACME CA you want to use. May be overriden by specifying a
#   different value for `$ca` for the certificate.
#   Previous versions of acme.sh used to have Let's Encrypt as their default CA,
#   hence this is the default value for this Puppet module.
#
# @param proxy
#   Proxy server to use to connect to the ACME CA, for example `proxy.example.com:3128`
#
# @param renew_days
#   Specifies the interval at which certs should be renewed automatically. Defaults to `60`.
#
# @param posthook_cmd
#   Specified a optional command to run after a certificate has been changed.
#
# @param dh_param_size
#   Specifies the DH parameter size, defaults to `2048`.
#
# @param ocsp_must_staple
#   Whether to request certificates with OCSP Must-Staple extension, defaults to `true`.
#
# @param manage_packages
#   Whether the module should install necessary packages, mainly git.
#   Set to `false` to disable package management.
#
# @param dnssleep
#   The time in seconds acme.sh should wait for all DNS changes to take effect.
#   Settings this to `0` disables the sleep mechanism and lets acme.sh poll DNS
#   status automatically by using DNS over HTTPS.
#
# @param exec_timeout
#   Specifies the time in seconds that any acme.sh operation can take before
#   it is aborted by Puppet. This should usually be set to a higher value
#   than `$dnssleep`.
#
# @param wildcard_marker
#   A string that is used to replace `*` in wildcard certificates. This is required
#   because Puppet does not allow special chars in variable names.
#   DO NOT CHANGE THIS VALUE! It is hardcoded in all custom facts too.
#
class acme (
  Array $accounts,
  String $acme_git_url,
  Boolean $acme_git_force,
  String $acme_host,
  String $acme_revision,
  Stdlib::Compat::Absolute_path $acme_install_dir,
  String $acmecmd,
  Stdlib::Compat::Absolute_path $acmelog,
  Stdlib::Compat::Absolute_path $base_dir,
  Stdlib::Compat::Absolute_path $acme_dir,
  Stdlib::Compat::Absolute_path $acct_dir,
  Stdlib::Compat::Absolute_path $cfg_dir,
  Stdlib::Compat::Absolute_path $key_dir,
  Stdlib::Compat::Absolute_path $crt_dir,
  Stdlib::Compat::Absolute_path $csr_dir,
  Stdlib::Compat::Absolute_path $results_dir,
  Stdlib::Compat::Absolute_path $log_dir,
  Stdlib::Compat::Absolute_path $ocsp_request,
  Array $ca_whitelist,
  Hash $certificates,
  String $date_expression,
  String $default_ca,
  Integer $dh_param_size,
  Integer $dnssleep,
  Integer $exec_timeout,
  String $group,
  Boolean $manage_packages,
  Boolean $ocsp_must_staple,
  String $path,
  String $posthook_cmd,
  Integer $renew_days,
  String $shell,
  String $stat_expression,
  String $user,
  String $wildcard_marker,
  # optional parameters
  Optional[String] $proxy = undef,
  Optional[Hash] $profiles = undef
) {
  require acme::setup

  # Is this the host to sign CSRs?
  if ($::fqdn == $acme_host) {

    # Validate configuration of $acme_host.
    if !($profiles) {
      # Cannot continue if no profile has been defined.
      notify { "Module ${module_name}: \$profiles must be defined on \"${acme_host}\"!":
        loglevel => err,
      }
    } elsif !($accounts) {
      # Cannot continue if no account has been defined.
      notify { "Module ${module_name}: \$accounts must be defined on \"${acme_host}\"!":
        loglevel => err,
      }
    } else {
      class { '::acme::request::handler' :
        require => Class[::acme::setup],
      }
    }
    # Collect certificates.
    if ($facts['acme_crts'] and $facts['acme_crts'] != '') {
      $acme_crts_array = split($facts['acme_crts'], ',')
      ::acme::request::crt { $acme_crts_array: }
    } else {
      notify { 'got no acme_crts from facter (may need another puppet run)': }
    }
  }

  # Generate CSRs.
  $certificates.each |$domain, $config| {
    # Merge domain params with module params.
    $options = deep_merge({
      domain           => $domain,
      acme_host        => $acme_host,
      dh_param_size    => $dh_param_size,
      ocsp_must_staple => $ocsp_must_staple,
    },$config)
    # Create the certificate resource.
    ::acme::certificate { $domain: * => $options }
  }
}
