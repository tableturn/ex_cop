defprotocol ExCop.Policy.Protocol do
  @fallback_to_any true

  @type user :: struct | nil
  @type parent :: any
  @type field :: atom
  @type context :: map
  @type args :: map
  @type everything :: {any, user, parent, field, context, args}
  @type error_response :: {:error, atom} | {:error, atom, String.t()}
  @type response :: :ok | error_response

  @spec before(any, user, parent, field, context, args) :: everything
  def before(source, user, parent, field, ctx, args)

  @spec can?(any, user, parent, field, context, args) :: response()
  def can?(source, user, parent, field, ctx, args)
end

# This is our global fallback. Whenever a policy isn't found, we want to keep track
# of it so we can improve the authorization layer later on.
defimpl ExCop.Policy.Protocol, for: Any do
  alias ExCop.Policy.Protocol

  @type user :: Protocol.user()
  @type parent :: Protocol.parent()
  @type field :: Protocol.field()
  @type context :: Protocol.context()
  @type args :: Protocol.args()
  @type everything :: Protocol.everything()
  @type error_response :: Protocol.error_response()

  @spec before(any, user(), parent(), field(), context(), args()) :: everything()
  def before(source, user, parent, field, ctx, args),
    do: {source, user, parent, field, ctx, args}

  @spec can?(any, user(), parent(), field(), context(), args()) :: error_response
  def can?(_source, _user, _parent, _field, _ctx, _args),
    do: ExCop.Police.missing_policy()
end
