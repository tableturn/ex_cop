defmodule ExCop.Test.Fixtures do
  @moduledoc false

  defmodule User do
    @moduledoc false
    defstruct [:id, :is_admin]
  end

  defmodule Post do
    @moduledoc false
    defstruct [:id, :name]
  end

  defmodule Comment do
    @moduledoc false
    defstruct [:id, :body]
  end
end
