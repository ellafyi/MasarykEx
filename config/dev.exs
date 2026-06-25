import Config

# Repo connection for dev is configured in runtime.exs (so it can read .env).

config :masaryk_ex_web, MasarykExWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4000],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "/j58rI/eqFsgXOW3duz23oglWbfN278JQ7ml8UfqDYtzxcYD2Cre/zehWKFo6e9V"
