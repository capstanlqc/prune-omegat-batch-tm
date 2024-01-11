# Create master batch TMs from OmegaT project -- PoC

This repo contains mockup code to prove the concept of a service that would receive parameters (locale, step, space, or just the URL) of a repo hosting an omegat project and would write a batch TM containing the translations for that batch online to a custom folder (e.g. `tasks`) in the omegat project.

The PISA workflow service application could call this service by including the details of the project where this is needed, and then it could fetch the prepared TMs from the `tasks` folder of the repo.

## TODO

Already existing batch TMs would need to be pruned (or produced again in the manner above -- however the same combination of batch/step/locale might need to be artificially creted). TBD.

