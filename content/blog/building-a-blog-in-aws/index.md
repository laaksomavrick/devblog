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

You should never use your root account for provisioning resources for a project and instead embrace applying least-privilege permissions  to an IAM user, group, or role [[2]](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html). For this project, I opted to create a separate IAM user with the following amazon managed policies attached from my `AdministratorAccess` account. 

* AmazonS3FullAccess
* CloudWatchFullAccess
* CloudFrontFullAccess
* AmazonSNSFullAccess
* AmazonRoute53FullAccess
* AWSCertificateManagerFullAccess

This isn't in the terraform declarations because I needed it prior to writing the terraform declarations (i.e., while I was figuring out how to do all this). In other words, a typical chicken-and-egg problem. In retrospect, I could have used a `AdministratorAccess` designated account to create this IAM user via terraform and then assume the created IAM user for all subsequent commands. But, this was still the experimental stage.

### Authoring the infrastructure (point out gotchas/what you did/why - start from front and go deep)

Prepare yourself for lots of [HCL](https://developer.hashicorp.com/terraform/language/syntax/configuration).

We'll start with the module entry point (`main.tf`), my provider declarations (`aws.tf`), and my terraform variables (`variables.tf`)

```terraform
# main.tf

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  backend "s3" {
    bucket = "technoblather-terraform"
    key    = "tfstate"
    region = "ca-central-1"
  }

  required_version = ">= 1.2.0"
}
```

I opted to use `ca-central-1` everywhere I could since I live nowhere close to Toronto. You'll see shortly that this led to a few gotchas related to certificate management and Cloudfront.

```terraform
# aws.tf

provider "aws" {
  region                   = "ca-central-1"
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "technoblather"
}

provider "aws" {
  alias  = "acm_provider"
  region = "us-east-1"
}
```

Aforementioned solution to the gotchas - the latter aws provider block specifies `us-east-1` for services that aren't operable outside that region [[3]](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cnames-and-https-requirements.html). Basically, you need to use `us-east-1` to set up SSL with Cloudfront.

```terraform
# variables.tf

variable "domain_name" {
  type        = string
  description = "The domain name for the website."
}

variable "bucket_name" {
  type        = string
  description = "The name of the bucket without the www. prefix. Normally domain_name."
}

variable "common_tags" {
  description = "Common tags you want applied to all components."
}

variable "alert_emails" {
  type        = list(string)
  description = "A list of emails for alerting via cloudwatch alarms."
}
```

No surprises here. One good practice I adopted was issuing a uniform set of tags for each resource since it made winnowing down billing for this project easier, e.g.:

```terraform
common_tags = {
  Project = "technoblather"
}
```


#### Route53 and Certificate Manager

Moving onto DNS. The vast majority of my career has been in development, so DNS and SSL are one of those things I've skimmed a how-to as little as possible and moved on. Trying to make amends here - I have a few hobby projects I operate now (sole user) and know the difference between an `A` record and a `CNAME`. Also smart enough to delegate certificate renewal to an automated process or a service.  

```terraform
# route53.tf

resource "aws_route53_zone" "main" {
  name = var.domain_name
  tags = var.common_tags
}

resource "aws_route53_record" "root-a" {
  zone_id = aws_route53_zone.main.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.root_s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.root_s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "www-a" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "www.${var.domain_name}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.www_s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.www_s3_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

resource "aws_route53_record" "main" {
  for_each = {
    for dvo in aws_acm_certificate.ssl_certificate.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = aws_route53_zone.main.zone_id
}
```

Here, we have two declarations for `A` records (`www.technoblather.ca` and `technoblather.ca`) which lets Route53 handle requests for our domain and traffic them to the appropriate service (Cloudfront).

You'll notice a recurring duplication between a `www` resource and a `root` resource as we proceed down the service stack. This is because I needed two buckets in order to handle url redirection [[4]](https://docs.aws.amazon.com/AmazonS3/latest/userguide/how-to-page-redirect.html#redirect-endpoint-host). I didn't want a request to `technoblather.ca` to result in a `404`, so `root` functions as a redirect to my `www` bucket.


```terraform
# acm.tf

resource "aws_acm_certificate" "ssl_certificate" {
  provider                  = aws.acm_provider
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  tags = var.common_tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "cert_validation" {
  provider                = aws.acm_provider
  certificate_arn         = aws_acm_certificate.ssl_certificate.arn
  validation_record_fqdns = [for record in aws_route53_record.main : record.fqdn]
}
```

Here we're setting up SSL for our domain name. This is almost verbatim copied from [the terraform documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation). Setting up DNS validation is recommended and was easier than trying to register a mail server for my domain.

#### Cloudfront

#### S3

#### Cloudwatch Alarms and SNS

### Authoring the CI/CD pipeline

## So, what's next?

setting up logging, setting up DDoS protection, setting up a staging environment, setting up a budget, more monitoring, ???