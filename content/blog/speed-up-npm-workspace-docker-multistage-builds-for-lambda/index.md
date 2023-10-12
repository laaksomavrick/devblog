---
title: Speeding up Docker builds for Node.js Lambda functions
date: "2023-10-12T00:00:00.000Z"
description: Decrease your Docker build times with a few lines worth of code changes by 1000% (more or less).
---

Docker's ubiquity presently is not without warrant: pretty much every deployment process I've seen in the past five years of my career has leveraged it to generate images for deployments.
Amazon's ECS, Google's Cloud Run, and Kubernetes in general all have images and containers at their core. 
So, accordingly, my present project (a serverless backend leveraging AWS Lambda) uses Docker to package the functions that are invoked.

This generally works great - what we author in our local environments corresponds to what we see in our cloud development environments, in staging, and in production.
Our typical developer lifecycle is to author a change locally, test it locally, deploy the image to an image repository, and then use that image to deploy a container to a dev cloud environment to validate the changes in a serverless environment.
However, one component of this kept bothering me.

Docker builds can be *slow*.
Particularly on this project, making a change could take upwards of a few minutes when rebuilding the Docker image to then deploy a container to a dev cloud environment.
So, make a change, and then break your flow until the build finishes.
With some downtime between tasks, I wanted to fix this to improve the developer experience of this project.

## Getting the lay of the land

Iterative improvement is the name of the game, so rather than accepting a slow `Dockerfile`, I wanted to understand what the problem was and then investigate how to resolve it.
The codebase I was working in contained a large number of Lambda functions and their source code with their dependencies managed via [npm workspaces](https://docs.npmjs.com/cli/v10/using-npm/workspaces?v=true).
Further, a `common` module provided shared functionality across the codebase: writing to a database, making API calls, processing errors, and so forth.

```shell
$ tree .
.
├── Dockerfile
├── package-lock.json
├── package.json
├── src
│   ├── common
│   │   ├── module1.js
│   │   ├── module2.js
│   │   ├── package.json
│   │   ├── src
│   │   │   ├── module1
│   │   │   │   └── index.js
│   │   │   ├── module2
│   │   │   │   ├── index.js
│   ├── lambda1
│   │   ├── app.js
│   │   ├── package.json
│   │   └── src
│   │       ├── handler.js
│   │       ├── handler.spec.js
│   │       └── index.js
│   ├── lambda2
│   │   ├── app.js
│   │   ├── package.json
│   │   └── src
│   │       ├── handler.js
│   │       ├── handler.spec.js
│   │       └── index.js
```

Our Dockerfile copied in the relevant Lambda source and the common directory, installed the dependencies, ran a build with `esbuild`, and copied the output artifacts into the deployment image: 

```Dockerfile
ARG LAMBDA_DIRECTORY_NAME

# Builder image
FROM public.ecr.aws/lambda/nodejs:18 as builder
ARG LAMBDA_DIRECTORY_NAME
WORKDIR ${LAMBDA_TASK_ROOT}

RUN npm install -g npm@9

COPY package.json package.json
COPY package-lock.json package-lock.json
COPY src/common src/common
COPY src/${LAMBDA_DIRECTORY_NAME} src/${LAMBDA_DIRECTORY_NAME}

RUN npm ci
RUN LAMBDA_DIRECTORY_NAME=${LAMBDA_DIRECTORY_NAME} npm run build

# Deployment image
FROM public.ecr.aws/lambda/nodejs:18
ARG LAMBDA_DIRECTORY_NAME
WORKDIR ${LAMBDA_TASK_ROOT}

COPY --from=builder ${LAMBDA_TASK_ROOT}/src/${LAMBDA_DIRECTORY_NAME}/dist ${LAMBDA_TASK_ROOT}/dist

ENTRYPOINT /lambda-entrypoint.sh dist/app.lambdaHandler
```

## Like an onion

A docker image is [a set of layers](https://docs.docker.com/build/guide/layers/), with each instruction in the `Dockerfile` generally translating to a new layer.
Docker caches these layers on repeated builds and does its best to rebuild only what has been changed, making your build faster.
This is like an ordered list, a dependency chain, or an onion (if you prefer).
Changing a file that is referenced in the first instruction (at the start of the list) of your Dockerfile means everything after must be rebuilt.
Changing a file that is referenced in the last instruction (at the end of the list)  of your Dockerfile means only that instruction must be re-invoked.

So, I wanted to know where the time was being spent in building the image.
Using the `docker buildx build` command, I was able to see the amount of time spent running each instruction:

```shell
$ docker buildx build --build-arg LAMBDA_DIRECTORY_NAME=lambda1 .
[+] Building 34.2s (14/15)
 => [internal] load build definition from Dockerfile                                                                                           0.0s
 => => transferring dockerfile: 721B                                                                                                           0.0s
 => [internal] load .dockerignore                                                                                                              0.0s
 => => transferring context: 2B                                                                                                                0.0s
 => [internal] load metadata for public.ecr.aws/lambda/nodejs:18                                                                              30.2s
 => [internal] load build context                                                                                                              0.1s
 => => transferring context: 1.43MB                                                                                                            0.1s
 => [builder 1/9] FROM public.ecr.aws/lambda/nodejs:18@sha256:50f22b7077c7fbb7be2720fb228462e332850a4cd48b4132ffc3c171603ab191                 0.0s
 => CACHED [builder 2/9] WORKDIR /var/task                                                                                                     0.0s
 => [builder 3/9] RUN npm install -g npm@9                                                                                                     5.1s
 => [builder 4/9] COPY package.json package.json                                                                                               0.0s
 => [builder 5/9] COPY package-lock.json package-lock.json                                                                                     0.0s
 => [builder 6/9] COPY src/common src/common                                                                                                   0.0s
 => [builder 7/9] COPY src/lambda1 src/lambda1                                                                                                 0.0s
 => [builder 8/9] RUN npm ci                                                                                                                  29.1s
 => [builder 9/9] RUN LAMBDA_DIRECTORY_NAME=lambda1 npm run build                                                                              0.6s
 => [stage-1 3/3] COPY --from=builder /var/task/src/lambda1/dist /var/task/dist                                                                0.0s
 => exporting to image                                                                                                                         0.0s
 => => exporting layers                                                                                                                        0.0s
 => => writing image sha256:a8095a1267ddf2a08d53525231565087e1d575a38b41eb9c6eddb331d977c591                                                   0.0s
```

## The problem

It looked like the bulk of our time was spent running `npm ci`.
The bulk of our logic lived in our `common` directory, so that was the code that most frequently changed.
And, whenever we made a change to `common`, our `npm ci` build instruction was re-executed.
Further, since `common` functions as a shared library across our code, and this `Dockerfile` was common to all our Lambda functions, any dependent Lambdas would also have to be rebuilt in order to deploy.

So, every time we made a code change in `common`, for every Lambda, we had to re-invoke `npm ci`, leading to our slow builds. 

## The solution

Remember how Docker is like an onion?
We only needed to re-execute `npm ci` when a dependency was added, modified, or changed.
So, modifying our `Dockerfile` to copy `package.json` and `package-lock.json`, executing the `npm ci` step, and then copying over our source code should result in the slow step being cached for our general case (modifying `common`). 
We can observe this change from the following Dockerfile:

```Dockerfile
ARG LAMBDA_DIRECTORY_NAME

# Builder image
FROM public.ecr.aws/lambda/nodejs:18 as builder

ARG LAMBDA_DIRECTORY_NAME

WORKDIR ${LAMBDA_TASK_ROOT}

RUN npm install -g npm@9

COPY package.json package-lock.json ./
COPY src/common/package.json src/common/package.json
COPY src/${LAMBDA_DIRECTORY_NAME}/package.json src/${LAMBDA_DIRECTORY_NAME}/package.json

RUN npm ci

COPY src/common/src src/common/src
COPY src/common/module1.js \
     src/common/module2.js \
     ./src/common/

COPY src/${LAMBDA_DIRECTORY_NAME}/src src/${LAMBDA_DIRECTORY_NAME}/src/
COPY src/${LAMBDA_DIRECTORY_NAME}/app.js src/${LAMBDA_DIRECTORY_NAME}/

RUN LAMBDA_DIRECTORY_NAME=${LAMBDA_DIRECTORY_NAME} npm run build

# Deployment image
FROM public.ecr.aws/lambda/nodejs:18

ARG LAMBDA_DIRECTORY_NAME

WORKDIR ${LAMBDA_TASK_ROOT}

COPY --from=builder ${LAMBDA_TASK_ROOT}/src/${LAMBDA_DIRECTORY_NAME}/dist ${LAMBDA_TASK_ROOT}/dist

ENTRYPOINT /lambda-entrypoint.sh dist/app.lambdaHandler
```

## The results

Installing a new dependency still required rerunning `npm ci`, meaning it took a second (or thirty of them more often).
However, modifying code in `common` did not trigger `npm ci` anymore.
So, we could author and deploy code changes to our dev cloud environment much more quickly and not break our flow state as a result:

```Dockerfile
$ docker buildx build --build-arg LAMBDA_DIRECTORY_NAME=lambda1 .
[+] Building 0.5s (18/19)
 => [internal] load build definition from Dockerfile                                                                                           0.0s
 => => transferring dockerfile: 1.29kB                                                                                                         0.0s
 => [internal] load .dockerignore                                                                                                              0.0s
 => => transferring context: 2B                                                                                                                0.0s
 => [internal] load metadata for public.ecr.aws/lambda/nodejs:18                                                                               0.4s
 => [builder  1/13] FROM public.ecr.aws/lambda/nodejs:18@sha256:50f22b7077c7fbb7be2720fb228462e332850a4cd48b4132ffc3c171603ab191               0.0s
 => [internal] load build context                                                                                                              0.1s
 => => transferring context: 475.68kB                                                                                                          0.0s
 => CACHED [builder  2/13] WORKDIR /var/task                                                                                                   0.0s
 => CACHED [builder  3/13] RUN npm install -g npm@9                                                                                            0.0s
 => CACHED [builder  4/13] COPY package.json package-lock.json ./                                                                              0.0s
 => CACHED [builder  5/13] COPY src/common/package.json src/common/package.json                                                                0.0s
 => CACHED [builder  6/13] COPY src/lambda1/package.json src/lambda1/package.json                                                              0.0s
 => CACHED [builder  7/13] RUN npm ci                                                                                                          0.0s
 => CACHED [builder  8/13] COPY src/common/config src/common/config                                                                            0.0s
 => CACHED [builder  9/13] COPY src/common/src src/common/src                                                                                  0.0s
 => CACHED [builder 10/13] COPY src/common/module1.js      src/common/module2.js       src/common                                              0.0s
 => [builder 11/13] COPY src/lambda1/src src/lambda1/src/                                                                                      0.0s
 => [builder 12/13] COPY src/lambda1/app.js src/lambda1/                                                                                       0.0s
 => [builder 13/13] RUN LAMBDA_DIRECTORY_NAME=lambda1 npm run build                                                                            0.9s
 => [stage-1 3/3] COPY --from=builder /var/task/src/lambda1/dist /var/task/dist                                                                0.0s
 => exporting to image                                                                                                                         0.0s
 => => exporting layers                                                                                                                        0.0s
 => => writing image sha256:716193841c31688bfd4a4b08f81735accb2d5f047c9d33fd1d31461b935ecfe4                                                   0.0s
```

Devs are happiest when they're working and not waiting, so I considered this a win for our team's health and for our productivity.
If you're suffering from slow builds, I invite you to examine your Dockerfiles and think about how to order the instructions to optimize for caching slow steps.