defmodule ExCop.PolicyTest do
  use ExCop.Case, async: true
  alias ExCop.Policy.Protocol
  alias ExCop.Test.Fixtures.{User, Post, Comment}

  describe "fallback" do
    test "error when no policy is found" do
      # Test that fallback is the default.
      %Post{}
      |> Protocol.can?(nil, nil, nil, %{}, %{})
      |> assert_match({:error, :unauthorized})
    end
  end

  describe "subject constraints" do
    # Test on matching subject fields.
    test "matches" do
      %Post{name: "subject"}
      |> Protocol.can?(nil, nil, nil, %{}, %{})
      |> assert_equal(:ok)
    end
  end

  describe "user" do
    # Test on matching on a user field.
    test "matches a user constraint" do
      %Post{}
      |> Protocol.can?(%User{id: "some specific id"}, nil, nil, %{}, %{})
      |> assert_equal(:ok)
    end

    test "honours requires_guest_user" do
      # Tests that a logged-in admin cannot access a guest-only policy.
      %Post{name: "requires_guest_user"}
      |> Protocol.can?(%User{is_admin: true}, nil, nil, %{}, %{})
      |> assert_match({:error, :unauthorized})

      # Tests that a logged-in user cannot access a guest-only policy.
      %Post{name: "requires_guest_user"}
      |> Protocol.can?(%User{}, nil, nil, %{}, %{})
      |> assert_match({:error, :unauthorized})

      # Tests that a guest can access a guest policy.
      %Post{name: "requires_guest_user"}
      |> Protocol.can?(nil, nil, nil, %{}, %{})
      |> assert_equal(:ok)
    end

    test "honours requires_logged_in_user" do
      # Tests that a guest cannot access a logged-in policy.
      %Post{name: "requires_logged_in_user"}
      |> Protocol.can?(nil, nil, nil, %{}, %{})
      |> assert_match({:error, :unauthorized})

      # Tests that a logged-in user can access a logged-in policy.
      %Post{name: "requires_logged_in_user"}
      |> Protocol.can?(%User{}, nil, nil, %{}, %{})
      |> assert_equal(:ok)

      # Tests that a logged-in admin user can access a logged-in policy.
      %Post{name: "requires_logged_in_user"}
      |> Protocol.can?(%User{is_admin: true}, nil, nil, %{}, %{})
      |> assert_equal(:ok)
    end

    test "honours requires_admin_user" do
      # Tests that a guest cannot access an admin-restricted policy.
      %Post{name: "requires_admin_user"}
      |> Protocol.can?(nil, nil, nil, %{}, %{})
      |> assert_match({:error, :unauthorized})

      # Tests that a logged-in user cannot access an admin-restricted policy.
      %Post{name: "requires_admin_user"}
      |> Protocol.can?(%User{}, nil, nil, %{}, %{})
      |> assert_match({:error, :unauthorized})

      # Tests that an admin can access an admin-restricted policy.
      %Post{name: "requires_admin_user"}
      |> Protocol.can?(%User{is_admin: true}, nil, nil, %{}, %{})
      |> assert_equal(:ok)
    end
  end

  describe "parent" do
    test "matches a single value" do
      # Tests that specification on a single parent can match.
      %Post{}
      |> Protocol.can?(nil, :single, nil, %{}, %{})
      |> assert_equal(:ok)
    end
  end

  describe "field" do
    test "matches a single value" do
      # Tests that specification on single field can match.
      %Post{}
      |> Protocol.can?(nil, nil, :single, %{}, %{})
      |> assert_equal(:ok)
    end
  end

  describe "field_in" do
    test "matches multiple values" do
      # Tests that specification on multiple fields can match.
      for field <- [:double, :tripple] do
        %Post{}
        |> Protocol.can?(nil, nil, field, %{}, %{})
        |> assert_equal(:ok)
      end
    end
  end

  describe "field and field_in" do
    test "should be combinable" do
      %Post{name: "field and field_in"}
      |> Protocol.can?(nil, nil, :field, %{}, %{})
      |> assert_equal(:ok)
    end
  end

  describe "context" do
    test "matches arguments" do
      # Tests that context is not matched.
      %Post{name: "context"}
      |> Protocol.can?(nil, nil, nil, %{fetched: %{something: false}}, %{})
      |> assert_equal({:error, :unauthorized})

      # Tests that context is matched.
      %Post{name: "context"}
      |> Protocol.can?(nil, nil, nil, %{fetched: %{something: true}}, %{})
      |> assert_equal(:ok)
    end
  end

  describe "args" do
    test "matches arguments" do
      # Tests that args is not matched.
      %Post{}
      |> Protocol.can?(nil, nil, nil, %{}, %{something: :unimportant})
      |> assert_match({:error, :unauthorized})

      # Tests that args is matched properly.
      %Post{}
      |> Protocol.can?(nil, nil, nil, %{}, %{something: :important})
      |> assert_equal(:ok)
    end
  end

  describe "wildcards" do
    test "matches" do
      %Post{id: "Gina", name: "wildcard"}
      |> Protocol.can?(%User{id: "1"}, nil, nil, %{}, %{})
      |> assert_equal(:ok)
    end
  end

  describe "guards" do
    test "is successful when all are matching" do
      %Post{id: "1", name: "guards"}
      |> Protocol.can?(%User{id: "1", is_admin: false}, :parent, :field, %{}, %{something: :else})
      |> assert_equal(:ok)
    end
  end

  describe "guards accumulation" do
    test "accumulates guards using the `and` keyword" do
      # When user id is not "1".
      %Post{name: "multiple guards"}
      |> Protocol.can?(%User{id: "2", is_admin: true}, nil, nil, %{}, %{})
      |> assert_match({:error, :unauthorized})

      # When is_admin is false...
      %Post{name: "multiple guards"}
      |> Protocol.can?(%User{id: "2", is_admin: false}, nil, nil, %{}, %{})
      |> assert_match({:error, :unauthorized})

      # All clear!
      %Post{name: "multiple guards"}
      |> Protocol.can?(%User{id: "1", is_admin: true}, nil, nil, %{}, %{})
      |> assert_equal(:ok)
    end
  end

  describe "check" do
    test "runs the function" do
      %Post{id: "fail!", name: "check"}
      |> Protocol.can?(nil, nil, nil, %{}, %{})
      |> assert_match({:error, :unauthorized})

      %Post{id: "pass!", name: "check"}
      |> Protocol.can?(nil, nil, nil, %{}, %{})
      |> assert_equal(:ok)
    end
  end

  describe "mutation constraints" do
    test "has a mutation_allowance that sets the parent to :mutation" do
      %Post{name: "mutation_allowance"}
      |> Protocol.can?(nil, :query, nil, %{}, %{})
      |> assert_match({:error, :unauthorized})

      %Post{name: "mutation_allowance"}
      |> Protocol.can?(nil, :mutation, nil, %{}, %{})
      |> assert_equal(:ok)
    end
  end

  describe "delegation" do
    test "relies on fetched subject" do
      %Comment{body: "delegated"}
      |> Protocol.can?(
        %User{id: "delegated"},
        :delegated_parent,
        :delegated_field,
        %{fetched: %{subject: %Post{name: "delegated"}}},
        %{delegated: true}
      )
      |> assert_equal(:ok)
    end

    test "relies on fetched subject for query parents" do
      %Comment{body: "delegated"}
      |> Protocol.can?(
        %User{id: "delegated"},
        :query,
        :delegated_field,
        %{fetched: %{subject: %Post{name: "delegated"}}},
        %{delegated: true}
      )
      |> assert_equal(:ok)
    end

    test "relies on fetched subject for mutation parents" do
      %Comment{body: "delegated"}
      |> Protocol.can?(
        %User{id: "delegated"},
        :mutation,
        :delegated_field,
        %{fetched: %{subject: %Post{name: "delegated"}}},
        %{delegated: true}
      )
      |> assert_equal(:ok)
    end
  end
end
