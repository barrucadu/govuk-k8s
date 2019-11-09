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

  # todo: use host-based routing inside k8s, rather than exposing
  # ports.
  ports = {
    # router
    www-origin               = 30000;
    # frontend apps
    calculators              = 30001;
    calendars                = 30002;
    collections              = 30003;
    email-alert-frontend     = 30004;
    feedback                 = 30005;
    finder-frontend          = 30006;
    frontend                 = 30007;
    government-frontend      = 30008;
    info-frontend            = 30009;
    licence-finder           = 30010;
    manuals-frontend         = 30011;
    smart-answers            = 30012;
    service-manual-frontend  = 30013;
    static                   = 30014;
    # public APIs
    hmrc-manuals-api         = 30100;
    # publishing apps
    collections-publisher    = 30200;
    contacts-admin           = 30201;
    content-tagger           = 30202;
    content-publisher        = 30203;
    local-links-manager      = 30204;
    manuals-publisher        = 30205;
    maslow                   = 30206;
    publisher                = 30207;
    service-manual-publisher = 30208;
    short-url-manager        = 30209;
    travel-advice-publisher  = 30210;
    whitehall                = 30211;
    # supporting apps
    search-admin             = 30300;
    signon                   = 30301;
    support                  = 30302;
    release                  = 30303;
  };

  live_offset = 1000;

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

    commonHttpConfig = ''
      server_names_hash_bucket_size 128;

      brotli on;
      brotli_comp_level 11;
      brotli_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    '';

    virtualHosts = {
      default = {
        default = true;
        locations."/".extraConfig = "return 421;";
      };

      # govuk apps
      "www-origin.${domain}"                   = govuk_virtualhost ports.www-origin;

      "calculators.${domain}"                  = govuk_virtualhost ports.calculators;
      "calendars.${domain}"                    = govuk_virtualhost ports.calendars;
      "collections.${domain}"                  = govuk_virtualhost ports.collections;
      "email-alert-frontend.${domain}"         = govuk_virtualhost ports.email-alert-frontend;
      "feedback.${domain}"                     = govuk_virtualhost ports.feedback;
      "finder-frontend.${domain}"              = govuk_virtualhost ports.finder-frontend;
      "frontend.${domain}"                     = govuk_virtualhost ports.frontend;
      "government-frontend.${domain}"          = govuk_virtualhost ports.government-frontend;
      "info-frontend.${domain}"                = govuk_virtualhost ports.info-frontend;
      "licence-finder.${domain}"               = govuk_virtualhost ports.licence-finder;
      "manuals-frontend.${domain}"             = govuk_virtualhost ports.manuals-frontend;
      "smart-answers.${domain}"                = govuk_virtualhost ports.smart-answers;
      "service-manual-frontend.${domain}"      = govuk_virtualhost ports.service-manual-frontend;
      "static.${domain}"                       = govuk_virtualhost ports.static;

      "hmrc-manuals-api.${domain}"             = govuk_virtualhost ports.hmrc-manuals-api;

      "collections-publisher.${domain}"        = govuk_virtualhost ports.collections-publisher;
      "contacts-admin.${domain}"               = govuk_virtualhost ports.contacts-admin;
      "content-tagger.${domain}"               = govuk_virtualhost ports.content-tagger;
      "content-publisher.${domain}"            = govuk_virtualhost ports.content-publisher;
      "local-links-manager.${domain}"          = govuk_virtualhost ports.local-links-manager;
      "manuals-publisher.${domain}"            = govuk_virtualhost ports.manuals-publisher;
      "maslow.${domain}"                       = govuk_virtualhost ports.maslow;
      "publisher.${domain}"                    = govuk_virtualhost ports.publisher;
      "service-manual-publisher.${domain}"     = govuk_virtualhost ports.service-manual-publisher;
      "short-url-manager.${domain}"            = govuk_virtualhost ports.short-url-manager;
      "travel-advice-publisher.${domain}"      = govuk_virtualhost ports.travel-advice-publisher;
      "whitehall.${domain}"                    = govuk_virtualhost ports.whitehall;

      "search-admin.${domain}"                 = govuk_virtualhost ports.search-admin;
      "signon.${domain}"                       = govuk_virtualhost ports.signon;
      "support.${domain}"                      = govuk_virtualhost ports.support;
      "release.${domain}"                      = govuk_virtualhost ports.release;

      # live: only frontend apps which can be run against live APIs
      "calculators.live.${domain}"             = govuk_virtualhost (live_offset + ports.calculators);
      "calendars.live.${domain}"               = govuk_virtualhost (live_offset + ports.calendars);
      "collections.live.${domain}"             = govuk_virtualhost (live_offset + ports.collections);
      "finder-frontend.live.${domain}"         = govuk_virtualhost (live_offset + ports.finder-frontend);
      "frontend.live.${domain}"                = govuk_virtualhost (live_offset + ports.frontend);
      "government-frontend.live.${domain}"     = govuk_virtualhost (live_offset + ports.government-frontend);
      "info-frontend.live.${domain}"           = govuk_virtualhost (live_offset + ports.info-frontend);
      "manuals-frontend.live.${domain}"        = govuk_virtualhost (live_offset + ports.manuals-frontend);
      "smart-answers.live.${domain}"           = govuk_virtualhost (live_offset + ports.smart-answers);
      "service-manual-frontend.live.${domain}" = govuk_virtualhost (live_offset + ports.service-manual-frontend);

      # management: administrationy things
      "concourse.management.${domain}"         = govuk_virtualhost 32000;
    };
  };
}
