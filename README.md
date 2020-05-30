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

  policy "guest users can see a post title and body of valid posts" do
    subject %Post{valid: true}
    field_in [:title, :body]
  end

  policy "logged-in users can see the author of a post" do
    requires_logged_in_user()
    field :author
  end

  policy "users can see everything on posts they are assigned to" do
    subject %Post{assigned_user_id: user_id}
    user %User{id: user_id}
  end

  policy "posts with less than three comments can be seen by logged-in users" do
    subject %Post{comment_count: count}
    requires_logged_in_user()
    guard count < 3
  end

  policy "allows something after checking something else" do
    subject %Post{must_check: true}
    check do
      user.id == "secret agent" || subject.chain_id =~ "123"
    end
  end

  policy "administrators can see everything in a post" do
    requires_admin_user()
  end
end
```

Policies are compiled into Elixir. A module will be created conforming to the `ExCop.Policy.Protocol` and
declaring a series of `can?/6` functions, one per `policy` you called.

At runtime, policies are evaluated from top to bottom - so it might be a good idea to keep the most used ones
on top and the most expensive ones to run at the bottom, like you would usually do with pattern-matching.

In case of a default:
- If no policy module exists for the target, it will return `{:error, :missing_policy}`.
- When no policy is found matching the arguments, `{:error, :unauthorized}` will be returned.

Note that most of the builder is defined using macros - so you will get compile-time errors and warnings
if you define a guard using a variable that is unknown, or if you declare a binding that is not used.

For more informations about how policies can be written, please check `test/ex_cop/builder_test.exs` and
its fixture `test/support/policed.ex`.

## The `check/0` Function

If you decide to use the `check` function, be mindful of the following:

- You can use the following bindings `subject`, `user`, `parent`, `field`, `context` and `args`.
- Your check block will allow access if it returns anything else than `false`-ey.
- The check function is performed after pattern matching - meaning that once the check block is entered, no further policy will be evaluated, even if the check block returns `false`-ey.

## Verifying Policies

To check for a policy, you can do something like this:

```elixir
defmodule MyApp.Police do
  def check(source, user, parent, field, context, args),
    do: source |> ExCop.Policy.Protocol.can?(user, parent, field, context, args)
end
```
