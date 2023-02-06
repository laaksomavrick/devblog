---
title: Building the World's Most Complicated Blog
date: "2023-02-02T00:00:00.000Z"
description: Or, my experience deploying and operating a static website in AWS with Cloudfront and S3.
---

## What is this and why am I here?

First and foremost: I'll skip any references to ontology with a subtitle like that.

If you've ever worked with me, you've likely listened to me whinge about our (developers) lack of conscientiousness towards how the software we develop is operated. Are the logs any good? Do we expose any metrics? Is the code performant under load? And so forth. Anecdotally, most companies that employ developers make it someone else's problem to deal with whatever the developers produce. Obviously that means we generally do a terrible job of it, and we ought not as an expression of our professional practice.

People smarter than myself have identified this as a problem (and you can probably tell I agree with them). This identification has given rise to a new approach regarding software development team practices called [DevOps](https://en.wikipedia.org/wiki/DevOps). Ignore the fact that colloquially DevOps has become a catch-all aggregate job role for operations, system administration, platform development, cloud development, and whatever you call writing pipelines (yaml configurator?). Ideally, a team practicing this methodology will have engineers work across the entire application lifecycle, from development and test to deployment to operations, and develop a range of skills not limited to a single function [[1]](https://aws.amazon.com/devops/what-is-devops/). 

This sounds great and is a lofty goal for any technical team to achieve. In the pursuit of developing the capability to walk-the-talk, I recently attained a [Solutions Architect – Associate](https://www.credly.com/badges/e056b75f-16ea-4d6d-8f70-b971fb067c59/public_url) certification with Amazon and have an eye towards attaining the [DevOps Engineer - Professional](https://aws.amazon.com/certification/certified-devops-engineer-professional/) certification this year.  

And so, this brings us to our main point: I wanted a project to both crystallize some of what I learned via studying and test taking for the aforementioned certification and to engage in open learning via blogging as a public journal of my professional development. And so, with the intention of using AWS services and industry standard tooling, I made a blog.

## Ok - so you made a blog

Not just any blog though - a _good blog_. But what does that mean? Blogs are meant to be read, and as such we'll want to optimize for SEO. From a technical perspective then, we should prioritize solutions that consider:

* Performance: a blog should be really, really fast to deliver content.
* Accessibility: a blog should be accessible to all users.
* Trustable: a blog should encrypt traffic, not spam users, not engage in dark-pattern UI distractions, and so forth.
* Machine-crawlability: a blog should include all the metadata search engines expect and be crawlable to get higher search rankings. 

Furthermore, I wanted to utilize "best practices" from a DevOps perspective with my technical decisions. And so, to facilitate this: 

* For the blog engine, I chose [Gatsby](https://www.gatsbyjs.com/). Architecting the blog as static content means it's easy to cache and removes the need for any server side infrastructure.
* For operating the blog, I chose [AWS](https://aws.amazon.com/). This is the industry standard for operating services in the cloud. 
* For configuring the infrastructure, I chose [Terraform](https://www.terraform.io/) as an infrastructure-as-code solution. Likewise, the industry standard IaC solution.
* To deploy the blog, I opted to use [Github Actions](https://github.com/features/actions) to set up continuous integration and deployment pipelines. Github is being used for version control already and actions integrates with this well. 


## High level technoblather

Before delving into the details of the terraform declarations, I'd like to give an overview of the services used and how they relate to one another:

* IAM for defining groups and policies to operate the solution
* Route53 for DNS management
* Certificate Manager for provisioning an SSL certificate
* Cloudfront for distributing and caching the blog
* S3 for storing terraform state and blog content
* SNS for publishing events related to operating the blog
* Cloudwatch for acting on events (e.g., alerting)

This will look familiar if you've ever hosted a static website via S3. Everything detailed in this blog post could just as well be applied to a single page application, e.g. a React app.

Visualized, this looks like:

![technoblather's infrastructure diagram](architecture.png)

## The details

Now, let's get into the details. We'll begin with explaining the IAM user administering this account, moving onto the services used from the front to the back of web traffic, ending with a brief overview of how the pipelines are set up. You can find all code referenced in [this github repository](https://github.com/laaksomavrick/devblog).

### Creating an IAM user for the project

You should never use your root account for provisioning resources for a project and instead embrace applying least-privilege permissions [[2]](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html) to an IAM user, group, or role. For this project, I opted to create a separate IAM user with the following default policies attached from my `AdministratorAccess` account. 

* AmazonS3FullAccess
* CloudWatchFullAccess
* CloudFrontFullAccess
* AmazonSNSFullAccess
* AmazonRoute53FullAccess
* AWSCertificateManagerFullAccess

This isn't in the terraform declarations because I needed it prior to writing the terraform declarations (i.e., while I was figuring out how to do all this). In other words, a typical chicken-and-egg problem. In retrospect, I could have used a `AdministratorAccess` designated account to create this IAM user via terraform and then assume the created IAM user for all subsequent commands. But, this was still the experimental stage.

### Authoring the infrastructure (point out gotchas/what you did/why - start from front and go deep)

#### Route53 and Certificate Manager

#### Cloudfront

#### S3

#### Cloudwatch Alarms and SNS

### Authoring the CI/CD pipeline

## So, what's next?

setting up logging, setting up DDoS protection, setting up a staging environment, setting up a budget, more monitoring, ???