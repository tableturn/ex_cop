defmodule ExCop.Case do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      import ExCop.Case
    end
  end

  defmacro assert_match(left, right) do
    quote do
      res = unquote(left)

      unquote(right)
      |> match?(res)
      |> assert

      res
    end
  end

  defmacro assert_equal(left, right) do
    quote do
      # Cache result of the left expression, as we only want to execute it once.
      left_res = unquote(left)
      right_res = unquote(right)
      # Compare result of both expressions.
      if left_res == right_res do
        assert true
        # Return result of left expression, in case the user is pipping to something else.
        left_res
      else
        flunk("""
        Terms are not equal:
        #{IO.ANSI.cyan()}left:#{IO.ANSI.reset()} #{inspect(left_res)}
        #{IO.ANSI.cyan()}right:#{IO.ANSI.reset()} #{inspect(right_res)}
        """)
      end
    end
  end
end
