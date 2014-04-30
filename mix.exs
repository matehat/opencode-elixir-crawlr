defmodule Crawlr.Mixfile do
  use Mix.Project

  def project do
    [ app: :crawlr,
      version: "0.0.1",
      deps: deps,
      escript_main_module: Crawlr.Script ]
  end

  # Configuration for the OTP application
  def application do
    [
      applications: [
        #:sasl, :exlager, :oauth, 
        :crypto, :ssl, :public_key, :inets
      ]
    ]
  end

  # Returns the list of dependencies in the format:
  defp deps do
    [ {:qrly, [github: "matehat/qrly"]} ]
  end
end
