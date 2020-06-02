defprotocol ExCop.Policy.Protocol do
  @fallback_to_any true

  @type user :: struct | nil
  @type parent :: any
  @type field :: atom
  @type context :: map
  @type args :: map
  @type error_response :: {:error, atom} | {:error, atom, String.t()}
  @type response :: :ok | error_response

  @spec can?(t(), user(), parent, field, context, args) :: response()
  def can?(target, user, parent, field, ctx, args)
end

defimpl ExCop.Policy.Protocol, for: Any do
  # This is our global fallback. Whenever a policy isn't found, we want to keep track
  # of it so we can improve the authorization layer later on.
  @spec can?(any, Policy.user(), Policy.parent(), Policy.field(), Policy.context(), Policy.args()) ::
          {:error, :missing_policy}
  def can?(_source, _user, _parent, _field, _ctx, _args),
    do: ExCop.Police.missing_policy()
end
