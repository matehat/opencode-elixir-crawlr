defmodule Crawlr do
  def download(url) when is_binary(url) do
    {:ok, url} = String.to_char_list(url)
    download url
  end
  
  def download(url) do
    Crawlr.Throttler.wait!
    case :httpc.request url do
      {:ok, {status, headers, body}} -> 
        Crawlr.Throttler.release!
        body
      
      {:error, _} -> 
        Crawlr.Throttler.release!
        download url
    end
  end
  
  defmodule Script do
    def main(args) do
      Crawlr.Throttler.start
      :httpc.set_options [{:max_sessions, 50}, {:max_keep_alive_length, 50}, {:max_pipeline_length, 20}]
      
      IO.inspect process args
    end
    
    defp process([url]) do
      Crawlr.download(url)
        |> :qrly_html.parse_string
    end
    
    defp process(["-q", query | args]) do
      {:ok, tag} = String.to_char_list query
      process(args)
        |> :qrly.filter(tag)
    end
    
    defp process(["-l" | args]) do
      get_href = fn
        ({"a", attrs, _content}) ->
          case List.keyfind attrs, "href", 0 do
            {_, href} -> href
            _ -> nil
          end
        (_) -> nil
      end
      Enum.reject(Enum.map(:qrly.filter(process(args), 'a'), get_href), &nil?(&1))
    end
    
    defp process(["--same", url]) do
      get_origin = fn(url) ->
        [scheme | rest] = String.split url, "://"
        if 0 < length rest do
          [origin | _] = String.split List.first(rest), "/"
          origin
        end
      end
      
      origin = get_origin.(url)
      is_same_origin = fn(url) -> 
        String.starts_with?(url, "/") or origin == get_origin.(url) 
      end
      
      links = process(["-l", url])
        |> Enum.filter(is_same_origin)
        |> Enum.map fn 
          (url = <<"/", _ :: binary>>) -> "http://" <> origin <> url
          (absolute_url) -> absolute_url
        end
      
      IO.puts "#{length links} links"  
      links
    end
    
    defp process(["--race" | urls]) do
      [start, goal | _] = Enum.map(urls, &(elem(String.to_char_list(&1), 1)))
      Crawlr.Racer.start_race start, goal
    end
  end
end