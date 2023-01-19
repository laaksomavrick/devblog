---
title: Handling Dynamic Property Typings with TypeScript
date: "2023-01-19T00:00:00.000Z"
description: Learn how to leverage the keyof type operator with union types and generics for safely accessing dynamic properties in TypeScript.
---

## The scenario

We've all been there. You're writing an integration against a web API. The access pattern is the same for each endpoint and you want to keep your code DRY. However, the responses you're observing have some common properties and some uncommon properties:

```
GET /api/v1/book/1

{
    "status": 200,
    "error": null,
    "warnings": null,
    "data": { id: 1, title: "Infinite Jest", ... }
}

GET /api/v1/authors

{
    "status": 200,
    "error": null,
    "warnings": null,
    "data": [{ id: 1, name: "David Foster Wallace", ... }, ...]
}

...
```

Since the shape of the response is uniform, creating a type is an obvious choice. However, `data` is different for each endpoint. Typing `data` as `any`, while avoiding type errors, means all consumers of our integration will be responsible for validating the shape of `data`. There must be a better way.

## Brainstorming

Let's start with handling our known common properties in a type:

```typescript
type ApiResponse = {
  status: number
  error: string | null
  warnings: string[] | null
  data: any
}
```

We know `data` will be either an array of objects or an object with varying properties. We can express that as follows:

```typescript
type ApiResponseData = { [key: string]: any }

type ApiResponse = {
  status: number
  error: string | null
  warnings: string[] | null
  data: ApiResponseData | ApiResponseData[]
}
```

These typings as-is handle all the common properties of our responses and gives us flexibility for `data`'s shape:

```typescript
const book: ApiResponseData = { id: 1, title: "Infinite Jest" }
const authors: ApiResponseData = [{ id: 1, name: "David Foster Wallace " }]

const title = book.title // OK
const authorName = authors[0].name // OK
```

However, there is a flaw with this approach:

```typescript
const shouldBeACompilerError = book.invalid // Also OK
```

Our typings allow for invalid property access. The compiler won't complain, but we can't trust our typings to provide us with accurate feedback. From experience, invalid property access is one of the most common software bugs (e.g. `Uncaught TypeError: Cannot read properties of undefined`) and we'd like to set up guard rails to avoid it.

## A solution

We can use generics to type the shape of `data` on a per-use basis. In this example, we leverage the [`keyof` type operator](https://www.typescriptlang.org/docs/handbook/2/keyof-types.html) alongside the `in` keyword to access the property key types for our provided generic `Type` as a `union`.

For example, for a `Book`, the property keys would be:

```typescript
type BookProperties = "id" | "title"

// Or in other words:

type BookProperties = keyof Book
```

Then, our value for each corresponding key is the type accessor for that key, similar to accessing the property of an object:

```typescript
type ApiResponseData<Type> = {
  [Property in keyof Type]: Type[Property]
}
```

Putting this all together, we end up with:

```typescript
type ApiResponseData<Type> = {
  [Property in keyof Type]: Type[Property]
}

type ApiResponse<DataShape> = {
  status: number
  error: string | null
  warnings: string[] | null
  data: ApiResponseData<DataShape>
}

type Book = { id: number; title: string }
type Author = { id: number; name: string }
type Authors = Author[]

type BookApiResponse = ApiResponse<Book>
type AuthorsApiResponse = ApiResponse<Author[]>

const bookResponse: BookApiResponse = {
  status: 200,
  error: null,
  warnings: null,
  data: {
    id: 1,
    title: "Infinite Jest",
  },
}

const authorsResponse: AuthorsApiResponse = {
  status: 200,
  error: null,
  warnings: null,
  data: [
    {
      id: 1,
      name: "David Foster Wallace",
    },
  ],
}
```

Trying to access an invalid property will now cause an error:

```typescript
const book = bookResponse.data
const shouldBeACompilerError = book.invalid // Error
```

Moreover, we have feedback from the typescript language server about the properties we can access for the `data` in each `ApiResponse`.

## Final thoughts

This summary came as a result of an [excellent blog post by a colleague](https://dev.to/danjfletcher/how-to-handle-this-type-error-2nc1) which led me to reconsider how I'd [answered a question on StackOverflow](https://stackoverflow.com/questions/23914271/typescript-interface-definition-with-an-unknown-property-key/52045097#52045097) some years prior. I encourage anyone reading to engage with the developer community and continue to learn.
