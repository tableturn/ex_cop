defmodule ExCop.Policy do
  @moduledoc false

  defmodule Rule do
    @moduledoc false

    @type t :: %__MODULE__{}
    defstruct description: nil,
              subject_matches: [],
              persona_matches: [],
              parent_matches: [],
              field_matches: [],
              context_matches: [],
              args_matches: [],
              guards: [],
              checks: []
  end

  defmacro __using__(opts) do
    target = opts |> Keyword.fetch!(:target)

    quote location: :keep do
      alias unquote(target)

      import unquote(__MODULE__),
        only: [before: 1, allowance: 2, query_allowance: 2, mutation_allowance: 2]

      # Store the target for which the protocol will be implemented.
      @target unquote(target)
      # Prepare a stack of rules to unwrap later into functions.
      Module.register_attribute(__MODULE__, :before_fn, accumulate: false, persist: false)
      Module.register_attribute(__MODULE__, :rules, accumulate: true, persist: false)
      Module.register_attribute(__MODULE__, :rule, accumulate: false, persist: false)
      # Schedule unwrapping rules.
      @before_compile unquote(__MODULE__)
    end
  end

  defmacro allowance(description, do: body) do
    quote location: :keep do
      import unquote(__MODULE__)
      # Prepare defaults in case the persona function doesn't do anything.
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
      # Prepare defaults in case the persona function doesn't do anything.
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
      # Prepare defaults in case the persona function doesn't do anything.
      @rule %Rule{description: unquote(description), parent_matches: [:mutation]}
      # Invoke the passed body.
      unquote(body)
      # Push a new rule into our accumulator.
      @rules @rule
    end
  end

  defmacro before(do: body) do
    quote location: :keep do
      @before_body unquote(Macro.escape(body))
    end
  end

  defmacro __before_compile__(env) do
    target = env.module |> Module.get_attribute(:target)
    rules = env.module |> Module.get_attribute(:rules)
    before_body = env.module |> Module.get_attribute(:before_body)

    ast =
      for %{
            description: description,
            subject_matches: subject_matches,
            persona_matches: persona_matches,
            parent_matches: parent_matches,
            field_matches: field_matches,
            context_matches: context_matches,
            args_matches: args_matches,
            guards: guards,
            checks: checks
          } <- rules |> Enum.reverse() do
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

        # Combine all persona patterns after a generic "persona" one.
        persona_match_ast =
          persona_matches
          |> Enum.reduce(
            quote(do: persona),
            &quote(location: :keep, do: unquote(&2) = unquote(&1))
          )

        # Combine all persona patterns after a generic "persona" one.
        parent_match_ast =
          parent_matches
          |> Enum.reduce(
            quote(do: parent),
            &quote(location: :keep, do: unquote(&2) = unquote(&1))
          )

        # Combine all persona patterns after a generic "field" one.
        field_match_ast =
          field_matches
          |> Enum.reduce(
            quote(do: field),
            &quote(location: :keep, do: unquote(&2) = unquote(&1))
          )

        # Combine all persona patterns after a generic "field" one.
        context_match_ast =
          context_matches
          |> Enum.reduce(
            quote(do: context),
            &quote(location: :keep, do: unquote(&2) = unquote(&1))
          )

        # Combine all persona patterns after a generic "field" one.
        args_match_ast =
          args_matches
          |> Enum.reduce(
            quote(do: args),
            &quote(location: :keep, do: unquote(&2) = unquote(&1))
          )

        quote location: :keep do
          @doc unquote(description)
          def can?(
                unquote(subject_match_ast) = var!(subject),
                unquote(persona_match_ast) = var!(persona),
                unquote(parent_match_ast) = var!(parent),
                unquote(field_match_ast) = var!(field),
                unquote(context_match_ast) = var!(ctx),
                unquote(args_match_ast) = var!(args)
              )
              when unquote(combined_guards) do
            _ = [var!(subject), var!(persona), var!(parent), var!(field), var!(ctx), var!(args)]

            # TODO: Help needed!
            # Somehow, `unquote(checks)` runs them all, instead of just
            # building a list of each check block AST to be ran lazily...
            unquote(checks)
            # As long as checks return :ok or an {:ok, ...} tuple, we keep going.
            |> Enum.reduce_while([], fn check, acc ->
              check
              |> case do
                :ok -> {:cont, acc}
                {:ok, reason} -> {:cont, [reason | acc]}
                {:error, :unauthorized} = err -> {:halt, err}
                {:error, :unauthorized, _reason} = err -> {:halt, err}
              end
            end)
            |> case do
              [] -> :ok
              [reason] -> {:ok, reason}
              [_ | _] = reasons -> {:ok, reasons: reasons}
              {:error, :unauthorized} = err -> err
              {:error, :unauthorized, _reason} = err -> err
            end
          end
        end
      end

    quote location: :keep do
      defimpl ExCop.Policy.Protocol, for: unquote(target) do
        # Before function.
        def before(var!(subject), var!(persona), var!(parent), var!(field), var!(ctx), var!(args)) do
          unquote(
            before_body ||
              quote(
                do: {
                  var!(subject),
                  var!(persona),
                  var!(parent),
                  var!(field),
                  var!(ctx),
                  var!(args)
                }
              )
          )
        end

        # Add our list of rules.
        unquote(ast)

        # Fallback - deny.
        def can?(_source, _persona, _parent, _field, _ctx, _args) do
          ExCop.Police.deny()
        end
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

  defmacro persona(body) do
    quote location: :keep do
      @rule %{@rule | persona_matches: @rule.persona_matches ++ [unquote(Macro.escape(body))]}
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
      import ExCop.Police, only: [allow: 0, allow: 1, deny: 0, deny: 1]

      @rule @rule |> Map.put(:checks, @rule.checks ++ [unquote(Macro.escape(body))])
    end
  end

  defmacro delegated() do
    quote location: :keep do
      context(%{fetched: %{subject: subject}})

      check do
        subject
        |> ExCop.Police.check(
          var!(persona),
          var!(parent),
          var!(field),
          var!(ctx),
          var!(args)
        )
      end
    end
  end
end
