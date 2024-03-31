---
title: "Reflections on Building and Running a Machine Learning Recommendation System as a Web Service in AWS"
date: "2024-04-01T00:00:00.000Z"
description: Learn from my efforts building and operating a machine learning-based recommendation system using Scikit-Learn, AWS SageMaker, and GitHub Actions.
---

It's no secret technology circles are currently experiencing peak levels of hype regarding AI and machine learning.
If you're reading this blog post, you likely know from your anecdotal experience: ChatGPT can more often than not write acceptable code snippets and DALL·E's image engine can generate uninspired but highly useful reproductions.

Further, every quarter brings forth new capabilties, expansions, and utilizations of the core technologies backing these models.
So, maybe the hype is [somewhat justified](https://www.google.com/finance/quote/NVDA:NASDAQ?window=6M).
I am not smart enough to know for sure.
But, with its collective capture of our attention, I do know its certain to be useful to learn something about the capabilities AI offers and the techniques we can leverage as software developers to capitalize. 

And so, as is my typical pattern, I wanted to build a hobby project end-to-end leveraging AI and/or machine learning to solve a small problem and learn something along the way. 

I settled on developing [a recommendation engine to recommend television shows](https://canihasashowplz.com/) based on input user preferences, given:

- I thought it would be fun to build something that could help my spouse and I choose a new television show to watch in the evenings.
- Recommendation engines are a feature I used in my daily life in my software products: Spotify's music recommendations, Amazon's product recommendations, the gajillion ads I am served which I do my best to block, and so on.
- A large public data set exists for movies, but not television shows, so I knew I would have to get the data myself, and I wanted an end-to-end experience.

With that in mind, this blog post serves as a compilation of my scratchpad-notes from developing the engine, hopefully providing a good recollection and reflection on the experience that can help those reading with their own work and/or fun.

## Learnings as a data scientist / building the model
- getting good quality data will be the bulk of your work
- determine how to evaluate your model sooner rather than later
- read the docs for pandas, scikit-learn

## Learnings as a developer / building the web service
- Model predictions can take a while, choose an architecture that can accommodate long-running tasks (e.g. queue)
- be mindful of cost of compute/memory for your model; wanted to use serverless for cost savings but initial model memory usage was too big
- sagemaker encourages using their tools - byob is not well documented 

## Learnings as an operator / running the system
- decouple your training and serving architecture 
- version your data just like you would your source code
- consider orchestrating end to end deployments with webhooks to save on compute time
- many workflows involved / this stuff is complicated 
        - Workflows to consider:
            - Model training infra changes
            - Model training logic changes
            - Model training data set changes
            - Model serving infra changes
            - Model serving logic changes

## Final thoughts on the whole process, link to the app