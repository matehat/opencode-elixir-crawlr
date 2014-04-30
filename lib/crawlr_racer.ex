defmodule Crawlr.Racer do
  defrecord Page, parent: nil, url: '', pid: nil, goal: ""

  def start_child(this = Page[], url) do
    # IO.write "."
    if url == this.goal do
      IO.puts "\n== Succès après #{Crawlr.Racer.Counter.count} liens rencontrés! =="
      send this.parent.pid, :done
      print_path Page[url: url, parent: this]
      IO.puts "===="
    else
      if Crawlr.Racer.DeDoubler.should_crawl?(url) do
        Crawlr.Racer.Counter.increment!
        spawn Crawlr.Racer, :start, [[parent: this, url: url, goal: this.goal]]
      end
    end
  end

  def start_race(start, goal) do
    Crawlr.Racer.DeDoubler.start
    Crawlr.Racer.Counter.start
    
    # IO.puts " -> #{start}"
    spawn Crawlr.Racer, :start, [[url: start, goal: goal, parent: Page[pid: Kernel.self]]]
    wait!
  end

  def start(args) do
    parent = args[:parent]
    fetch Page.new(
      parent: parent, 
      pid: self, 
      goal: args[:goal], 
      url: args[:url]
    )
  end

  defp fetch(this = Page[]) do
    url = this.url
    origin = get_origin url
  
    data = Crawlr.download(url)
    data
      |> :qrly_html.parse_string
      |> :qrly.filter('a')
    
      |> Enum.map(fn
          ({"a", attrs, _content}) ->
            case List.keyfind attrs, "href", 0 do
              {_, href} -> href
              _ -> nil
            end
          (_) -> nil
        end)
    
      |> Enum.reject(&nil?(&1))
      |> Enum.filter(fn(url) -> 
           String.starts_with?(url, "/wiki") or origin == get_origin(url) 
         end)
         
      |> Enum.reject(fn(url) -> 
           Enum.any? excluded_prefixes, &(String.starts_with?(url, "/wiki/" <> &1))
         end)
       
      |> Enum.map(fn 
           (url = <<"/", _ :: binary>>) -> "http://" <> origin <> url
           (absolute_url) -> absolute_url
         end)
         
      |> Enum.map(fn (url) -> 
            [url | _] = String.split url, "#"
            url
         end)
      
      |> Enum.uniq
      |> Enum.map(&:erlang.binary_to_list/1)
      |> Enum.shuffle
      |> Enum.each(fn (url) ->
        start_child this, url
      end)

    wait! this.parent.pid
  end

  defp print_path(this) do
    case this.parent do
      nil -> :ok
      parent ->
        print_path(parent)
        IO.puts this.url
    end
  end
  
  defp excluded_prefixes do
    ["Wikipedia:", "Help:", "Portal:", "File:", "Special:", "Talk:", "Category:", "Main_Page"]
  end
  
  defp wait!(pid \\ nil) do
    receive do 
      :done ->
        case pid do
          nil -> :done
          _ -> send pid, :done
        end
    end
  end

  defp get_origin(url) when is_binary(url) do
    [_scheme | rest] = String.split url, "://"
    if 0 < length rest do
      [origin | _] = String.split List.first(rest), "/"
      origin
    end
  end
  
  defp get_origin(url) do
    get_origin :erlang.list_to_binary url
  end
  
  defmodule DeDoubler do
    def start() do
      pid = spawn DeDoubler, :loop, [HashSet.new]
      Process.register pid, DeDoubler
    end
    
    def should_crawl?(url) do
      send DeDoubler, {:should_crawl, self, url}
      receive do any -> any end
    end
    
    def loop(set) do
      receive do
        {:should_crawl, from, url} ->
          case Set.member?(set, url) do
            true -> 
              send from, false
              loop set
            
            false ->
              send from, true
              loop Set.put set, url
          end
      end
    end
  end
  
  defmodule Counter do
    def start() do
      pid = spawn Counter, :loop, [0]
      Process.register pid, Counter
    end
    
    def increment! do
      send Counter, :increment
    end
    
    def count do
      send Counter, {:count, self}
      receive do any -> any end
    end
    
    def loop(n) do
      receive do 
        :increment -> loop n+1
        {:count, from} ->
          send from, n
          loop n
      end
    end
  end
end