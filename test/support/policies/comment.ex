defmodule ExCop.Test.Policies.Comment do
  @moduledoc false
  use ExCop.Policy, target: ExCop.Test.Fixtures.Comment
  alias ExCop.Test.Fixtures.User

  allowance "delegates to something else" do
    persona %User{id: "delegated"}
    subject %{body: "delegated"}
    parent :delegated_parent
    field :delegated_field
    args %{delegated: true}
    delegated()
  end

  query_allowance "delegates query to something else" do
    persona %User{id: "delegated"}
    subject %{body: "delegated"}
    field :delegated_field
    args %{delegated: true}
    delegated()
  end

  mutation_allowance "delegates mutation to something else" do
    persona %User{id: "delegated"}
    subject %{body: "delegated"}
    field :delegated_field
    args %{delegated: true}
    delegated()
  end
end
