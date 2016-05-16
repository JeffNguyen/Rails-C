# Rails-C

Rails-C is a webserver MVC framework and ORM inspired by Ruby on Rails. It includes a demo showing REST implementation.

## Setup

From the root directory of the project, run
```bash
bundle install
```
(Install bundler if you haven't already). Then, run

```bash
ruby app/bin/server.rb
```

## Features

Router, Controllers, Views
- Handles POST, GET, PATCH, DELETE
- CSRF protection
- Cookies
  - Session class for persistent cookies
  - Flash cookies which persist only for one request cycle
  - Flash.now cookies which only for current request cycle
- View helper methods like `link_to` and `button_to`
- `resources` method for routers automatically defines CRUD routes

ORM
- Eager loading using `includes`,
- Has-many-through, belongs-to-through, and has-one-through associations
- Lazy querying via the Relation class
- Model validations
  - Custom validations
  - Preset validations like `presence` and `uniqueness`
- Strong params
