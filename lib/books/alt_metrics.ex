defmodule Books.AltMetrics do
  @moduledoc """
  Get book information from the AltMetrics API
  """

  @base "https://api.altmetric.com/v1/isbn"

  @spec fetch(String.t()) :: {:ok, map} | {:error, :no_match | :unable_to_fetch}
  def fetch(isbn) do
    "#{@base}/#{isbn}"
    |> HTTPoison.get()
    |> case do
      {:ok, %{status_code: 200} = resp} ->
        book = resp.body
          |> Jason.decode!()
          |> parse()
          {:ok, book}

      {:ok, resp} ->
        case resp.status_code == 404 do
          true -> {:error, :no_match}
          false -> {:error, :unable_to_fetch}
        end

      _ ->
        {:error, :no_match}
    end
  end

  defp parse(raw) do
    %{
      title: raw["title"],
      link: raw["uri"],
      isbns: raw["isbns"] || [],
      authors: raw["authors_or_editors"] || [],
      published: raw["published_on"],
      image_links: Map.values(raw["images"] || %{})
    }
  end
end
