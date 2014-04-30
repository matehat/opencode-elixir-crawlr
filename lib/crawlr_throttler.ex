defmodule Crawlr.Throttler do
  @limit 500
  
  def start() do
    pid = spawn Crawlr.Throttler, :loop, [0, :queue.new]
    Process.register pid, Throttler
  end
  
  def wait! do
    send Throttler, {:wait, self}
    receive do any -> any end
  end
  
  def release! do
    send Throttler, :release
  end
  
  def loop(n, waiters) do
    receive do
      :release ->
        case :queue.is_empty(waiters) do
          true -> 
            loop n-1, waiters
          false ->
            {{:value, w}, rest} = :queue.out(waiters)
            send w, :ok
            loop n, rest
        end
      
      {:wait, from} ->
        case n < @limit do
          true ->
            send from, :ok
            loop n+1, waiters
            
          false ->
            loop n, :queue.in(from, waiters)
        end
    end
  end
end