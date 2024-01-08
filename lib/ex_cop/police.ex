defmodule ExCop.Police do
  @moduledoc false
  alias ExCop.Policy.Protocol

  @type subject :: any
  @type persona :: Protocol.persona()
  @type parent :: Protocol.parent()
  @type field :: Protocol.field()
  @type context :: Protocol.context()
  @type args :: Protocol.args()
  @type error_response :: Protocol.error_response()
  @type response :: Protocol.response()

  @spec __using__(any) :: term
  def __using__(_opts \\ []) do
    quote location: :keep do
      import ExCop.Police, only: [allow: 0, allow: 1, deny: 0, deny: 1]

      @behaviour ExCop.Police
    end
  end

  def check(source, user, parent, field, ctx, args) do
    post = Protocol.before(source, user, parent, field, ctx, args) |> Tuple.to_list()
    apply(&Protocol.can?/6, post)
  end

  @spec allow(any) :: :ok | {:ok, any}
  def allow(reason \\ nil)

  def allow(nil),
    do: :ok

  def allow(reason),
    do: {:ok, reason}

  @spec deny(String.t() | nil) :: Protocol.error_response()
  def deny(reason \\ nil)

  def deny(nil),
    do: {:error, :unauthorized}

  def deny(reason),
    do: {:error, :unauthorized, reason}

  @spec missing_policy() :: Protocol.error_response()
  def missing_policy(),
    do: {:error, :missing_policy}
end
