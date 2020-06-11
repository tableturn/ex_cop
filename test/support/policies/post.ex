defmodule ExCop.Test.Policies.Post do
  @moduledoc false
  use ExCop.Policy, target: ExCop.Test.Fixtures.Post
  alias ExCop.Test.Fixtures.User

  allowance "subject" do
    subject %Post{name: "subject"}
  end

  allowance "user" do
    user %User{id: "some specific id"}
  end

  allowance "guest" do
    subject %Post{name: "requires_guest_user"}
    requires_guest_user()
  end

  allowance "logged-in" do
    subject %Post{name: "requires_logged_in_user"}
    requires_logged_in_user()
  end

  allowance "admin" do
    subject %Post{name: "requires_admin_user"}
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
    subject %Post{name: "context"}
    context %{fetched: %{something: true}}
  end

  allowance "args" do
    args %{something: :important}
  end

  allowance "wildcard" do
    subject %Post{id: _, name: "wildcard"}
    user %User{id: _}
  end

  allowance "guards" do
    subject %Post{id: id, name: name}
    user %User{id: id, is_admin: is_admin}
    parent :parent
    field :field
    args %{something: :else}
    guard is_admin == false and name == "guards"
  end

  allowance "multiple guards" do
    subject %Post{name: name}
    user %User{id: user_id, is_admin: is_admin}
    guard name == "multiple guards"
    guard user_id == "1"
    guard is_admin == true
  end

  allowance "check" do
    subject %Post{name: "check"}
    check do: (subject.id == "pass!" && allow()) || deny()
  end

  mutation_allowance "mutation_allowance" do
    subject %Post{name: "mutation_allowance"}
  end

  allowance "delegated" do
    user %User{id: "delegated"}
    subject %{name: "delegated"}
    parent :delegated_parent
    field :delegated_field
    args %{delegated: true}
  end

  allowance "delegated query" do
    user %User{id: "delegated"}
    subject %{name: "delegated"}
    parent :query
    field :delegated_field
    args %{delegated: true}
  end

  allowance "delegated mutation" do
    user %User{id: "delegated"}
    subject %{name: "delegated"}
    parent :mutation
    field :delegated_field
    args %{delegated: true}
  end
end
