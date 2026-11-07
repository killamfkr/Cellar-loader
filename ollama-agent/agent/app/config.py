from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="AGENT_")

    ollama_base_url: str = "http://ollama:11434"
    default_model: str = "qwen2.5-coder:7b"
    workspace_root: str = "/workspace"
    max_agent_steps: int = 40
    shell_timeout_sec: int = 120
    host: str = "0.0.0.0"
    port: int = 8080


settings = Settings()
