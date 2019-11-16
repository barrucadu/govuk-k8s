{ config, lib, pkgs, ... }:

let
  external_domain = "web.${config.govuk-k8s.externalDomainName}";

  proxy_to = namespace: host: app:
    let tls = if config.govuk-k8s.enableHTTPS then "" else "tls off";
        # with `tls off` caddy doesn't change the default port
        port = if config.govuk-k8s.enableHTTPS then "" else ":80";
        proxy_cfg = scheme: ''
          ${scheme}${host}.${namespace}.${external_domain}${port} {
            gzip
            ${tls}
            proxy / ${app}.${namespace}.in-cluster.govuk-k8s.test:80
          }
    '';
    in ''
      ${proxy_cfg ""}
      ${if config.govuk-k8s.forceHTTPS then "" else proxy_cfg "http://"}
    '';

  proxy = namespace: app: proxy_to namespace app app;
in
{
  imports = [ ./common.nix ];

  services.caddy.enable = true;
  services.caddy.agree  = true; # letsencrypt licence
  services.caddy.email  = config.govuk-k8s.httpsEmail;
  services.caddy.config = ''
    ${proxy_to "live"  "www-origin" "fake-router"}
    ${proxy_to "govuk" "www-origin" "router"}

    ${proxy "live" "calculators"}
    ${proxy "live" "calendars"}
    ${proxy "live" "collections"}
    ${proxy "live" "finder-frontend"}
    ${proxy "live" "frontend"}
    ${proxy "live" "government-frontend"}
    ${proxy "live" "info-frontend"}
    ${proxy "live" "manuals-frontend"}
    ${proxy "live" "smart-answers"}
    ${proxy "live" "service-manual-frontend"}

    ${proxy "govuk" "calculators"}
    ${proxy "govuk" "calendars"}
    ${proxy "govuk" "collections"}
    ${proxy "govuk" "email-alert-frontend"}
    ${proxy "govuk" "feedback"}
    ${proxy "govuk" "finder-frontend"}
    ${proxy "govuk" "frontend"}
    ${proxy "govuk" "government-frontend"}
    ${proxy "govuk" "info-frontend"}
    ${proxy "govuk" "licence-finder"}
    ${proxy "govuk" "manuals-frontend"}
    ${proxy "govuk" "smart-answers"}
    ${proxy "govuk" "service-manual-frontend"}
    ${proxy "govuk" "static"}
    ${proxy "govuk" "hmrc-manuals-api"}
    ${proxy "govuk" "collections-publisher"}
    ${proxy "govuk" "contacts-admin"}
    ${proxy "govuk" "content-tagger"}
    ${proxy "govuk" "content-publisher"}
    ${proxy "govuk" "local-links-manager"}
    ${proxy "govuk" "manuals-publisher"}
    ${proxy "govuk" "maslow"}
    ${proxy "govuk" "publisher"}
    ${proxy "govuk" "service-manual-publisher"}
    ${proxy "govuk" "short-url-manager"}
    ${proxy "govuk" "travel-advice-publisher"}
    ${proxy "govuk" "whitehall"}
    ${proxy "govuk" "search-admin"}
    ${proxy "govuk" "signon"}
    ${proxy "govuk" "support"}
    ${proxy "govuk" "release"}
  '';
}
