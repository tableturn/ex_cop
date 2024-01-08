defmodule ExCop.Test.Policies.Post do
  @moduledoc false
  use ExCop.Policy, target: ExCop.Test.Fixtures.Post
  alias ExCop.Test.Fixtures.User

  before do
    case subject do
      %{name: "before"} -> {%{subject | name: "after"}, persona, parent, field, ctx, args}
      _ -> {subject, persona, parent, field, ctx, args}
    end
  end

  allowance "before" do
    subject %Post{name: "after"}
  end

  allowance "subject" do
    subject %Post{name: "subject"}
  end

  allowance "persona" do
    persona %User{id: "some specific id"}
  end

  allowance "guest" do
    subject %Post{name: "nil persona"}
    persona nil
  end

  allowance "logged-in" do
    subject %Post{name: "non-nil persona"}
    persona %User{}
  end

  allowance "admin" do
    subject %Post{name: "admin persona"}
    persona %User{is_admin: true}
  end

  allowance "reason" do
    subject %Post{name: "reason"}
    check do: ExCop.Police.allow(:reason)
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
    persona %User{id: _}
  end

  allowance "guards" do
    subject %Post{id: id, name: name}
    persona %User{id: id, is_admin: is_admin}
    parent :parent
    field :field
    args %{something: :else}
    guard is_admin == false and name == "guards"
  end

  allowance "multiple guards" do
    subject %Post{name: name}
    persona %User{id: user_id, is_admin: is_admin}
    guard name == "multiple guards"
    guard user_id == "1"
    guard is_admin == true
  end

  allowance "single check" do
    subject %Post{name: "single check"}
    check do: (subject.id == "pass!" && allow()) || deny()
  end

  allowance "multiple checks" do
    subject %Post{name: "multiple checks"}
    persona %User{id: user_id}
    check do: (user_id == "pass!" && allow()) || deny()
    check do: (subject.id == "pass!" && allow()) || deny()
  end

  allowance "multiple checks with reasons" do
    subject %Post{name: "multiple checks with reasons"}
    persona %User{id: user_id}
    check do: (user_id == "pass!" && allow(:valid_user)) || deny(:invalid_user)
    check do: (subject.id == "pass!" && allow(:valid_subject)) || deny(:invalid_subject)
  end

  mutation_allowance "mutation_allowance" do
    subject %Post{name: "mutation_allowance"}
  end

  allowance "delegated" do
    persona %User{id: "delegated"}
    subject %{name: "delegated"}
    parent :delegated_parent
    field :delegated_field
    args %{delegated: true}
  end

  allowance "delegated query" do
    persona %User{id: "delegated"}
    subject %{name: "delegated"}
    parent :query
    field :delegated_field
    args %{delegated: true}
  end

  allowance "delegated mutation" do
    persona %User{id: "delegated"}
    subject %{name: "delegated"}
    parent :mutation
    field :delegated_field
    args %{delegated: true}
  end
end
