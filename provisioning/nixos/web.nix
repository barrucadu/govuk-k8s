{ config, pkgs, ... }:

let
  nginx_with_brotli = pkgs.nginx.override {
    modules = [
      pkgs.nginxModules.brotli
    ];
  };

  govuk_virtualhost = port: {
    enableACME = config.govuk-k8s.enableHTTPS;
    forceSSL   = config.govuk-k8s.enableHTTPS && config.govuk-k8s.forceHTTPS;
    # todo: put a load balancer in front of the slaves and use that
    locations."/".proxyPass = "http://k8s-slave-0.govuk-k8s.test:${toString port}";
  };

  domain = "web.${config.govuk-k8s.externalDomainName}";
in
{
  imports = [ ./common.nix ];

  networking.hostName = "web.govuk-k8s.test";

  services.nginx = {
    enable = true;
    package = nginx_with_brotli;

    recommendedGzipSettings  = true;
    recommendedOptimisation  = true;
    recommendedProxySettings = true;
    recommendedTlsSettings   = true;

    appendHttpConfig = ''
      brotli on;
      brotli_comp_level 11;
      brotli_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    '';

    virtualHosts = {
      default = {
        default = true;
        locations."/".extraConfig = "return 421;";
      };

      "www-origin.${domain}" = govuk_virtualhost 30000;
    };
  };
}
