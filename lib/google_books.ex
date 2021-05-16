defmodule GoogleBooks do


  @moduledoc """
  Provides a wrapper for the Google Books API.
  Currently only supports finding a book by ISBN.
  """

  # GoogleBooks.find_by_isbn("9780529072245")

  @gbooks_base "https://www.googleapis.com/books/v1/volumes"
  @covers_base "http://covers.openlibrary.org/b"

  def query_images() do
    url = "https://www.google.com/search?q=throne+of+glass&tbm=isch&ved=2ahUKEwi-4KmznM3wAhXBLisKHRAkAd8Q2-cCegQIABAA&oq=throne+of+glass&gs_lcp=CgNpbWcQAzIECCMQJzICCAAyAggAMgIIADICCAAyAggAMgIIADICCAAyAggAMgIIADoFCAAQsQM6BAgAEEM6BwgAELEDEENQjxpYpCdgmihoAHAAeACAAaECiAHiF5IBBjAuMy4xMZgBAKABAaoBC2d3cy13aXotaW1nwAEB&sclient=img&ei=Z4ygYP6QL8HdrAGQyIT4DQ&bih=720&biw=1042"

    case HTTPoison.get(url) do
      {:ok, resp} -> resp.body |> IO.inspect(printable_limit: :infinity)
error -> error
    end


    :ok
  end

  def get(isbn) do
    %{isbn: isbn}
    |> construct_query()
    |> HTTPoison.get()
    |> case do
      {:ok, resp} ->
        (Jason.decode!(resp.body)["items"] || [])
        |> List.first()
        |> case do
          nil -> {:error, :no_match}
          item -> {:ok, parse_item(item)}
        end

      error -> error
    end
  end

  defp parse_item(item) do
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

  # books
  # %{
  #   title: "String",
  #   authors: "Array(string)",
  #   images: %{
  #     cover: "url or local image",
  #     spine: "url or local image",
  #     back_cover: "url or local image",
  #     other: "Need to tag colors. One can be primary"
  #   },
  #   page_count: "Number",
  #   binding: "Array(string)",
  #   isbn: "String",
  #   dimensions: %{
  #     height: %{value: "Number", unit: "String"},
  #     width: %{value: "Number", unit: "String"},
  #     thickness: %{value: "Number", unit: "String"},
  #   },
  #   genre: "Array(string)",
  #   language: "String",
  #   blurb: "String",
  #   quantity: "Number",

  #   371
  # }





  # GoogleBooks.get("9783833732201")
  # GoogleBooks.get_all_versions("9783833732201")
  # 9783833732201

  # GoogleBooks.get("9781408832332")
  # GoogleBooks.get_all_versions("9781408832332")

  # GoogleBooks.get("9780553804577")

  def get_all_versions(isbn) do
    case get(isbn) do
      {:ok, book} ->
        author = List.first(book.authors || [])
        get_like_books(book.title, author, book.language)


        # search by title and author
      error ->
        error
    end
  end


  defp get_like_books(title, author, language) do

    %{title: title, author: author}
    |> construct_query()
    |> HTTPoison.get()
    |> case do
      {:ok, resp} ->
        books =
        Jason.decode!(resp.body)
        |> Map.get("items", [])
        |> Enum.map(&parse_item/1)
        |> Enum.filter(&(&1.language == language))
        |> Enum.reject(&title_has(&1.title, ["Boxset", "Bundle", "Colouring", "Coloring"]))

        {:ok, books}

      error -> error
    end
  end

  defp title_has(title, words), do: Enum.any?(words, &String.contains?(title, &1))

  defp construct_query(params) do
    query_params =
      params
      |> Enum.map(&query_to_param/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("+")

    "#{@gbooks_base}?q=#{query_params}"
    |> URI.encode()
  end

  defp query_to_param({_key, nil}), do: nil
  defp query_to_param({key, value}) do
    case key do
      :title -> "intitle:#{value}"
      :author -> "inauthor:#{value}"
      :publisher -> "inpublisher:#{value}"
      :subject -> "subject:#{value}"
      :isbn -> "isbn:#{value}"
      :lccn -> "lccn:#{value}"
      :oclc -> "oclc:#{value}"
    end
  end

  defp image_size(size) do
    case size do
      :large -> "L"
      :medium -> "M"
      _ -> "S"
    end
  end

  def get_cover(isbn, size \\ :small) do
  endpoint = "#{@covers_base}/isbn/#{isbn}-#{image_size(size)}.jpg"
    HTTPoison.get(endpoint)
    |> IO.inspect()
    # http://covers.openlibrary.org/b/isbn/9780385533225-S.jpg
  end


  # GoogleBooks.open_library_get("9781547604319")
  def open_library_get(isbn) do
    "https://openlibrary.org/api/books?bibkeys=ISBN:#{isbn}&format=json&jscmd=data"
    |> HTTPoison.get()
    |> case do
      {:ok, resp} ->
        resp.body
        |> Jason.decode!()
        |> Map.values()
        |> List.first()
        |> case do
          nil -> {:error, :no_match}
          raw -> {:ok, parse_open_book(raw)}
        end

      error -> error
    end
  end

  defp parse_open_book(raw) do
    authors =
      Enum.map(raw["authors"] || [], &(&1["name"]))
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

  # GoogleBooks.get_altmetric_book("9781547604319")
  # GoogleBooks.get_altmetric_book("9783319255576")

  def get_altmetric_book(isbn) do
    "https://api.altmetric.com/v1/isbn/#{isbn}"
    |> HTTPoison.get()
    |> case do
      {:ok, %{status_code: 200} = resp} ->
        IO.inspect(resp)
        book =
          resp.body
          |> Jason.decode!()
          |> parse_altmetric_book()

          {:ok, book}

        _ ->
          {:error, :no_match}
    end

  end

  defp parse_altmetric_book(raw) do
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
