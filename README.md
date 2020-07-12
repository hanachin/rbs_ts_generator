# RbsTsGenerator

Generate TypeScript that includes routes definition and request / response JSON type from type signature of Rails controller actions.

Sample repository: [hanachin/rbs_ts_bbs](https://github.com/hanachin/rbs_ts_bbs)

## Usage

Write type signature of your controller actions in [ruby/rbs](https://github.com/ruby/rbs).

```rbs
# sig/app/controllers/boards_controller.rbs
class BoardsController < ApplicationController
  @board: Board
  @boards: Board::ActiveRecord_Relation

  def index: () -> Array[{ id: Integer, title: String }]
  def create: (String title) -> ({ url: String, message: String } | Array[String])
  def update: (Integer id, String title) -> ({ url: String, message: String } | Array[String])
  def destroy: (Integer id) -> { url: String, message: String }
end
```

The return type of the action method is type of json record.
But action does not explicitly return json record.
To pass the ruby type checking, add `| void` to each signatures.

```rbs
class BoardsController < ApplicationController
  @board: Board
  @boards: Board::ActiveRecord_Relation

  def index: () -> (Array[{ id: Integer, title: String }] | void)
  def create: (String title) -> ({ url: String, message: String } | Array[String] | void)
  def update: (Integer id, String title) -> ({ url: String, message: String } | Array[String] | void)
  def destroy: (Integer id) -> ({ url: String, message: String } | void)
end
```

I use [Steep](https://github.com/soutaro/steep) to type checking the ruby code.
Setup the Steepfile like following and run `steep check`.

```ruby
# Steepfile
target :app do
  signature "sig"

  check "app"
  typing_options :strict
end
```

```console
$ bundle exec steep check
[Steep 0.17.1] [target=app] [target#type_check(target_sources: [app/channels/application_cable/channel.rb, app/channels/application_cable/connection.rb, app/controllers/application_controller.rb, app/controllers/boards_controller.rb, app/helpers/application_helper.rb, app/helpers/boards_helper.rb, app/jobs/application_job.rb, app/mailers/application_mailer.rb, app/models/application_record.rb, app/models/board.rb, app/mailboxes/application_mailbox.rb], validate_signatures: true)] [synthesize:(1:1)] [synthesize:(2:3)] [synthesize:(2:3)] [(*::Symbol, ?model_name: ::string, **untyped) -> void] Method call with rest keywords type is detected. Rough approximation to be improved.
```

When you passed the ruby type check, next generate TypeScript from those signatures.

```console
$ rails generate rbs_ts
```

This will generate those routes definition in `app/javascript/packs/rbs_ts_routes.ts`.

```typescript
type BoardsUpdateParams = { id: number; title: string }
type BoardsDestroyParams = { id: number }
type BoardsIndexParams = {}
type BoardsCreateParams = { title: string }

type BoardsUpdateReturn = Exclude<{ url: string; message: string } | string[] | void, void>
type BoardsDestroyReturn = Exclude<{ url: string; message: string } | void, void>
type BoardsIndexReturn = Exclude<{ id: number; title: string }[] | void, void>
type BoardsCreateReturn = Exclude<{ url: string; message: string } | string[] | void, void>

export const boards = {
  path: ({ format }: any) => "/" + "boards" + (() => { try { return "." + (() => { if (format) return format; throw "format" })() } catch { return "" } })(),
  names: ["format"]
} as {
  path: (args: any) => string
  names: ["format"]
  Methods?: "GET" | "POST"
  Params?: {
    GET: BoardsIndexParams,
    POST: BoardsCreateParams
  }
  Return?: {
    GET: BoardsIndexReturn,
    POST: BoardsCreateReturn
  }
}
export const board = {
  path: ({ id, format }: any) => "/" + "boards" + "/" + (() => { if (id) return id; throw "id" })() + (() => { try { return "." + (() => { if (format) return format; throw "format" })() } catch { return "" } })(),
  names: ["id","format"]
} as {
  path: (args: any) => string
  names: ["id","format"]
  Methods?: "PATCH" | "PUT" | "DELETE"
  Params?: {
    PATCH: BoardsUpdateParams,
    PUT: BoardsUpdateParams,
    DELETE: BoardsDestroyParams
  }
  Return?: {
    PATCH: BoardsUpdateReturn,
    PUT: BoardsUpdateReturn,
    DELETE: BoardsDestroyReturn
  }
}
```

And generate default runtime in `app/javascript/packs/rbs_ts_runtime.ts`

```typescript
type HttpMethods = 'GET' | 'POST' | 'PATCH' | 'PUT' | 'DELETE'
type BaseResource = {
  path: (args: any) => string
  names: string[]
  Methods?: any
  Params?: { [method in HttpMethods]?: any }
  Return?: { [method in HttpMethods]?: any }
}
export async function railsApi<
  Method extends Exclude<Resource['Methods'], undefined>,
  Resource extends BaseResource,
  Params extends Exclude<Resource['Params'], undefined>[Method],
  Return extends Exclude<Resource['Return'], undefined>[Method]
>(method: Method, { path, names }: Resource, params: Params): Promise<{ status: number, json: Return }> {
  const tag = document.querySelector<HTMLMetaElement>('meta[name=csrf-token]')
  const paramsNotInNames = Object.keys(params).reduce<object>((ps, key) => names.indexOf(key) === - 1 ? { ...ps, [key]: params[key] } : ps, {})
  const searchParams = new URLSearchParams()
  for (const name of Object.keys(paramsNotInNames)) {
    searchParams.append(name, paramsNotInNames[name])
  }
  const query = method === 'GET' && Object.keys(paramsNotInNames).length ? `?${searchParams.toString()}` : ''
  const body = method === 'GET' ? undefined : JSON.stringify(paramsNotInNames)
  const response = await fetch(path(params) + query, {
    method,
    body,
    headers: {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'X-CSRF-Token': tag.content
    }
  })
  const json = await response.json() as Return
  return new Promise((resolve) => resolve({ status: response.status, json: json }))
}
```

In your TypeScript code, you can use those routes definition and the default runtime like following

```typescript
import { boards } from './rbs_ts_routes'
import { railsApi } from './rbs_ts_runtime'

const params = { title: 'test' }
railsApi('POST' as const, boards, params).then(({ json }) => {
  if (json instanceof Array) {
    return Promise.reject(json)
  } else {
    window.location.href = json.url
    return Promise.resolve()
  }
})
```

## Installation
Add this line to your application's Gemfile:

```ruby
gem 'rbs_ts_generator', group: :development
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install rbs_ts_generator
```

## Contributing

https://github.com/hanachin/rbs_ts_generator

## License
The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
