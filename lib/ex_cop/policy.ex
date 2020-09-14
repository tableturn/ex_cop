defmodule ExCop.Police do
  @moduledoc false
  alias ExCop.Policy.Protocol

  @type subject :: any
  @type user :: Protocol.user()
  @type parent :: Protocol.parent()
  @type field :: Protocol.field()
  @type context :: Protocol.context()
  @type args :: Protocol.args()
  @type error_response :: Protocol.error_response()
  @type response :: Protocol.response()

  @callback check(subject, user, parent, field, context, args) :: response

  @spec __using__(any) :: term
  def __using__(_opts \\ []) do
    quote location: :keep do
      import ExCop.Police, only: [allow: 0, deny: 0, deny: 1]

      @behaviour ExCop.Police
    end
  end

  @spec can?(subject, user, parent, field, context, args) :: response
  def can?(source, user, parent, field, ctx, args),
    do: apply(&Protocol.can?/6, Protocol.before(source, user, parent, field, ctx, args))

  @spec allow() :: :ok
  def allow(),
    do: :ok

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
