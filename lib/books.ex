defmodule Books do
  @moduledoc """
  Provides a consolidated way to access ISBN information
  across multiple sources
  """

  alias __MODULE__.{Google, OpenLibrary, AltMetrics}

  # Books.fetch("9781547604319")

  @type return :: %{
          status: :ok | :error,
          value: map() | nil
        }

  @type response :: %{
          total: integer(),
          failure: integer,
          google: return,
          open_library: return,
          alt_metrics: return
        }

  @spec fetch(String.t()) :: response
  def fetch(isbn) do
    %{
      google: Google.fetch(isbn),
      open_library: OpenLibrary.fetch(isbn),
      alt_metrics: AltMetrics.fetch(isbn)
    }
    |> compose()
  end

  defp compose(results) do
    total = length(Map.values(results))

    failed =
      results
      |> Map.values()
      |> Enum.filter(&(elem(&1, 0) == :error))
      |> length()

    formatted_results =
      results
      |> Enum.map(fn {key, {status, value}} ->
        {key,
         %{
           status: status,
           value: value
         }}
      end)

    formatted_results
    |> Enum.into(%{})
    |> Map.put(:total, total)
    |> Map.put(:failed, failed)
  end
end
