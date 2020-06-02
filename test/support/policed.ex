defmodule ExCop.Test.Policed do
  @moduledoc false
  use ExCop.Policy, target: ExCop.Test.Policed.Target

  defmodule User do
    @moduledoc false
    defstruct [:id, :is_admin]
  end

  defmodule Target do
    @moduledoc false
    defstruct [:id, :name]
  end

  mutation_allowance "mutation_policy" do
    subject %Target{name: "mutation_policy"}
  end

  allowance "subject" do
    subject %Target{name: "subject"}
  end

  allowance "user" do
    user %User{id: "some specific id"}
  end

  allowance "guest" do
    subject %Target{name: "requires_guest_user"}
    requires_guest_user()
  end

  allowance "logged-in" do
    subject %Target{name: "requires_logged_in_user"}
    requires_logged_in_user()
  end

  allowance "admin" do
    subject %Target{name: "requires_admin_user"}
    requires_admin_user()
  end

  allowance "parent" do
    parent :single
  end

  allowance "field" do
    field :single
  end

  allowance "field_in" do
    field_in [:double, :tripple]
  end

  allowance "field and field_in" do
    field :field
    field_in [:field]
  end

  allowance "context" do
    subject %Target{name: "context"}
    context %{fetched: %{something: true}}
  end

  allowance "args" do
    args %{something: :important}
  end

  allowance "wildcard" do
    subject %Target{id: _, name: "wildcard"}
    user %User{id: _}
  end

  allowance "guards" do
    subject %Target{id: id, name: name}
    user %User{id: id, is_admin: is_admin}
    parent :parent
    field :field
    args %{something: :else}
    guard is_admin == false and name == "guards"
  end

  allowance "multiple guards" do
    subject %Target{name: name}
    user %User{id: user_id, is_admin: is_admin}
    guard name == "multiple guards"
    guard user_id == "1"
    guard is_admin == true
  end

  allowance "check" do
    subject %Target{name: "check"}
    check do: subject.id == "pass!"
  end
end
