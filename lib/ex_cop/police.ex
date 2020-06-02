defmodule ExCop.Policy do
  @moduledoc false

  defmodule Rule do
    @moduledoc false

    @type t :: %__MODULE__{}
    defstruct description: nil,
              subject_matches: [],
              user_matches: [],
              parent_matches: [],
              field_matches: [],
              context_matches: [],
              args_matches: [],
              guards: [],
              check_fn: nil
  end

  defmacro __using__(opts) do
    target = opts |> Keyword.fetch!(:target)

    quote location: :keep do
      alias unquote(target)
      alias unquote(Application.fetch_env!(:ex_cop, :user_module))

      import unquote(__MODULE__),
        only: [allowance: 2, query_allowance: 2, mutation_allowance: 2]

      # Store the target for which the protocol will be implemented.
      @target unquote(target)
      # Prepare a stack of rules to unwrap later into functions.
      Module.register_attribute(__MODULE__, :rules, accumulate: true, persist: false)
      Module.register_attribute(__MODULE__, :rule, accumulate: false, persist: false)
      # Schedule unwrapping rules.
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro allowance(description, do: body) do
    quote location: :keep do
      import unquote(__MODULE__)
      # Prepare defaults in case the user function doesn't do anything.
      @rule %Rule{description: unquote(description)}
      # Invoke the passed body.
      unquote(body)
      # Push a new rule into our accumulator.
      @rules @rule
    end
  end

  defmacro query_allowance(description, do: body) do
    quote location: :keep do
      import unquote(__MODULE__)
      # Prepare defaults in case the user function doesn't do anything.
      @rule %Rule{description: unquote(description), parent_matches: [:query]}
      # Invoke the passed body.
      unquote(body)
      # Push a new rule into our accumulator.
      @rules @rule
    end
  end

  defmacro mutation_allowance(description, do: body) do
    quote location: :keep do
      import unquote(__MODULE__)
      # Prepare defaults in case the user function doesn't do anything.
      @rule %Rule{description: unquote(description), parent_matches: [:mutation]}
      # Invoke the passed body.
      unquote(body)
      # Push a new rule into our accumulator.
      @rules @rule
    end
  end

  defmacro __before_compile__(env) do
    target = env.module |> Module.get_attribute(:target)
    rules = env.module |> Module.get_attribute(:rules)

    ast =
      for %{
            description: description,
            subject_matches: subject_matches,
            user_matches: user_matches,
            parent_matches: parent_matches,
            field_matches: field_matches,
            context_matches: context_matches,
            args_matches: args_matches,
            guards: guards,
            check_fn: check_fn
          } <- rules do
        # Combine all guards.
        combined_guards =
          guards
          |> Enum.reduce(true, &quote(location: :keep, do: unquote(&2) and unquote(&1)))

        # Combine all subject patterns after a generic "subject" one.
        subject_match_ast =
          subject_matches
          |> Enum.reduce(
            quote(do: subject),
            &quote(location: :keep, do: unquote(&2) = unquote(&1))
          )

        # Combine all user patterns after a generic "user" one.
        user_match_ast =
          user_matches
          |> Enum.reduce(
            quote(do: user),
            &quote(location: :keep, do: unquote(&2) = unquote(&1))
          )

        # Combine all user patterns after a generic "user" one.
        parent_match_ast =
          parent_matches
          |> Enum.reduce(
            quote(do: parent),
            &quote(location: :keep, do: unquote(&2) = unquote(&1))
          )

        # Combine all user patterns after a generic "field" one.
        field_match_ast =
          field_matches
          |> Enum.reduce(
            quote(do: field),
            &quote(location: :keep, do: unquote(&2) = unquote(&1))
          )

        # Combine all user patterns after a generic "field" one.
        context_match_ast =
          context_matches
          |> Enum.reduce(
            quote(do: context),
            &quote(location: :keep, do: unquote(&2) = unquote(&1))
          )

        # Combine all user patterns after a generic "field" one.
        args_match_ast =
          args_matches
          |> Enum.reduce(
            quote(do: args),
            &quote(location: :keep, do: unquote(&2) = unquote(&1))
          )

        if check_fn do
          quote location: :keep do
            @doc unquote(description)
            def can?(
                  unquote(subject_match_ast) = var!(subject),
                  unquote(user_match_ast) = var!(user),
                  unquote(parent_match_ast) = parent = var!(parent),
                  unquote(field_match_ast) = var!(field),
                  unquote(context_match_ast) = var!(ctx),
                  unquote(args_match_ast) = var!(args)
                )
                when unquote(combined_guards) do
              _ = var!(subject)
              _ = var!(user)
              _ = var!(parent)
              _ = var!(field)
              _ = var!(ctx)
              _ = var!(args)

              (unquote(check_fn) && ExCop.Police.allow()) || ExCop.Police.deny()
            end
          end
        else
          quote location: :keep do
            @doc unquote(description)
            def can?(
                  unquote(subject_match_ast),
                  unquote(user_match_ast),
                  unquote(parent_match_ast),
                  unquote(field_match_ast),
                  unquote(context_match_ast),
                  unquote(args_match_ast)
                )
                when unquote(combined_guards) do
              ExCop.Police.allow()
            end
          end
        end
      end

    quote location: :keep do
      defimpl ExCop.Policy.Protocol, for: unquote(target) do
        # Always allow IDs to be accessed.
        def can?(_subject, _user, _parent, :id, _ctx, _args),
          do: ExCop.Police.allow()

        # Add our list of rules.
        unquote(ast)

        # Fallback - deny.
        def can?(_subject, _user, _parent, _field, _ctx, _args),
          do: ExCop.Police.deny()
      end
    end
  end

  defmacro guard(body) do
    quote location: :keep do
      @rule @rule |> Map.put(:guards, @rule.guards ++ [unquote(Macro.escape(body))])
    end
  end

  defmacro subject(body) do
    quote location: :keep do
      @rule %{@rule | subject_matches: @rule.subject_matches ++ [unquote(Macro.escape(body))]}
    end
  end

  defmacro user(body) do
    quote location: :keep do
      @rule %{@rule | user_matches: @rule.user_matches ++ [unquote(Macro.escape(body))]}
    end
  end

  defmacro parent(body) do
    quote location: :keep do
      @rule %{@rule | parent_matches: @rule.parent_matches ++ [unquote(Macro.escape(body))]}
    end
  end

  defmacro parent_in(parents) do
    body =
      quote location: :keep do
        parent in unquote(parents)
      end

    quote location: :keep do
      @rule @rule |> Map.put(:guards, @rule.guards ++ [unquote(Macro.escape(body))])
    end
  end

  defmacro field(body) do
    quote location: :keep do
      @rule %{@rule | field_matches: @rule.field_matches ++ [unquote(Macro.escape(body))]}
    end
  end

  defmacro field_in(fields) do
    body =
      quote location: :keep do
        field in unquote(fields)
      end

    quote location: :keep do
      @rule @rule |> Map.put(:guards, @rule.guards ++ [unquote(Macro.escape(body))])
    end
  end

  defmacro context(body) do
    quote location: :keep do
      @rule %{@rule | context_matches: @rule.context_matches ++ [unquote(Macro.escape(body))]}
    end
  end

  defmacro args(body) do
    quote location: :keep do
      @rule %{@rule | args_matches: @rule.args_matches ++ [unquote(Macro.escape(body))]}
    end
  end

  defmacro check(do: body) do
    quote location: :keep do
      @rule @rule |> Map.put(:check_fn, unquote(Macro.escape(body)))
    end
  end

  defmacro requires_guest_user() do
    quote location: :keep do
      user(nil)
    end
  end

  defmacro requires_logged_in_user() do
    quote location: :keep do
      user(%unquote(Application.fetch_env!(:ex_cop, :user_module)){})
    end
  end

  defmacro requires_admin_user() do
    quote location: :keep do
      user(%unquote(Application.fetch_env!(:ex_cop, :user_module)){is_admin: true})
    end
  end
end