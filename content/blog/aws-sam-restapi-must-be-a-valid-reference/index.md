---
title: Decompose AWS SAM API Gateway to Lambda binding declarations
date: "2023-09-25T00:00:00.000Z"
description: Solve "RestApiId must be a valid reference to an 'AWS::Serverless::Api' resource in same template" errors when attempting to DRY up your AWS SAM CloudFormation templates.
---

_Note: this blog post was originally written for my employer, Test Double, in their [blog](https://blog.testdouble.com/posts/2023-09-25-decomposing-aws-sam-templates/)._

As a consultant, our clients often need us to be high-trust partners who solve not only immediate problems but also optimize and improve systems we interact with along the way.
For this particular client engagement, we functioned as the engineering team and source of technical expertise for a multi-hundred-employee business.

In one corner of their business, they had a number of legacy applications functioning as APIs and background jobs to facilitate internal tooling and data synchronization.
These weren't immediately problematic but were finicky to maintain and a constant source of fire-fighting for our team and the business.

Given these were low-traffic services, the infrastructure remained idle the majority of the time.
However, when they were required, they needed to be able to perform in a timely manner.
Furthermore, we were responsible for managing and operating the infrastructure: software updates, security patches, monitoring infrastructure, and so forth.
As a small team, a lot of our effort in owning these services translated to operational overhead instead of business impact.
So - as the problem solvers we are - we wanted to make this better.

Given this context, our team opted to begin migrating this functionality using [serverless](https://aws.amazon.com/serverless/) technologies.
Our APIs would be developed using [API Gateway](https://aws.amazon.com/api-gateway/), and our API handler and background job logic would be developed using [Lambda](https://aws.amazon.com/lambda/) functions.

AWS offers an easy-to-begin on-ramp to provision this infrastructure using infrastructure-as-code and develop functionality with it via the [AWS Serverless Application Model](https://aws.amazon.com/serverless/sam/).
Using this superset on top of [CloudFormation](https://aws.amazon.com/cloudformation/) templates, we would manage our infrastructure and our application code within the same software development lifecycle.

This has met our needs and is still in place as a solution today.

## A common problem

Nothing is perfect, however.

During this transition, as we added more functionality, it soon became time to perform some refactoring.
Our root template included all of our infrastructure components and was quickly becoming burdensome to review and maintain:

```yaml
# https://github.com/laaksomavrick/aws-sam-apigw-lambda-decomposition-example/blob/main/template.yaml

...

Resources:
  ApiGateway:
    Type: AWS::Serverless::Api
    Properties:
      StageName: v1

  HelloWorldFunction:
    Type: AWS::Serverless::Function
    Properties:
      PackageType: Image
      Architectures:
        - x86_64
      Events:
        HelloWorld:
          Type: Api
          Properties:
            RestApiId: !Ref ApiGateway
            Path: /hello
            Method: get
    Metadata:
      DockerTag: nodejs18.x-v1
      DockerContext: ./hello-world
      Dockerfile: Dockerfile
      ...

...a lot of other stuff for the client infrastructure...
```

So, to solve this problem, we wanted to extract common infrastructure components into their own stacks: our root template would be decomposed to reference nested stacks such as `Api`, `Lambda`, `IAM`, and so on.
This would reduce the cognitive burden of navigating the codebase and help us [DRY](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself) up our declarations for common infrastructure components.

So, naturally, we began by separating common components into separate files, for example:

```yaml
# https://github.com/laaksomavrick/aws-sam-apigw-lambda-decomposition-example/blob/refactoring-error/template.yaml

...

Resources:
  ApiGateway:
    Type: AWS::Serverless::Api
    Properties:
      StageName: v1

  Lambdas:
    Type: AWS::Serverless::Application
    Properties:
      Location: lambdas.yaml
      Parameters:
        ApiGateway: !Ref ApiGateway

...

# https://github.com/laaksomavrick/aws-sam-apigw-lambda-decomposition-example/blob/refactoring-error/lambdas.yaml

...

Parameters:
  ApiGateway:
    Type: String
    Description: The ApiGateway identifier

Resources:
  HelloWorldFunction:
    Type: AWS::Serverless::Function
    Properties:
      PackageType: Image
      Architectures:
        - x86_64
      Events:
        HelloWorld:
          Type: Api
          Properties:
            RestApiId: !Ref ApiGateway
            Path: /hello
            Method: get
    Metadata:
      DockerTag: nodejs18.x-v1
      DockerContext: ./hello-world
      Dockerfile: Dockerfile
      ...

...
```

However, on attempting to build this template via `sam build`, the following error was observed:

```
Error: [InvalidResourceException('HelloWorldFunction', "Event with id [HelloWorld] is invalid. RestApiId must be a valid reference to an 'AWS::Serverless::Api' resource in same template.")]
```

Uh-oh.

It appeared that we couldn't separate the API Gateway declaration from the Lambda declarations that backed any API endpoint logic.

So, this meant that we couldn't DRY up our Lambda declarations, and it would disrupt our efforts to compartmentalize our infrastructure declarations.
Furthermore, there is a [resource limit of 500](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/cloudformation-limits.html) for CloudFormation templates, meaning we would eventually encounter this problem again.

So - did we simply have to live with everything being in one template file?

## The official nonsolution

Hope for the best, plan for the worst.

Before conceding defeat and moving on to a different strategy, we wanted to make sure we understood the problem and evaluate whether any workarounds existed.

First, we looked at the documentation for the `AWS::Serverless::Api` [resource](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-property-function-api.html).
As written, the `RestApiId` "...must contain an operation with the given path and method..." and in its absence, "...AWS SAM creates a default AWS::Serverless::Api resource using a generated OpenAPI document. That resource contains a union of all paths and methods defined by API events in the same template that do not specify a RestApiId".

Hmm, okay.

So, there was some code generation internal to AWS SAM that generated a path and method mapping via an OpenAPI document.
Presumptively, that OpenAPI document is used as metadata to map API Gateway endpoints to their respective Lambda function handler.

Digging deeper, we found the following [Github issue](https://github.com/aws/serverless-application-model/issues/349) that mirrored our problem dating back to 2018 (and remains unresolved today).
Moreover, we found an [explanation](https://github.com/aws/serverless-application-model/issues/349#issuecomment-458652439) of why this error occurs (and why it probably won't be addressed in an official capacity).

## An unofficial solution

From both the official documentation on AWS and the community discussion on Github, the core blocker centered around generating an OpenAPI specification to bind endpoints to their respective handlers.
Doing some [documentation spelunking](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-resource-api.html#sam-api-definitionbody), it seemed like we could provide an OpenAPI specification manually via the `DefinitionBody` property on an `AWS::Serverless::Api` resource.

Further, using CloudFormation's macros to [transform](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/intrinsic-function-reference-transform.html) and [include](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/create-reusable-transform-function-snippets-and-add-to-your-template-with-aws-include-transform.html) the specification, we could template this file with the appropriate parameters (AWS region, AWS account id, Lambda function name) and have it uploaded to S3 as part of our deployment process.

This meant, in theory, we could avoid hardcoding any parameters into the OpenAPI specification and retain our existing deployment process without the for of additional tooling (e.g., a separate OpenAPI generation or templating tool).

## A walkthrough of the implementation

So - we moved from ideation to implementation in order to validate whether we could work around this long-standing issue with our proposed solution.

All code is visible from [the given repository and branch](https://github.com/laaksomavrick/aws-sam-apigw-lambda-decomposition-example/tree/refactoring-fix) should you wish to walk through it independently.

### Template root

```yaml
# https://github.com/laaksomavrick/aws-sam-apigw-lambda-decomposition-example/blob/refactoring-fix/template.yaml

---
Resources:
  Api:
    Type: AWS::Serverless::Application
    Properties:
      Location: api.yaml
      Parameters:
        HelloWorldFunctionArn: !GetAtt Lambdas.Outputs.HelloWorldFunctionArn

  Lambdas:
    Type: AWS::Serverless::Application
    Properties:
      Location: lambdas.yaml
```

The root template now referenced the two nested stacks: one for the `Api` related components and the other for the `Lambda` related components.
The `Api` layer required a reference to the Lambda function ARN for interpolation in the OpenAPI specification.

### Api template

```yaml
# https://github.com/laaksomavrick/aws-sam-apigw-lambda-decomposition-example/blob/refactoring-fix/api.yaml

---
Resources:
  ApiGateway:
    Type: AWS::Serverless::Api
    Properties:
      StageName: v1
      DefinitionBody:
        "Fn::Transform":
          Name: "AWS::Include"
          Parameters:
            Location: openapi.yaml

  ApiGatewayExecutionRole:
    Type: AWS::IAM::Role
    Properties:
      AssumeRolePolicyDocument:
        Version: "2012-10-17"
        Statement:
          - Effect: Allow
            Principal:
              Service:
                - apigateway.amazonaws.com
            Action:
              - "sts:AssumeRole"
      Policies:
        - PolicyName: ApiGatewayExecutionPolicy
          PolicyDocument:
            Version: "2012-10-17"
            Statement:
              - Action: lambda:*
                Effect: Allow
                Resource:
                  - Ref: HelloWorldFunctionArn
```

The `Api` template required unraveling and making explicit some of the implicit infrastructure provisioned for us previously.
We had to explicitly define the IAM role for the API Gateway and the OpenAPI specification.
Using `Transform` and `Include` did allow us to upload and template the OpenAPI specification as we had suspected.
This was the trick that allowed us to preserve our existing development and deployment practices (i.e., running `sam build` and `sam deploy`) without introducing new dependencies or complicating the existing practices we had standardized.

### OpenAPI specification

```yaml
# https://github.com/laaksomavrick/aws-sam-apigw-lambda-decomposition-example/blob/refactoring-fix/openapi.yaml

openapi: 3.0.1
info:
  title: sam-app
  version: "1.0"
servers:
  - url: /v1
paths:
  /hello:
    get:
      security:
        - {}
      x-amazon-apigateway-integration:
        credentials:
          Fn::GetAtt:
            - ApiGatewayExecutionRole
            - Arn
        type: aws_proxy
        httpMethod: POST
        uri:
          Fn::Sub: arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${HelloWorldFunctionArn}/invocations
        passthroughBehavior: when_no_match
```

There was enough AWS-specific technobabble in this specification to make discovering it naturally untenable.

In order to create a working example, we scaffolded an API using the GUI and then exported the specification from that API.
From there, we adapted the specification to suit our application and added templating parameters via CloudFormation's interpolation syntax, the visible parameters in our stack, and the visible [pseudo parameters](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/pseudo-parameter-reference.html).

Defining an [x-amazon-apigateway-integration](https://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-swagger-extensions-integration.html) per endpoint binds the API endpoint to a Lambda function, which was the aforementioned code generation being taken care of for us behind the scenes.

### Lambda template

```yaml
# https://github.com/laaksomavrick/aws-sam-apigw-lambda-decomposition-example/blob/refactoring-fix/lambdas.yaml

---
Resources:
  HelloWorldFunction:
    Type: AWS::Serverless::Function
    Properties:
      PackageType: Image
      Architectures:
        - x86_64
    Metadata:
      DockerTag: nodejs18.x-v1
      DockerContext: ./hello-world
      Dockerfile: Dockerfile

Outputs:
  HelloWorldFunctionArn:
    Value: !GetAtt HelloWorldFunction.Arn
```

Our Lambda template remained generally the same aside from the absence of the previous `Events` block per Lambda function.
This was redundant, given the binding between an endpoint and a function was now defined at the `Api` layer of our stack.

### Samconfig update

```toml
# https://github.com/laaksomavrick/aws-sam-apigw-lambda-decomposition-example/blob/refactoring-fix/samconfig.toml

...

[default.deploy.parameters]
capabilities = "CAPABILITY_IAM CAPABILITY_AUTO_EXPAND"

...
```

Last but not least, since we utilized macros in our CloudFormation templates, we had to explicitly declare the `CAPABILITY_AUTO_EXPAND` [capability](https://docs.aws.amazon.com/AWSCloudFormation/latest/APIReference/API_UpdateStack.html) in order to create and update our stack.

## The result

The moment of anticipation.
We were able to successfully build and deploy our stack.
Furthermore, we were able to observe that it was functioning correctly:

```sh
$ curl https://$SOME_ID.execute-api.$SOME_REGION.amazonaws.com/v1/hello
{"message":"hello world"}
```

Woohoo!

## Reflection

After having made this change, we observed some key takeaways.

Our CloudFormation templates became more modular and encapsulated behaviours common to them.
Swapping the implementation of some infrastructure components wasn't a problem as long as the change was conformant to the interfaces we set up between stacks.
With the same reasoning as object-oriented design, this made change management easier and more localized.

Resource limits were no longer a concern in our templates.
If we ever begin to reach the upper bound in a template, refactoring the template now has prior art to learn from and guide the execution.

We gained new capabilities to manage and configure the bindings between API Gateway and Lambda functions.
Defining, for example, mapping templates or integrations with other AWS services (e.g. SQS) was explicit in our OpenAPI specification.

However, one caveat is that debugging failed deployments became more difficult as a result of authoring more nested stacks.
Root stacks only indicate a failure happening somewhere and not the reason for the failure itself.
Finding the cause of an error felt like manually walking a dependency graph - I think there is room for improvement (via tooling or otherwise) here.

On reflection, solving the impossible is my favourite thing about working in technology, and this exercise proved a good experience in that respect.
As a team, we learned a lot about the internals of our chosen tooling and found a solution to a problem many users were and continue to experience. Furthermore, our client has benefited from us investing in our tools and being forward-thinking in our approach.
