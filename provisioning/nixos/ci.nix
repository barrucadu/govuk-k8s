{ config, pkgs, ... }:

let
  cfg = config.govuk-k8s;

  external_domain = "ci.${cfg.externalDomainName}";

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
          CONCOURSE_EXTERNAL_URL: "${if cfg.enableHTTPS then "https" else "http"}://${external_domain}"
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

  services.caddy.enable = true;
  services.caddy.agree  = true; # letsencrypt licence
  services.caddy.email  = config.govuk-k8s.httpsEmail;
  services.caddy.config =
    let
      tls    = if config.govuk-k8s.enableHTTPS then "" else "tls off";
      port   = if config.govuk-k8s.enableHTTPS then "" else ":80";
      scheme = if config.govuk-k8s.enableHTTPS then "" else "http://";
    in
      ''
        ${scheme}${external_domain}${port} {
          gzip
          ${tls}
          proxy / localhost:8080
        }
      '';

  users.extraUsers.concourseci = {
    home = "/srv/concourseci";
    isSystemUser = true;
    extraGroups = [ "docker" ];
  };

  virtualisation.docker = {
    autoPrune.enable = true;
    enable = true;
    extraOptions = "--insecure-registry=registry.govuk-k8s.test:5000";
  };
}
