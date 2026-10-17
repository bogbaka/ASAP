from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "ASAP API"
    app_env: str = "development"
    debug: bool = True
    database_url: str

    jwt_secret_key: str
    access_token_expire_minutes: int = 30

    otp_hmac_secret: str 

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()