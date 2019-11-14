{ config, pkgs, ... }:

let
  nginx_with_brotli = pkgs.nginx.override {
    modules = [
      pkgs.nginxModules.brotli
    ];
  };

  cfg = config.govuk-k8s;

  domain = "ci.${cfg.externalDomainName}";

  externalURL = "${if cfg.enableHTTPS then "https" else "http"}://${domain}";

  dockerComposeFile = pkgs.writeText "docker-compose.yml" ''
    version: '3'
    services:
      concourse:
        image: concourse/concourse
        command: quickstart
        privileged: true
        depends_on: [postgres]
        ports: ["127.0.0.1:8080:8080"]
        environment:
          CONCOURSE_POSTGRES_HOST: postgres
          CONCOURSE_POSTGRES_USER: concourse
          CONCOURSE_POSTGRES_PASSWORD: concourse
          CONCOURSE_POSTGRES_DATABASE: concourse
          CONCOURSE_EXTERNAL_URL: "${externalURL}"
          CONCOURSE_MAIN_TEAM_GITHUB_USER: "${cfg.concourseGithubUser}"
          CONCOURSE_GITHUB_CLIENT_ID: "${cfg.concourseGithubClientId}"
          CONCOURSE_GITHUB_CLIENT_SECRET: "${cfg.concourseGithubClientSecret}"
          CONCOURSE_LOG_LEVEL: error
          CONCOURSE_GARDEN_LOG_LEVEL: error
      postgres:
        image: postgres
        environment:
          POSTGRES_DB: concourse
          POSTGRES_PASSWORD: concourse
          POSTGRES_USER: concourse
          PGDATA: /database
        volumes:
          - pgdata:/database
    volumes:
      pgdata:
  '';
in

{
  imports = [ ./common.nix ];

  systemd.services.concourseci = {
    enable   = true;
    wantedBy = [ "multi-user.target" ];
    requires = [ "docker.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' up";
      ExecStop  = "${pkgs.docker_compose}/bin/docker-compose -f '${dockerComposeFile}' down";
      Restart   = "always";
      User      = "concourseci";
    };
  };

  services.nginx = {
    enable = true;
    package = nginx_with_brotli;

    recommendedGzipSettings  = true;
    recommendedOptimisation  = true;
    recommendedProxySettings = true;
    recommendedTlsSettings   = true;

    commonHttpConfig = ''
      brotli on;
      brotli_comp_level 11;
      brotli_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    '';

    virtualHosts."${domain}" = {
      enableACME = cfg.enableHTTPS;
      forceSSL   = cfg.enableHTTPS && cfg.forceHTTPS;
      locations."/" = {
        proxyPass = "http://localhost:8080/";
        proxyWebsockets = true;
      };
    };
  };

  users.extraUsers.concourseci = {
    home = "/srv/concourseci";
    isSystemUser = true;
    extraGroups = [ "docker" ];
  };

  virtualization.docker.enable = true;
}
