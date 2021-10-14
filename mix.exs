defmodule Maxine.MixProject do
  use Mix.Project

  def project do
    [
      name: "Maxine",
      app: :maxine,
      description: "State machines as data for Elixir",
      version: "0.2.5",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto, ">= 3.0.0", optional: true},
      {:deep_merge, ">= 1.0.0", optional: true},
      {:benchee, "~> 0.11", only: :dev},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
  
  defp package do 
    %{
      licenses: ["MIT"],
      maintainers: ["Erik Cameron"],
      links: %{"GitHub" => "https://github.com/erikcameron/maxine"}
    }
  end
end
