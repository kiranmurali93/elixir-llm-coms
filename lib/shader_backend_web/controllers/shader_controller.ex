defmodule ShaderBackendWeb.ShaderController do
  use ShaderBackendWeb, :controller

  alias ShaderBackend.Services.OpenaiService

  def generate_shader(conn, %{"description" => description}) do
    case OpenaiService.generate_shader(description) do
      {:ok, shader_code} ->
        json(conn, %{
          shader_code: shader_code,
          status: "success"
        })

      {:error, error_details} ->
        conn
        |> put_status(400)
        |> json(%{
          error: "Failed to generate shader",
          details: error_details
        })
    end
  end
end
