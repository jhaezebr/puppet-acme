# @summary Gather all data and use acme.sh to create accounts and sign certificates.
#
# @api private
class acme::request::handler {
  File {
    owner => 'root',
    group => 0,
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
