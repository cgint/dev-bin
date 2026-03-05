import os
from dotenv import load_dotenv

load_dotenv()

access_pwd = os.environ.get("ACCESS_PWD")
if not access_pwd:
    raise ValueError("Environment variable ACCESS_PWD is not set")

MODEL_NAME_GEMINI_2_5_FLASH = "gemini-2.5-flash"
MODEL_NAME_GEMINI_2_5_PRO = "gemini-2.5-pro"

default_llm_model_name = os.getenv("GEMINI_MODEL_NAME", MODEL_NAME_GEMINI_2_5_FLASH)
print(f"Using model: {default_llm_model_name}")


debug_outputs = os.getenv("DEBUG_OUTPUTS", "false").lower() == "true"
nav_rss_debug = debug_outputs
chat_coordinator_debug = debug_outputs
storage_path = "./storage"

os.makedirs(storage_path, exist_ok=True)