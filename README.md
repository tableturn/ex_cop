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

Once installed, you must tell ExCop which one is your user module. You do that in your configuration by adding
something like:

```elixir
config :ex_cop,
  user_module: MyApp.User
```

## Policy System

To write a policy, simply create a module looking like something like the following:

```elixir
defmodule MyApp.PostPolicy do
  alias MyApp.{Post, User}
  use ExCop, target: Post

  allowance "all users can see a post title and body if it's valid" do
    # We require that the `%Post{}` subject has a field `valid` set to `true`.
    subject %{valid: true}
    field_in [:title, :body]
  end

  allowance "logged-in users can see the author of a post" do
    requires_logged_in_user()
    field :author
  end

  allowance "users can see everything on posts they authored" do
    subject %{author_id: user_id}
    user %User{id: user_id}
  end

  allowance "posts with less than three comments can be seen by logged-in users" do
    # Here, we guard against the shape of a particular subject, and later use that binding.
    subject %{comment_count: count}
    # This is a shortcut to `user %User{}`.
    requires_logged_in_user()
    guard count < 3
  end

  allowance "allows CIA users to see everything on posts for area 51" do
    subject %{cia_post: true, mission: mission}
    check do
      String.downcase(user.agency) == "cia" && mission =~ "area 51"
    end
  end

  allowance "administrators can see everything in a post" do
    # This is a shortcut to `user %User{is_admin: true}`.
    requires_admin_user()
  end
end
```

If you're using Absinthe and want to control what is happening at the root of your schema, you'll have to
implement a policy such as this one:

```
defmodule MyApp.RootPolicy do
  @moduledoc false
  use ExCop.Policy, target: Map

  # Shortcut to using `parent :query`.
  query_allowance "users can access certain queries" do
    requires_logged_in_user()
    field_in [:me, :users, :onboards, :documents]
  end

  # Shortcut to using `parent :mutation`.
  mutation_allowance "guests can create new users and authenticate" do
    requires_guest_user()
    field_in [:create_user, :authenticate]
  end
end
```

## Policy Delegation to Another Policy

Another trick you can leverage while using ExCop is the policy delegation feature. Consider something like
the following:

```
defmodule MyApp.RootPolicy do
  @moduledoc false
  use ExCop.Policy, target: Map

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
defmodule MyApp.Police do
  def check(source, user, parent, field, context, args),
    do: source |> ExCop.Policy.can?(user, parent, field, context, args)
end
```

## Loading Subjects

For certain policies, you want to make sure that the subject is loaded before the policies are ran. In the
case of Absinthe, it means that you might want to have your `subject` loaded before your authorization layer
kicks-in.
