defmodule HtmlCleaner do
  @moduledoc """
  This module is to clean html
  """

  @allowed_elements [
    "a",
    "article",
    "aside",
    "b",
    "blockquote",
    "br",
    "center",
    "del",
    "dfn",
    "div",
    "dl",
    "dt",
    "em",
    "font",
    "footer",
    "h3",
    "h4",
    "h5",
    "h6",
    "header",
    "hr",
    "i",
    "img",
    "ins",
    "li",
    "ol",
    "p",
    "section",
    "span",
    "strike",
    "strong",
    "sub",
    "sup",
    "table",
    "tbody",
    "td",
    "tr",
    "u",
    "ul",
    "wbr"
  ]

  defp is_previous_element_br?(html) do
    last_element =
      html
      |> Enum.filter(fn
        {_, _, _} -> true
        text -> String.trim(text) != ""
      end)
      |> Enum.at(-1)

    case last_element do
      {"br", _, _} -> true
      _ -> false
    end
  end

  defp filter_unnecessary_br(html) when is_list(html) do
    html
    |> Enum.reduce([], fn
      {"br", attrs, children}, elements ->
        if is_previous_element_br?(elements) do
          elements
        else
          elements ++ [{"br", attrs, filter_unnecessary_br(children)}]
        end

      {name, attrs, children}, elements ->
        elements ++ [{name, attrs, filter_unnecessary_br(children)}]

      text, elements ->
        elements ++ [text]
    end)
  end

  defp filter_unnecessary_br(html), do: html

  defp has_image?(html) do
    Floki.find(html, "img") != []
  end

  defp filter_empty_lines(html) do
    html
    |> Floki.traverse_and_update(fn
      {name, attrs, children} ->
        if name == "p" and children |> Floki.text() |> String.trim() == "" and
             not has_image?(children) do
          nil
        else
          {name, attrs, filter_unnecessary_br(children)}
        end

      _ ->
        nil
    end)
  end

  defp filter_out_not_allowed_elements(html, allowed_elements) do
    html
    |> Floki.filter_out("*:not(#{Enum.join(@allowed_elements ++ allowed_elements, ", ")})")
  end

  @allowed_href_schemes [nil, "http", "https", "mailto", "tel"]

  # Browsers strip leading C0 controls and spaces and drop tabs and newlines
  # anywhere in a URL before reading its scheme.
  defp allowed_href?(href) do
    href
    |> String.replace(~r/^[\x00-\x20]+|[\t\n\r]/, "")
    |> URI.parse()
    |> Map.fetch!(:scheme)
    |> Kernel.in(@allowed_href_schemes)
  end

  defp transform_anchors(html) do
    html
    |> Floki.attr("a[href]", "href", &if(allowed_href?(&1), do: &1, else: "#"))
    |> Floki.attr("a[href]", "rel", fn _ -> "noopener noreferrer" end)
    |> Floki.attr("a[href]", "target", fn _ -> "_blank" end)
  end

  @allowed_attributes [
    "href",
    "src",
    "target",
    "rel",
    "style"
  ]

  defp allowed_attribute?({"class", _}, %Regex{}) do
    true
  end

  defp allowed_attribute?({key, _}, _) do
    key in @allowed_attributes
  end

  defp remove_not_allowed_attributes(html, allowed_classes_regex) do
    html
    |> Floki.traverse_and_update(fn
      {name, attrs, children} ->
        {
          name,
          attrs |> Enum.filter(&allowed_attribute?(&1, allowed_classes_regex)),
          children
        }

      other ->
        other
    end)
  end

  def remove_not_allowed_classes(html, %Regex{} = allowed_classes_regex) do
    html
    |> Floki.find_and_update("*[class]", fn
      {name, attributes} ->
        {name,
         attributes
         |> Enum.flat_map(fn
           {"class", classes} ->
             classes =
               classes
               |> String.split(" ", trim: true)
               |> Enum.filter(&String.match?(&1, allowed_classes_regex))
               |> Enum.join(" ")

             if classes == "" do
               []
             else
               [{"class", classes}]
             end

           {key, value} ->
             {key, value}
         end)}

      other ->
        other
    end)
  end

  def remove_not_allowed_classes(html, _) do
    html
  end

  def allowed_url?(url, %Regex{} = allowed_url_regex) do
    String.match?(url, allowed_url_regex)
  end

  def allowed_url?(_, _), do: false

  defp remove_elements_with_not_allowed_urls(html, allowed_url_regex) do
    html
    |> Floki.traverse_and_update(fn
      {name, attrs, children} ->
        has_external_url_in_src =
          attrs
          |> Enum.any?(fn {key, value} ->
            key == "src" and not allowed_url?(value, allowed_url_regex)
          end)

        if has_external_url_in_src do
          nil
        else
          {name, attrs, children}
        end

      other ->
        other
    end)
  end

  defp filter_style_properties(_, []) do
    ""
  end

  defp filter_style_properties(style, allowed_style_properties) do
    style
    |> String.split(";", trim: true)
    |> Enum.flat_map(fn property_with_value ->
      with [property, value] <- String.split(property_with_value, ":", trim: true),
           true <- property in allowed_style_properties do
        [Enum.join([property, value], ": ")]
      else
        _ -> []
      end
    end)
    |> Enum.join("; ")
  end

  defp remove_not_allowed_inline_style_properties(html, allowed_style_properties) do
    html
    |> Floki.traverse_and_update(fn
      {name, attrs, children} ->
        {name,
         attrs
         |> Enum.flat_map(fn
           {"style", value} ->
             with true <- is_binary(value),
                  style when style !== "" <-
                    filter_style_properties(value, allowed_style_properties) do
               [{"style", style}]
             else
               _ -> []
             end

           other ->
             [other]
         end), children}

      other ->
        other
    end)
  end

  def minify_spaces(html) when is_binary(html) do
    html
    |> String.replace(~r/(\s*\n\s*)+/, "\n")
    |> String.replace(~r/[^\S\n]+/, " ")
    |> String.trim()
  end

  def clean_html(html, options \\ [])

  def clean_html(html, options) when is_binary(html) do
    html
    |> Floki.parse_fragment!()
    |> clean_html(options)
    |> Floki.raw_html(encode: true)
    |> minify_spaces()
  end

  def clean_html(nil, _), do: nil

  def clean_html(html, options) do
    allowed_url_regex = Keyword.get(options, :allowed_url_regex)
    allowed_elements = Keyword.get(options, :allowed_elements, [])
    allowed_classes_regex = Keyword.get(options, :allowed_classes_regex, [])
    allowed_inline_style_properties = Keyword.get(options, :allowed_inline_style_properties, [])

    html
    |> filter_out_not_allowed_elements(allowed_elements)
    |> remove_elements_with_not_allowed_urls(allowed_url_regex)
    |> remove_not_allowed_attributes(allowed_classes_regex)
    |> remove_not_allowed_classes(allowed_classes_regex)
    |> remove_not_allowed_inline_style_properties(allowed_inline_style_properties)
    |> filter_empty_lines()
    |> transform_anchors()
  end
end
