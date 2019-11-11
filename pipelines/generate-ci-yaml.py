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


def job(name):
    return {
        "name": name,
        "serial": True,
        "plan": [
            {"get": "govuk-base-git"},
            {"get": "govuk-base-image", "trigger": True},
            {"get": f"{name}-git", "trigger": True},
            {
                "put": f"{name}-image",
                "params": {
                    "build": f"{name}-git",
                    "dockerfile": "govuk-base-git/docker/Dockerfile.generic-app",
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

pipeline = {
    "resources": [
        git_resource(
            "govuk-base", repo="https://github.com/barrucadu/govuk-k8s.git", branch="ci"
        ),
        image_resource("govuk-base"),
    ],
    "jobs": [
        # different enough to job() to not be worth function-ising.
        {
            "name": "govuk-base",
            "serial": True,
            "plan": [
                {"get": "govuk-base-git"},
                {
                    "put": "govuk-base-image",
                    "params": {
                        "build": ".",
                        "dockerfile": "govuk-base-git/docker/Dockerfile.govuk-base",
                        "tag_as_latest": True,
                    },
                },
            ],
        }
    ],
    "groups": [
        {"name": "CI", "jobs": ["govuk-base"]},
        {"name": "Frontend", "jobs": frontend_apps},
    ],
}

for app in frontend_apps:
    pipeline["resources"].append(git_resource(app))
    pipeline["resources"].append(image_resource(app))
    pipeline["jobs"].append(job(app))

print(yaml.dump(pipeline, Dumper=yaml.Dumper))
