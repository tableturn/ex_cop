defprotocol ExCop.Policy.Protocol do
  @fallback_to_any true

  @type user :: struct | nil
  @type parent :: any
  @type field :: atom
  @type context :: map
  @type args :: map
  @type before_return(type) :: list(type | user | parent | field | context | args)
  @type error_response :: {:error, atom} | {:error, atom, String.t()}
  @type response :: :ok | error_response

  @spec before(t, user, parent, field, context, args) :: before_return(t)
  def before(target, user, parent, field, ctx, args)

  @spec can?(t, user, parent, field, context, args) :: response
  def can?(target, user, parent, field, ctx, args)
end

defimpl ExCop.Policy.Protocol, for: Any do
  alias ExCop.Policy.Protocol

  @type user :: Protocol.user()
  @type parent :: Protocol.parent()
  @type field :: Protocol.field()
  @type context :: Protocol.context()
  @type args :: Protocol.args()
  @type before_return(type) :: Protocol.before_return(type)

  @spec before(any, user, parent, field, context, args) :: before_return(any)
  def before(source, user, parent, field, ctx, args),
    do: [source, user, parent, field, ctx, args]

  # This is our global fallback. Whenever a policy isn't found, we want to keep track
  # of it so we can improve the authorization layer later on.
  @spec can?(any, user, parent, field, context, args) :: {:error, :missing_policy}
  def can?(_source, _user, _parent, _field, _ctx, _args),
    do: ExCop.Police.missing_policy()
end
