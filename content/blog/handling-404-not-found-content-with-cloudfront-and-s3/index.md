---
title: Fixing 404/403 Errors in Cloudfront and S3
date: "2023-02-12T00:00:00.000Z"
description: Solving AccessDenied errors being surfaced to your users.
---

I noticed (read: Google's SEO tooling did for me) this ugly error message being surfaced to readers when visiting URLs that don't exist on [technoblather](/building-a-blog-in-aws):

```xml
<Error>
    <Code>AccessDenied</Code>
    <Message>Access Denied</Message>
    <RequestId>3DJ33MVM7989SSXH</RequestId>
    <HostId>SomeBase64String</HostId>
</Error>
```

The S3 bucket hosting technoblather was (correctly) forbidding access to content that didn't exist. However, it should have been returning a `404` instead of a `403` so the Cloudfront error response handling could correctly show a generic `Not Found` page.

A couple potential solutions presented themselves after research:

- Creating a [routing rule](https://docs.aws.amazon.com/AmazonS3/latest/userguide/how-to-page-redirect.html) in S3 to redirect to the `404.html` page
- Creating a [Cloudfront function](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-functions.html) to intercept responses and handle them appropriately

Neither of these seemed ideal.

Using a routing rule would lead to making the bucket hosting technoblather publicly accessible - something I explicitly did not want to happen. All traffic should go through Cloudfront such that it's cached and served through a CDN. Given that, only Cloudfront should be able to access the bucket.

Using a Cloudfront function could work. The function would check if a `403` status code is present on responses and redirect to the `404` path.
But, that would create a side effect: all forbidden responses would be treated as not found responses, which won't always be the case. I have plans to make an admin console for administering technoblather and as such want to preserve a distinction between these two errors.

So, I examined the [origin access identity](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html) configured between Cloudfront and S3:

```json
{
  "Version": "2012-10-17",
  "Statement": {
    "Sid": "AllowCloudFrontServicePrincipalReadOnly",
    "Effect": "Allow",
    "Principal": {
      "Service": "cloudfront.amazonaws.com"
    },
    "Action": "s3:GetObject",
    "Resource": "arn:aws:s3:::${bucket}/*",
    "Condition": {
      "StringEquals": {
        "AWS:SourceArn": "${cloudfront_arn}"
      }
    }
  }
}
```

On [doing some research](https://stackoverflow.com/questions/19037664/how-do-i-have-an-s3-bucket-return-404-instead-of-403-for-a-key-that-does-not-e), I modified the origin access identity to allow for Cloudfront to have `ListBucket` rights:

```json
{
  "Version": "2012-10-17",
  "Statement": {
    "Sid": "AllowCloudFrontServicePrincipalReadOnly",
    "Effect": "Allow",
    "Principal": {
      "Service": "cloudfront.amazonaws.com"
    },
    "Action": ["s3:GetObject", "s3:ListBucket"],
    "Resource": ["arn:aws:s3:::${bucket}/*", "arn:aws:s3:::${bucket}"],
    "Condition": {
      "StringEquals": {
        "AWS:SourceArn": "${cloudfront_arn}"
      }
    }
  }
}
```

This fixed the issue without having to make the blog bucket public and without having to write some non-standard logic to handle the error.
