defmodule ShaderBackend.Services.OpenaiService do
  @moduledoc """
  Service for generating shader code using OpenAI API
  """
  require Logger
  require System
  alias HTTPoison

   # Configurable timeout and retry settings
   @default_timeout 60000 # 60 seconds
  #  @max_retries 3
  #  @retry_delay 2_000 # 2 seconds between retries

  @doc """
  Generate shader code based on a description
  """
  def generate_shader(description) do
    timeout =  @default_timeout
      # Retrieve API key from environment variables
    openai_api_key = System.get_env("OPENAI_API_KEY")
    # max_retries = Keyword.get(opts, :max_retries, @max_retries)
    # retry_delay = Keyword.get(opts, :retry_delay, @retry_delay)

    # Prepare request body
    body =
      %{
        "model" => "gpt-4o-2024-08-06",
        "messages" => [
          %{
            "role" => "system",
            "content" =>
              "You are an expert at generating WebGL GLSL shader code. Generate fragment shaders and vertex shaders for object, backgound and shape only.
                For a description that involves shapes like cube, sphere, torus,
                ensure the shader calculates appropriate distances and renders the correct shape.
                shape should be taken from the context.
                Provide ONLY the GLSL shader code for fragment and vertex shaders as a JSON object with keys 'fragmentShader', 'vertexShader', 'shape'.
                 Here is an example for A rotating cube with a gradient background,
                 vertex_shadder for background
                 void main() {
        gl_Position = vec4(position, 1.0);
      }
                fragment_shader for background
                precision mediump float;

                  void main() {
                    vec2 uv = gl_FragCoord.xy / vec2(400.0, 400.0); // Adjust resolution
                    gl_FragColor = vec4(uv.x, uv.y, 1.0, 1.0); // Gradient (blue-based)
                  }

                vertex_shadder for object
                uniform float time;
                void main() {
                    vec3 pos = position;
                    pos.z += sin(time + position.x * 5.0) * 0.1; // Add wavy movement
                    gl_Position = projectionMatrix * modelViewMatrix * vec4(pos, 1.0);
                }

                fragment_shader for object
                precision mediump float;
                void main() {
                    gl_FragColor = vec4(1.0, 0.5, 0.2, 1.0); // Orange color
                }

                shape:
                cube

                "
          },
          %{
            "role" => "user",
            "content" => "Generate a WebGL shader for: #{description}"
          }
        ],
        "response_format" => %{
          "type" => "json_object"
        },
        # Optional parameters to control the response
        "max_tokens" => 8000,
        "temperature" => 0.7,
      }
      |> Jason.encode!()

    # Prepare headers
    headers = [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{openai_api_key}"}
    ]

    # Make API call
    case HTTPoison.post("https://api.openai.com/v1/chat/completions", body, headers, [
      connect_timeout: timeout,
      recv_timeout: timeout,
      timeout: timeout
    ]) do
      {:ok, %HTTPoison.Response{body: response_body, status_code: 200}} ->
        parse_shader_response(response_body)
      {:ok, %HTTPoison.Response{body: response_body, status_code: status_code}} ->
        {:error,
         %{
           message: "API request failed",
           status_code: status_code,
           details: response_body
         }}
      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error,
         %{
           message: "HTTP request failed",
           details: reason
         }}
    end
  end

  # Parse the OpenAI API response
  defp parse_shader_response(response_body) do
    case Jason.decode(response_body) do
      {:ok, %{"choices" => choices}} ->
        # Extract shader code from the first choice
        content =
          choices
          |> List.first()
          |> get_in(["message", "content"])
          |> String.trim()

        # Try to parse the JSON content
        case Jason.decode(content) do
          {:ok, %{"fragmentShader" => fragment, "vertexShader" => vertex, "shape" => shape}} ->
            {:ok, %{fragment_shader: fragment, vertex_shader: vertex, shape: shape}}
          _ ->
            {:error,
             %{
               message: "Failed to parse shader code",
               details: content
             }}
        end
      _ ->
        {:error,
         %{
           message: "Failed to parse API response",
           details: response_body
         }}
    end
  end
end
