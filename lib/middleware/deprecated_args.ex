defmodule AbsintheUtils.Middleware.DeprecatedArgs do
  @doc """

  Absinthe middleware for handling of deprecated, renamed field arguments.

  TODO: improve documentation

  ## Usage

  ```
  field :query_with_deprecated_required_args, non_null(:string) do
    arg(:old_arg, :string, deprecate: "Use `newParam` instead.")
    arg(:new_arg, :string)

    middleware(
      DeprecatedArgs,
      %{
        legacy_arg_identifier: :old_arg,
        new_arg_identifier: :new_arg,
        is_required: true
      }
    )

    resolve(&MyApp.my_resolver/3)
  end
  ```
  """

  @behaviour Absinthe.Middleware

  @impl true
  def call(
        resolution = %{arguments: arguments},
        %{
          legacy_arg_identifier: legacy_arg_identifier,
          new_arg_identifier: new_arg_identifier,
          is_required: _is_required
        }
      )
      when is_map_key(arguments, legacy_arg_identifier) and
             is_map_key(arguments, new_arg_identifier) do
    Absinthe.Resolution.put_result(
      resolution,
      {
        :error,
        %{
          message:
            "Arguments #{camelize(legacy_arg_identifier)} and " <>
              "#{camelize(new_arg_identifier)} cannot be passed together",
          extensions: %{code: "MUTUALLY_EXCLUSIVE_ARG_VIOLATION"}
        }
      }
    )
  end

  @impl true
  def call(
        resolution = %{arguments: arguments},
        %{
          legacy_arg_identifier: legacy_arg_identifier,
          new_arg_identifier: new_arg_identifier,
          is_required: _is_required
        } = opts
      )
      when is_map_key(arguments, legacy_arg_identifier) do
    {value, arguments} = Map.pop(arguments, legacy_arg_identifier)

    if Map.get(opts, :non_null, false) == true and value === nil do
      Absinthe.Resolution.put_result(
        resolution,
        {
          :error,
          %{
            message: "Argument #{camelize(legacy_arg_identifier)} cannot be null",
            extensions: %{code: "NOT_NULL_VIOLATION"}
          }
        }
      )
    else
      %{
        resolution
        | arguments: Map.put(arguments, new_arg_identifier, value)
      }
    end
  end

  @impl true
  def call(
        resolution = %{arguments: arguments},
        %{
          legacy_arg_identifier: _legacy_arg_identifier,
          new_arg_identifier: new_arg_identifier,
          is_required: _is_required
        } = opts
      )
      when is_map_key(arguments, new_arg_identifier) do
    if Map.get(opts, :non_null, false) == true and
         Map.get(arguments, new_arg_identifier) == nil do
      Absinthe.Resolution.put_result(
        resolution,
        {
          :error,
          %{
            message: "Argument #{camelize(new_arg_identifier)} cannot be null",
            extensions: %{code: "NOT_NULL_VIOLATION"}
          }
        }
      )
    else
      resolution
    end
  end

  @impl true
  def call(
        resolution,
        %{
          legacy_arg_identifier: _legacy_arg_identifier,
          new_arg_identifier: _new_arg_identifier,
          is_required: false
        }
      ) do
    resolution
  end

  @impl true
  def call(
        resolution,
        %{
          legacy_arg_identifier: legacy_arg_identifier,
          new_arg_identifier: new_arg_identifier,
          is_required: true
        }
      ) do
    Absinthe.Resolution.put_result(
      resolution,
      {
        :error,
        %{
          message:
            "Exactly one of the following arguments must be provided: " <>
              "#{camelize(legacy_arg_identifier)}, #{camelize(new_arg_identifier)}",
          extensions: %{code: "MUTUALLY_EXCLUSIVE_ARG_VIOLATION"}
        }
      }
    )
  end

  defp camelize(atom) do
    atom
    |> to_string()
    |> Absinthe.Utils.camelize(lower: true)
  end
end
