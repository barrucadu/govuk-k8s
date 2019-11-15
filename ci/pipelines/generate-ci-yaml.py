#!/usr/bin/env python3

import yaml


def git_resource(name, repo=None, branch=None):
    if repo is None:
        repo = f"https://github.com/alphagov/{name}.git"
    if branch is None:
        branch = "deployed-to-production"
    return {
        "name": f"{name}-git",
        "type": "git",
        "source": {"uri": repo, "branch": branch},
    }


def image_resource(name):
    return {
        "name": f"{name}-image",
        "type": "docker-image",
        "source": {
            "repository": f"registry.govuk-k8s.test:5000/{name}",
            "insecure_registries": ["registry.govuk-k8s.test:5000"],
        },
    }


def build_base_image(name, base_image="govuk-base"):
    plan = [{"get": "govuk-base-git"}]
    if base_image:
        plan.append({"get": f"{base_image}-image", "trigger": True})
    plan.append(
        {
            "put": f"{name}-image",
            "params": {
                "build": ".",
                "dockerfile": f"govuk-base-git/ci/docker/Dockerfile.{name}",
                "tag_as_latest": True,
            },
        }
    )
    return {"name": name, "serial": True, "plan": plan}


def build_app(
    name,
    base_image="ruby-2-6-5",
    rake_assets_precompile=True,
    rake_yarn_install=True,
    rails6_initializer=False,
):
    build_args = {"BASE_IMAGE": f"registry.govuk-k8s.test:5000/{base_image}:latest"}
    if rake_assets_precompile:
        build_args["RAKE_ASSETS_PRECOMPILE"] = "true"
    if rake_yarn_install:
        build_args["RAKE_YARN_INSTALL"] = "true"
    if rails6_initializer:
        build_args["RAILS6_INITIALIZER"] = "true"

    return {
        "name": name,
        "serial": True,
        "plan": [
            {"get": "govuk-base-git"},
            {"get": f"{base_image}-image", "trigger": True},
            {"get": f"{name}-git", "trigger": True},
            {
                "put": f"{name}-image",
                "params": {
                    "build": f"{name}-git",
                    "build_args": build_args,
                    "dockerfile": "govuk-base-git/ci/docker/Dockerfile.generic-app",
                    "tag_as_latest": True,
                },
            },
        ],
    }


frontend_apps = [
    "calculators",
    "calendars",
    "collections",
    "finder-frontend",
    "frontend",
    "government-frontend",
    "info-frontend",
    "manuals-frontend",
    "smart-answers",
    "service-manual-frontend",
]

api_apps = ["content-store", "search-api"]

all_apps = frontend_apps + api_apps

extra_job_kwargs = {
    "content-store": {"rake_assets_precompile": False},
    "finder-frontend": {"rails6_initializer": True},
    "search-api": {"rake_assets_precompile": False, "rake_yarn_install": False},
}

pipeline = {
    "resources": [
        git_resource(
            "govuk-base",
            repo="https://github.com/barrucadu/govuk-k8s.git",
            branch="master",
        ),
        image_resource("govuk-base"),
        image_resource("ruby-2-6-5"),
        image_resource("fake-router"),
    ],
    "jobs": [
        build_base_image("govuk-base", base_image=None),
        build_base_image("ruby-2-6-5"),
        {
            "name": "fake-router",
            "serial": True,
            "plan": [
                {"get": "govuk-base-git"},
                {
                    "put": f"fake-router-image",
                    "params": {
                        "build": "govuk-base-git/util/fake-router",
                        "tag_as_latest": True,
                    },
                },
            ],
        },
    ],
    "groups": [
        {"name": "CI", "jobs": ["govuk-base", "ruby-2-6-5"]},
        {"name": "Frontend", "jobs": frontend_apps},
        {"name": "API", "jobs": api_apps},
        {"name": "Miscellaneous", "jobs": ["fake-router"]},
    ],
}

for app in all_apps:
    pipeline["resources"].append(git_resource(app))
    pipeline["resources"].append(image_resource(app))
    pipeline["jobs"].append(build_app(app, **extra_job_kwargs.get(app, {})))

print(yaml.dump(pipeline, Dumper=yaml.Dumper))
