# request crt using acme.sh
define acme::crt (
  String $domain = $name
){
  # acme.sh configuration
  $acme_dir = $acme::acme_dir
  $crt_dir = $acme::crt_dir
  $results_dir = $acme::results_dir
  $ocsp_file = "${results_dir}/${domain}.ocsp"
  $cfg_dir = $acme::cfg_dir
  $key_dir = $acme::key_dir
  $user = $acme::user
  $group = $acme::group

  # Places where acme.sh stores the resulting certificate.
  $le_crt_file = "${acme_dir}/${domain}/${domain}.cer"
  $le_chain_file = "${acme_dir}/${domain}/ca.cer"
  $le_fullchain_file = "${acme_dir}/${domain}/fullchain.cer"

  # Avoid special characters (required for wildcard certs)
  $domain_rep = regsubst($domain, /[*.-]/, {'.' => '_', '-' => '_', '*' => $acme::wildcard_marker}, 'G')
  $domain_tag = regsubst($domain, /[*]/, $acme::wildcard_marker, 'G')

  $crt_content = pick_default($facts["acme_crt_${domain_rep}"], '')

  # special handling for ocsp stuff (binary data)
  $ocsp_content = base64('encode', file_or_empty_string($ocsp_file))

  $crt_chain_content = pick_default($facts["acme_ca_${domain_rep}"], '')

  # Bring back special characters (required for wildcard certs)
  $real_domain = regsubst($domain, $acme::wildcard_marker, '*', 'G')

  $crt = "${crt_dir}/${real_domain}/cert.pem"
  $ocsp = "${crt_dir}/${real_domain}/cert.ocsp"
  $key = "${key_dir}/${real_domain}/private.key"
  $dh = "${cfg_dir}/${real_domain}/params.dh"
  $crt_chain = "${crt_dir}/${real_domain}/chain.pem"
  $crt_full_chain = "${crt_dir}/${real_domain}/fullchain.pem"
  $crt_full_chain_with_key = "${key_dir}/${real_domain}/fullchain_with_key.pem"

  file { $crt:
    ensure  => file,
    owner   => 'root',
    group   => $group,
    content => "${crt_content}\n",
    mode    => '0644',
  }

  if !empty($ocsp_content) {
    file { $ocsp:
      ensure  => file,
      owner   => 'root',
      group   => $group,
      content => base64('decode', $ocsp_content),
      mode    => '0644',
    }
  } else {
    file { $ocsp:
      ensure => absent,
      force  => true,
    }
  }

  concat { $crt_full_chain:
    owner => 'root',
    group => $group,
    mode  => '0644',
  }

  concat { $crt_full_chain_with_key:
    owner => 'root',
    group => $group,
    mode  => '0640',
  }

  concat::fragment { "${real_domain}_key" :
    target => $crt_full_chain_with_key,
    source => $key,
    order  => '01',
  }

  concat::fragment { "${real_domain}_fullchain":
    target    => $crt_full_chain_with_key,
    source    => $crt_full_chain,
    order     => '10',
    subscribe => Concat[$crt_full_chain],
  }

  concat::fragment { "${real_domain}_crt":
    target  => $crt_full_chain,
    content => "${crt_content}\n",
    order   => '10',
  }

  concat::fragment { "${real_domain}_dh":
    target => $crt_full_chain,
    source => $dh,
    order  => '30',
  }

  if ($crt_chain_content and $crt_chain_content =~ /BEGIN CERTIFICATE/) {
    file { $crt_chain:
      ensure  => file,
      owner   => 'root',
      group   => $group,
      content => $crt_chain_content,
      mode    => '0644',
    }
    concat::fragment { "${real_domain}_ca":
      target  => $crt_full_chain,
      content => $crt_chain_content,
      order   => '50',
    }
  } else {
    file { $crt_chain:
      ensure => absent,
      force  => true,
    }
  }
}
