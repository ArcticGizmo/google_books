defmodule Books.Google do
  @moduledoc """
  Get book information from the Google Books API
  """

  @base "https://www.googleapis.com/books/v1/volumes"

  @spec fetch(String.t()) :: {:ok, map} | {:error, :no_match | :unable_to_fetch}
  def fetch(isbn) do
    "#{@base}?q=isbn:#{isbn}"
    |> HTTPoison.get()
    |> case do
      {:ok, %{status_code: 200} = resp} ->
        (Jason.decode!(resp.body)["items"] || [])
        |> List.first()
        |> case do
          nil -> {:error, :no_match}
          item -> {:ok, parse(item)}
        end

      {:ok, _resp} ->
        {:error, :unable_to_fetch}

      _ ->
        {:error, :no_match}
    end
  end

  defp parse(item) do
    info = item["volumeInfo"]
    dims = info["dimensions"]
    ids =
      (info["industryIdentifiers"] || [])
      |> Enum.map(&{&1["type"], &1["identifier"]})
      |> Enum.into(%{})

    %{
      title: info["title"],
      authors: info["authors"] || [],
      google_link: info["canonicalVolumeLink"],
      description: info["description"],
      image_links: info["imageLinks"] || [],
      language: info["language"],
      publisher: info["publisher"],
      identifiers: ids,
      published: info["publishedDate"],
      dimensions: %{
        height: dims["height"],
        width: dims["width"],
        thickness: dims["thickness"]
      },
      type: info["printType"],
      pageCount: info["pageCount"],
      categories: info["categories"] || [],
    }
  end
end
