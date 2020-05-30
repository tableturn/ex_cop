defmodule ExCop.Policy do
  alias ExCop.Policy.Protocol

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
