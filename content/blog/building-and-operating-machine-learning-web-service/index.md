---
title: "Reflections on Building and Running a Machine Learning Recommendation System as a Web Service in AWS"
date: "2024-04-01T00:00:00.000Z"
description: The whole experience made me miss my old friend, the determinate 'if' statement. Read about my experience building, serving, and operating a machine-learning dependent web service. 
---

It's no secret technology circles are currently experiencing peak levels of hype regarding AI and machine learning.
If you're reading this blog post, you likely know from your anecdotal experience: ChatGPT can more often than not write acceptable code snippets and DALL·E's image engine can generate uninspired but highly useful reproductions.

Further, every quarter brings forth new capabilties, expansions, and utilizations of the core technologies backing these models.
So, maybe the hype is [somewhat justified](https://www.google.com/finance/quote/NVDA:NASDAQ?window=6M) (author is aware at time of writing that this graph may change quite dramatically in the future, and the hype may then be somewhat unjustified).

I am not smart enough to know for sure.
But, with its collective capture of our attention, I do know its certain to be useful to learn something about the capabilities AI offers and the techniques we can leverage as software developers to capitalize. 

And so, as is my typical pattern, I wanted to build a hobby project end-to-end leveraging AI and/or machine learning to solve a small problem and learn something along the way. I settled on developing [a recommendation engine to recommend television shows](https://canihasashowplz.com/) based on input user preferences, given:

- I thought it would be fun to build something that could help my spouse and I choose a new television show to watch in the evenings.
- Recommendation engines are a feature I used in my daily life in my software products: Spotify's music recommendations, Amazon's product recommendations, the gajillion ads I am served which I do my best to block, and so on.
- A large public data set exists for movies, but not television shows, so I knew I would have to get the data myself, and I wanted an end-to-end experience.

With that in mind, this blog post serves as a compilation of my scratchpad-notes from developing the engine, hopefully providing a good recollection and reflection on the experience that can help those reading with their own work and/or fun.

## Building the model

The closest I come to being a data scientist in my day-to-day life is having lap time telemetry side-by-side with Formula One races on the weekends.
I stopped learning mathematics formally in grade 11 (priorities were more centered around raising my ELO in video games than they were with doing 50 brain teasers every evening) and only came back to it in a round-about way with discrete mathematics when I segued from english and philosophy to computer science late in my post-secondary journey.

That is to say, I really don't know linear algebra, and at this point, with my [limited and declining dendrites](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC4906299/), I don't want to know.

So, naturally, my first step towards building a model to back a recommendation system was to [buy a book written by someone smarter than me](https://www.amazon.ca/Hands-Machine-Learning-Scikit-Learn-TensorFlow/dp/1491962291) (generously paid for by an employer-backed stipend, thank you [Test Double](https://testdouble.com/)) and blindly follow its instructions, varying the approach to suit my specific domain.

The gist of the process comes down to the following steps:
- Examine your data set and develop an intuition for its features (i.e., properties for you developers out there) and their relationships.
- Prepare the data to suit a particular algorithm or approach you would like to attempt
- Select and train a model
- Develop a heuristic for evaluating the model
- Apply the heuristic and note the results
- Repeat the process until you are happy with the results

### Politely stealing data

As noted, I did not have a data set publicly available to me that met my needs.
Given my goal of a recommendation engine based on user preferences, I needed data that:
- Had a feature indicating a particular user (e.g., user `A` is Bob, user `B` is Alice)
- Had a feature indicating a particular television show (e.g., show `10` has the title 'The Sopranos')
- Had a feature indicating user preference (e.g., show `10` has reviews by both user `A` and user `B`)

So, I settled on [scraping IMDB's reviews](https://github.com/laaksomavrick/tv-show-recommender-exploration/blob/main/data/ratings/ratings/spiders/ratings_spider.py) given the capability to sort that data by the highest volume of reviews.
I combined this with their [publicy available](https://developer.imdb.com/non-commercial-datasets/) data set, allowing me to create a relationship between a television show, users, and their reviews (which conveniently had a number value).
Further, given I scraped only the most reviewed shows, I figured I would have a data set that was "dense" enough (i.e., enough user-review associations) to give at-least-okay recommendations.

After a few days and evenings running my scraper 24/7, I had around 500,000 reviews, which felt like a good enough number (and mostly I wanted to get on with it).
In retrospect, the more data, the better your results will be.
I assume this is a platitude that will hold for every and all machine learning application. 

### Time for science

With my data acquired and aggregated, I ended up with a data set that had the following columns:

```csv
show_id,user_id,rating,primary_title,start_year,end_year,genres,average_rating,num_votes
```

Many features here seemed like they would be good candidates for associating user preferences: users might like shows of similar genres, from similar time periods, or with high ratings in general.

My hope was that these variables would all be encapsulated by users giving positive reviews, as that could be a proxy for each thing I had considered (and those I didn't).

Further, after doing some ~googling~ research, I wanted to leverage a [nearest neighbours](https://scikit-learn.org/stable/modules/neighbors.html) algorithm given its widespread use and relative simplicity compared to other approaches (see [here](https://scholar.google.ca/scholar?q=nearest+neighbor+algorithm+for+recommendation+system&hl=en&as_sdt=0&as_vis=1&oi=scholart) for all the literature on the topic).

So, to best leverage this approach,  I had to transform my data into a set of user-show relationships with a binary attribute `is_liked`. For example:

```csv
show_id,user_id,is_liked
tt0043208,ur20552756,1
tt0043208,ur2483625,0
...
```

Furthermore, there remained a few variants of the model I experimented with (why not? The legwork was already done) and I came to have three potential candidates:
- A vanilla nearest neighbours model
- A graph-based approach generated via the nearest neighbours model
- A random forest classifier, just for fun

Training the model was the easiest part of this whole process (it's really just a few lines of python) - who would have thought?

### Being picky

Given how easy training the model is, its appropriate deciding how to evaluate them is the tricky bit.
My approach demonstrated an [unsupervised learning](https://en.wikipedia.org/wiki/Unsupervised_learning) training method, because my model's output (television show recommendations) could not be compared against a known set of good recommendations for a particular user.

So, I had to get a little creative in developing a heuristic to score each model and fake-it-until-i-make-it.
In essence, my approach was to:
- Organize my data set to select for the most prolific reviewers (i.e., the users with the most reviews against shows also in my data set).
- For each prolific user, sort the television shows they have reviewed (by any dimension, this is done so comparisons are made uniformly).
- For each prolific user, select only the first 80% of shows they have reviewed.
- Train the model with this stratified data set.
- For each user, generate a recommendation, and observe what percentage of recommendations were present in the 20% we did not use for training.

I am not experienced enough to know the caveats of this approach, but it was able to generate a consistent scoring metric that I could evaluate my candidates against.
It is not important that the scoring be high, but that the scoring is better relative to your other candidates (my best model had a metric around 0.24, meaning it gave a 'good' recommendation 24% of the time - better than 0%, so I took that in stride). 

Of note: a recurring theme of this project which became apparent during this stage was that you should only change one variable at a time when evaluating these models.
Further, pay particular attention to making sure all your operations are determinate - operations that can have a different result depending on the environment or context _will_ ruin your day.
In other words, seed random to `42`!

## Serving the model

### Model training

### Model serving

- Model predictions can take a while, choose an architecture that can accommodate long-running tasks (e.g. queue)
- be mindful of cost of compute/memory for your model; wanted to use serverless for cost savings but initial model memory usage was too big
- sagemaker encourages using their tools - byom is not well documented 

## Operating the model
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

- [source code found here](https://github.com/laaksomavrick/canihasashowplz) and [here for exploration code](https://github.com/laaksomavrick/tv-show-recommender-exploration)