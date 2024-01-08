# ExCop

ExCop is a flexible policy DSL allowing you to write easy-to-navigate policies. ExCop doesn't make any assumption
about what kind of layer is on top or under it - and even though it was designed to work particularily easily
with Absinthe, it should also work for many other environments.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `ex_cop` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_cop, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/ex_cop](https://hexdocs.pm/ex_cop).

## Configuration

You probably want to declare a `Police` module that looks like this:

```elixir
defmodule MyApp.Police do
  @moduledoc false
  alias ExCop.Policy.Protocol
  import ExCop.Police, only: [allow: 0]

  @type user :: Protocol.user()
  @type error_response :: Protocol.error_response()
  @type response :: Protocol.response()
  @type parent :: Protocol.parent()
  @type field :: Protocol.field()
  @type context :: Protocol.context()
  @type args :: Protocol.args()

  @allowed_parents [
    :__schema,
    :__directive,
    :__type,
    :__inputvalue,
    :__field,
    :__enumvalue,
    :page_info,
    :edges
  ]

  @allowed_fields [
    :__typename,
    :__schema,
    :id,
    :node,
    :nodes,
    :edges,
    :cursor,
    :page_info
  ]

  @spec check(any, user, parent, field, context, args) :: response()
  def check(_source, _user, parent, field, _ctx, _args)
      when parent in @allowed_parents or field in @allowed_fields,
      do: allow()

  def check(source, user, parent, field, ctx, args) do
    parent
    |> to_string
    |> String.ends_with?("_payload")
    |> case do
      true -> allow()
      _ -> source |> ExCop.Police.check(user, parent, field, ctx, args)
    end
  end

  defmodule Helpers do
    @moduledoc false

    defmacro object_allowance(title, do: block) do
      quote do
        allowance unquote(title) do
          unquote(block)
          guard var!(parent) not in [:query, :mutation, :subscription]
        end
      end
    end

    # A macro that requires a user as the current persona.
    defmacro requires_logged_in_user() do
      quote do
        persona %User{}
      end
    end

    # A macro that requires an admin user as the current persona.
    defmacro requires_admin_user() do
      quote do
        persona %User{is_admin: true}
      end
    end

    # A macro that requires that the current persona is `nil` - some guest systems do that.
    defmacro requires_guest_user() do
      quote do
        persona nil
      end
    end
  end
end
```

Then you could have a `Policy` module defined such as:

```elixir
defmodule MyApp.Policy do
  @moduledoc false

  defmacro __using__(opts) do
    quote do
      use ExCop.Policy, unquote(opts)
      alias MyApp.Schema.Accounts.{User, Session}
      import MyApp.Police.Helpers
    end
  end
end
```

This way, all the macro you've defined in MyApp.Police.Helpers would become available to your policies when they `use MyApp.Policy, target: Something`.

## Policy System

To write a policy, simply create a module looking like the following:

```elixir
defmodule MyApp.PostPolicy do
  alias MyApp.{Post, User}
  use MyApp.Policy, target: Post

  allowance "all users can see a post title and body if it's valid" do
    # We require that the `%Post{}` subject has a field `valid` set to `true`.
    subject %{valid: true}
    field_in [:title, :body]
  end

  allowance "users can see the author of a post" do
    # Equivalent to `persona %User{}`...
    requires_logged_in_user()
    field :author
  end

  allowance "users can see everything on posts they authored" do
    persona %User{id: user_id}
    subject %{author_id: user_id}
  end

  allowance "posts with less than three comments can be seen by users" do
    # Here, we guard against the shape of a particular subject, and later use that binding.
    requires_logged_in_user()
    subject %{comment_count: count}
    guard count < 3
  end

  allowance "allows CIA users to see everything on posts for area 51" do
    subject %{cia_post: true, mission: mission}
    check do
      String.downcase(persona.agency) == "cia" && mission =~ "area 51"
    end
  end

  allowance "administrators can see everything in a post" do
    requires_admin_user()
  end
end
```

If you're using Absinthe and want to control what is happening at the root of your schema, you'll have to
implement a policy such as this one:

```elixir
defmodule MyApp.RootPolicy do
  @moduledoc false
  use MyApp.Policy, target: Map

  # Shortcut to using `parent :query`.
  query_allowance "users can access certain queries" do
    persona %User{}
    field_in [:me, :users, :onboards, :documents]
  end

  # Shortcut to using `parent :mutation`.
  mutation_allowance "guests can create new users and authenticate" do
    persona nil
    field_in [:create_user, :authenticate]
  end
end
```

## Policy Delegation to Another Policy

Another trick you can leverage while using ExCop is the policy delegation feature. Consider something like
the following:

```elixir
defmodule MyApp.RootPolicy do
  @moduledoc false
  use MyApp.Policy, target: Map

  # Shortcut to using `parent :query`.
  mutation_allowance "users can access certain queries" do
    field :add_comment
    delegated()
  end
end
```

This particular policy would destructure the `context` into `%{fetched: %{subject: subject}}` and call
`ExCop.Policy.Protocol.can?/6`, effectivelly replacing the subject by the one found in context. Therefore,
if the subject is of a different type, the protocol would in turn try to find a matching policy for the new
subject.

> Note that for this mechanism to work, you will need to have the context fetched before you try and apply
> policies to your subject. See the "Loading Subjects" paragraph for more information.

## Advices

Policies are compiled into Elixir. A module will be created conforming to the `ExCop.Policy` and
declaring a series of `can?/6` functions, one per `policy` you called.

At runtime, policies are evaluated from top to bottom - so it might be a good idea to keep the most used ones
on top and the most expensive ones to run at the bottom, like you would usually do with pattern-matching.

In case of a default:
- If no policy module exists for the target, it will return `{:error, :missing_policy}`.
- When no policy is found matching the arguments, `{:error, :unauthorized}` will be returned.

Note that most of the builder is defined using macros - so you will get compile-time errors and warnings
if you define a guard using a variable that is unknown, or if you declare a binding that is not used.

For more informations about how policies can be written, please check `test/ex_cop/police_test.exs` and
its fixtures.

## The `check/0` Function

If you decide to use the `check` function, be mindful of the following:

- You can use the following bindings `subject`, `user`, `parent`, `field`, `context` and `args`.
- Your check block will allow access if it returns anything else than `false`-ey.
- The check function is performed after pattern matching - meaning that once the check block is entered, no further policy will be evaluated, even if the check block returns `false`-ey.

## Manually Verifying Policies

To check for a policy, you can do something like this:

```elixir
source |> ExCop.Police.check(user, parent, field, context, args)
```

## Loading Subjects

For certain policies, you want to make sure that the subject is loaded before the policies are ran. In the
case of Absinthe, it means that you might want to have your `subject` loaded before your authorization layer
kicks-in.
