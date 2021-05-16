defmodule Books.OpenLibrary do
  @moduledoc """
  Get book information from the Open Library API
  """

  @base "https://openlibrary.org/api/books"

  @spec fetch(String.t()) :: {:ok, map} | {:error, :no_match | :unable_to_fetch}
  def fetch(isbn) do
    "#{@base}?bibkeys=ISBN:#{isbn}&format=json&jscmd=data"
    |> HTTPoison.get()
    |> case do
      {:ok, %{status_code: 200} = resp} ->
        resp.body
        |> Jason.decode!()
        |> Map.values()
        |> List.first()
        |> case do
          nil -> {:error, :no_match}
          raw -> {:ok, parse(raw)}
        end

      {:ok, _resp} ->
        {:error, :unable_to_fetch}

      _ ->
        {:error, :no_match}
    end
  end

  defp parse(raw) do
    authors = Enum.map(raw["authors"] || [], & &1["name"])
    image_links = Map.values(raw["cover"] || %{})

    ids =
      (raw["identifiers"] || %{})
      |> Enum.map(fn {key, values} -> {key, List.first(values)} end)
      |> Enum.into(%{})


      publisher =
        (raw["publishers"] || [])
        |> Enum.map(& &1["name"])
        |> List.first()

    %{
      title: raw["title"],
      authors: authors,
      open_books_link: raw["url"],
      image_links: image_links,
      publisher: publisher,
      identifiers: ids,
      published: raw["publish_date"],
      pageCount: raw["number_of_pages"],
    }
  end
end
