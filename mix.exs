defmodule HtmlCleaner.MixProject do
  use Mix.Project

  def project do
    [
      app: :html_cleaner,
      version: "0.1.0",
      elixir: "~> 1.11",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      preferred_cli_env: [espec: :test],
      elixirc_options: [warnings_as_errors: true]
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:floki, "~> 0.32.0"},
      {:espec, "~> 1.8", only: [:dev, :test]}
    ]
  end
end
