#!/usr/bin/env -S uv run --script
# /// script
# dependencies = [
#     "google-genai"
# ]
# requires-python = ">=3.12"
# ///
"""
High-quality audio transcription using Gemini 2.5 Pro API.
Handles large MP3 files by uploading them first, then processing for transcription.
"""

import os
import sys
import time
import json
import logging
import hashlib
import threading
from pathlib import Path
from typing import Optional, Dict, Any, List
from dataclasses import dataclass
from datetime import datetime
import concurrent.futures

from google import genai
from google.genai import types as genai_types

import subprocess
import math

class AudioSplitter:
    @staticmethod
    def convert_to_mp3(input_file: Path, output_file: Path) -> Path:
        """
        Converts an audio file to MP3 format using ffmpeg, if it doesn't already exist.

        Args:
            input_file (Path): The path to the input audio file (e.g., .m4a).
            output_file (Path): The path for the output .mp3 file.

        Returns:
            Path: The path to the resulting .mp3 file.
        """
        if output_file.exists():
            print(f"Converted mp3-file already exists: {output_file}")
            return output_file

        print(f"Converting {input_file} to {output_file}...")
        try:
            command = [
                'ffmpeg',
                '-i', str(input_file),
                str(output_file),
                '-y'  # Overwrite output files without asking
            ]
            subprocess.run(command, check=True, capture_output=True, text=True)
            print(f"Successfully converted to {output_file}")
        except subprocess.CalledProcessError as e:
            print(f"Error converting {input_file} to mp3: {e.stderr}")
            raise
        
        return output_file
        
    """
    A utility class for splitting audio files into smaller chunks.
    It uses ffprobe to get audio duration and ffmpeg to perform the splitting.
    """

    @staticmethod
    def get_audio_duration(file_path: str) -> float | None:
        """
        Retrieves the duration of an audio file in seconds using ffprobe.

        Args:
            file_path (str): The path to the audio file.

        Returns:
            float | None: The duration of the audio file in seconds, or None if an error occurs.
        """
        try:
            command = [
                'ffprobe',
                '-v', 'error',
                '-show_entries', 'format=duration',
                '-of', 'default=noprint_wrappers=1:nokey=1',
                file_path
            ]
            result = subprocess.run(command, capture_output=True, text=True, check=True)
            return float(result.stdout.strip())
        except (subprocess.CalledProcessError, FileNotFoundError, ValueError) as e:
            print(f"Error getting duration for {file_path}: {e}")
            return None

    @staticmethod
    def split_audio_chunk(input_file: str, output_file: str, start_time: float, duration: float) -> None:
        """
        Splits a single chunk of the audio file using ffmpeg.

        Args:
            input_file (str): The path to the input audio file.
            output_file (str): The path for the output audio chunk.
            start_time (float): The start time in seconds for the chunk.
            duration (float): The duration in seconds of the chunk.
        """
        try:
            command = [
                'ffmpeg',
                '-i', input_file,
                '-ss', str(start_time),
                '-t', str(duration),
                '-c', 'copy',  # Copy streams without re-encoding for speed
                output_file,
                '-y'  # Overwrite output files without asking
            ]
            subprocess.run(command, check=True, capture_output=True, text=True)
            print(f"Created {output_file}")
        except subprocess.CalledProcessError as e:
            print(f"Error splitting {output_file}: {e.stderr}")
            raise

    @staticmethod
    def auto_split_audio(
        input_file: Path, 
        output_dir: Path,
        max_duration_sec: int = 1800, 
        min_slice_duration_sec: int = 600
    ) -> List[Path]:
        """
        Automatically splits an audio file into chunks of optimal length.

        Args:
            input_file (Path): The path to the input audio file.
            output_dir (Path): The directory to save the chunks.
            max_duration_sec (int): The maximum desired duration for each audio chunk.
            min_slice_duration_sec (int): The minimum acceptable duration for a slice.

        Returns:
            List[Path]: A list of paths to the created audio chunks, or the original file path if not split.
        """
        total_duration = AudioSplitter.get_audio_duration(str(input_file))
        if total_duration is None:
            return []

        print(f"Total audio duration: {total_duration:.2f} seconds.")

        if total_duration <= max_duration_sec:
            print("Audio file is within the duration limit, no splitting needed.")
            return [input_file]

        num_slices = math.ceil(total_duration / max_duration_sec)

        if (total_duration % max_duration_sec) < min_slice_duration_sec and num_slices > 1:
            num_slices -= 1
            print(f"Adjusting number of slices to {num_slices} to avoid a short final chunk.")

        if num_slices <= 1:
            print("Audio file is too short to be split into multiple chunks based on current settings.")
            return [input_file]

        slice_duration = total_duration / num_slices
        print(f"Splitting into {num_slices} chunks of approximately {slice_duration:.2f} seconds each.")

        output_dir.mkdir(parents=True, exist_ok=True)
        
        chunks_to_process = []
        output_files = []
        for i in range(num_slices):
            start_time = i * slice_duration
            output_file = output_dir / f"{input_file.stem}_part_{i+1}{input_file.suffix}"
            chunks_to_process.append((str(input_file), str(output_file), start_time, slice_duration))
            output_files.append(output_file)

        with concurrent.futures.ThreadPoolExecutor() as executor:
            futures = [executor.submit(AudioSplitter.split_audio_chunk, *chunk) for chunk in chunks_to_process]
            concurrent.futures.wait(futures)
        
        return output_files



# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@dataclass
class ProcessingResult:
    """Result of audio transcription."""
    output: str
    model_used: str
    file_name: str
    file_size_mb: float
    processing_time_seconds: float
    token_usage: Dict[str, Any]
    cost_estimation: Dict[str, float]
    timestamp: str
    finish_reason: Optional[str] = None
    safety_ratings: Optional[List[Dict[str, Any]]] = None


def _sha256_file(path: Path, chunk_size: int = 1024 * 1024) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(chunk_size)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


class UploadCache:
    """
    Small JSON cache mapping audio content hash -> remote file name.
    Keeps uploads reusable across runs (optional).
    """

    def __init__(self, cache_path: Path):
        self.cache_path = cache_path
        self._lock = threading.Lock()
        self._data: dict[str, Any] = {"version": 1, "entries": {}}
        self._load()

    def _load(self) -> None:
        with self._lock:
            if not self.cache_path.exists():
                return
            try:
                raw = json.loads(self.cache_path.read_text(encoding="utf-8"))
                if isinstance(raw, dict) and raw.get("version") == 1 and isinstance(raw.get("entries"), dict):
                    self._data = raw
            except Exception:
                # Corrupt cache should not break transcription; treat as empty.
                self._data = {"version": 1, "entries": {}}

    def _persist(self) -> None:
        self.cache_path.parent.mkdir(parents=True, exist_ok=True)
        self.cache_path.write_text(json.dumps(self._data, ensure_ascii=False, indent=2), encoding="utf-8")

    def get_remote_name(self, sha256_hex: str, expected_size_bytes: int) -> str | None:
        with self._lock:
            entry = self._data.get("entries", {}).get(sha256_hex)
            if not isinstance(entry, dict):
                return None
            if entry.get("size_bytes") != expected_size_bytes:
                return None
            remote_name = entry.get("remote_name")
            return remote_name if isinstance(remote_name, str) and remote_name else None

    def set_remote_name(self, sha256_hex: str, size_bytes: int, remote_name: str) -> None:
        with self._lock:
            entries = self._data.setdefault("entries", {})
            entries[sha256_hex] = {
                "remote_name": remote_name,
                "size_bytes": size_bytes,
                "updated_at": datetime.now().isoformat(),
            }
            self._persist()


class GeminiAudioTranscriber:
    """High-quality audio transcription using Gemini"""
    
    def __init__(self, api_key: Optional[str] = None, model_name: str = "gemini-2.5-flash"):
        """Initialize the transcriber with API key."""
        self.api_key = api_key or os.getenv('GEMINI_API_KEY')
        if not self.api_key:
            raise ValueError("GEMINI_API_KEY environment variable is required")
        
        # Configure Gemini
        self.client = genai.Client(api_key=self.api_key)
        
        # Model configuration
        self.model_name = model_name
        self.generation_config = genai_types.GenerationConfig(
            temperature=0.1,  # Low temperature for consistent transcription
            max_output_tokens=65536,
            top_p=0.8,
            top_k=40
        )
        
        # Safety settings for transcription (allow most content)
        self.safety_settings = {
            genai_types.HarmCategory.HARM_CATEGORY_HARASSMENT: genai_types.HarmBlockThreshold.BLOCK_NONE,
            genai_types.HarmCategory.HARM_CATEGORY_HATE_SPEECH: genai_types.HarmBlockThreshold.BLOCK_NONE,
            genai_types.HarmCategory.HARM_CATEGORY_SEXUALLY_EXPLICIT: genai_types.HarmBlockThreshold.BLOCK_NONE,
            genai_types.HarmCategory.HARM_CATEGORY_DANGEROUS_CONTENT: genai_types.HarmBlockThreshold.BLOCK_NONE,
        }
        
        # Supported audio formats
        self.supported_formats = {
            '.mp3': 'audio/mp3',
            '.wav': 'audio/wav',
            '.aiff': 'audio/aiff',
            '.aac': 'audio/aac',
            '.ogg': 'audio/ogg',
            '.flac': 'audio/flac'
        }
        
        # Pricing for cost estimation (USD per 1M tokens)
        self.pricing = { 
            'gemini-2.5-pro': {
                'input_price_per_million': 1.25,  # For prompts <= 200K tokens
                'input_price_per_million_high': 2.50,  # For prompts > 200K tokens
                'output_price_per_million': 10.00,  # For outputs <= 200K tokens
                'output_price_per_million_high': 15.00  # For outputs > 200K tokens
            },
            'gemini-2.5-flash': {
                'input_price_per_million': 0.3,  # For prompts <= 200K tokens
                'input_price_per_million_high': 0.3,  # For prompts > 200K tokens
                'output_price_per_million': 2.50,  # For outputs <= 200K tokens
                'output_price_per_million_high': 2.50  # For outputs > 200K tokens
            },
            'gemini-3-flash-preview': {
                'input_price_per_million': 0.50,
                'input_price_per_million_high': 0.50,
                'output_price_per_million': 3.00,
                'output_price_per_million_high': 3.00
            }
        }

    def validate_audio_file(self, file_path: Path) -> tuple[bool, str]:
        """Validate if the audio file is supported and accessible."""
        if not file_path.exists():
            return False, f"File does not exist: {file_path}"
        
        if not file_path.is_file():
            return False, f"Path is not a file: {file_path}"
        
        file_extension = file_path.suffix.lower()
        if file_extension not in self.supported_formats:
            return False, f"Unsupported format: {file_extension}. Supported: {list(self.supported_formats.keys())}"
        
        file_size_mb = file_path.stat().st_size / (1024 * 1024)
        if file_size_mb > 2000:  # 2GB limit
            return False, f"File too large: {file_size_mb:.1f}MB. Maximum: 2000MB"
        
        return True, f"Valid audio file: {file_size_mb:.1f}MB"

    def upload_audio_file(self, file_path: Path) -> genai_types.File:
        """Upload audio file to Gemini Files API."""
        logger.info(f"Uploading {file_path.name}...")
        
        try:
            # Upload file using the correct API
            uploaded_file = self.client.files.upload(file=str(file_path))
            
            logger.info(f"File uploaded successfully: {uploaded_file.name}")
            return uploaded_file
            
        except Exception as e:
            logger.error(f"Failed to upload file: {e}")
            raise

    def _calculate_cost(self, token_usage: Dict[str, Any]) -> Dict[str, float]:
        """Calculate estimated cost based on token usage."""
        if self.model_name not in self.pricing:
            supported = ', '.join(self.pricing.keys())
            raise ValueError(
                f"No pricing configured for model '{self.model_name}'. "
                f"Supported models: {supported}. "
                "Add pricing for this model in the pricing dict."
            )
        prompt_tokens = token_usage.get('prompt_token_count', 0)
        output_tokens = token_usage.get('candidates_token_count', 0)
        
        # Determine pricing tier based on prompt size
        input_price = (self.pricing[self.model_name]['input_price_per_million'] 
                      if prompt_tokens <= 200000 
                      else self.pricing[self.model_name]['input_price_per_million_high'])
        
        output_price = (self.pricing[self.model_name]['output_price_per_million']
                       if prompt_tokens <= 200000
                       else self.pricing[self.model_name]['output_price_per_million_high'])
        
        input_cost = (prompt_tokens / 1_000_000) * input_price
        output_cost = (output_tokens / 1_000_000) * output_price
        total_cost = input_cost + output_cost
        
        return {
            'input_cost': input_cost,
            'output_cost': output_cost,
            'total_cost': total_cost,
            'input_price_tier': input_price,
            'output_price_tier': output_price
        }
    
    def _get_finish_reason(self, response: genai_types.GenerateContentResponse) -> str:
        finish_reason_as_text = "STOP"
        if hasattr(response, 'candidates') and response.candidates:
            if hasattr(response.candidates[0], 'finish_reason') and response.candidates[0].finish_reason:
                finish_reason_as_text = response.candidates[0].finish_reason.name if hasattr(response.candidates[0].finish_reason, 'name') else str(response.candidates[0].finish_reason)
            logger.info(f"Finish reason: {finish_reason_as_text}")
        else:
            logger.warning("No candidates found in the response.")
        
        return finish_reason_as_text
    
    def _get_safety_ratings(self, response: genai_types.GenerateContentResponse) -> list[dict[str, str]]:
        safety_ratings_as_list = []
        if hasattr(response, 'candidates') and response.candidates:
            if hasattr(response.candidates[0], 'safety_ratings') and response.candidates[0].safety_ratings:
                logger.info(f"Safety ratings: {response.candidates[0].safety_ratings}")
                safety_ratings_as_list = [
                    {
                        "category": getattr(rating.category, 'name', str(rating.category)) if hasattr(rating, 'category') else 'N/A',
                        "probability": getattr(rating.probability, 'name', str(rating.probability)) if hasattr(rating, 'probability') else 'N/A',
                        "severity": getattr(rating, 'severity', {}).get('name', 'N/A') if hasattr(rating, 'severity') else 'N/A'
                    }
                    for rating in response.candidates[0].safety_ratings
                ]
            else:
                logger.info("No safety ratings available for the candidate.")
        else:
            logger.warning("No candidates found in the response.")
        
        return safety_ratings_as_list
    
    def _get_output_text(self, response: genai_types.GenerateContentResponse) -> str:
        finish_reason_as_text = self._get_finish_reason(response)
        output_text = ""
        response_has_text = hasattr(response, 'text') and response.text is not None
        pure_text: str | None = response.text if response_has_text else None
        # Check finish reason first to avoid accessing response.text when it will fail
        if finish_reason_as_text == "RECITATION":
            output_text = "**TRANSCRIPTION BLOCKED**: The model detected potential copyrighted material and refused to transcribe this audio file."
            output_text = output_text + "\n\n" + (pure_text if pure_text else "Response did not contain text.")
            logger.warning(f"Transcription blocked due to potential copyrighted material detection - response_has_text={response_has_text}")
        elif finish_reason_as_text == "STOP" and pure_text is not None:
            output_text = pure_text
        elif finish_reason_as_text == "MAX_TOKENS" and pure_text is not None:
            output_text = pure_text
            logger.warning("Model hit MAX_TOKENS; returning partial output (will retry same request).")
        else:
            output_text = f"## TRANSCRIPTION FAILED Finish reason: {finish_reason_as_text}"
            output_text = output_text + "\n\n" + (pure_text if pure_text else "Response did not contain text.")
            logger.error(f"No text found in the response. Finish reason: {finish_reason_as_text} - response_has_text={response_has_text}")
        
        return output_text
        
    
    def validate_and_upload(
        self,
        file_path: Path,
        *,
        upload_cache: UploadCache | None = None,
        reuse_remote_uploads: bool = False,
    ) -> genai_types.File:
        # Validate file
        logger.info(f"Validating: {file_path.name}")
        is_valid, message = self.validate_audio_file(file_path)
        if not is_valid:
            raise ValueError(message)
        
        logger.info(message)

        if reuse_remote_uploads and upload_cache is not None:
            sha256_hex = _sha256_file(file_path)
            size_bytes = file_path.stat().st_size
            cached_remote_name = upload_cache.get_remote_name(sha256_hex, size_bytes)
            if cached_remote_name:
                try:
                    logger.info(f"Reusing remote upload from cache: {cached_remote_name}")
                    return self.client.files.get(name=cached_remote_name)
                except Exception:
                    logger.info(f"Cached remote upload not found anymore, will re-upload: {cached_remote_name}")

            logger.info(f"Starting upload of: {file_path.name}")
            uploaded = self.upload_audio_file(file_path)
            remote_name: str | None = getattr(uploaded, "name", None)
            if not remote_name:
                raise ValueError("Uploaded file did not return a remote name.")
            upload_cache.set_remote_name(sha256_hex, size_bytes, remote_name)
            return uploaded

        logger.info(f"Starting upload of: {file_path.name}")
        return self.upload_audio_file(file_path)
        
    def process_prompt(
        self,
        contents: list[genai_types.ContentUnionDict],
        file_path: Path,
        generate_config_params: Dict[str, Any],
        raw_output_file: Optional[Path] = None,
        max_attempts: int = 3
    ) -> ProcessingResult:
        """
        Transcribe audio file using Gemini 2.5 Pro/Flash.
        
        Args:
            file_path: Path to the audio file
            raw_output_file: Path to save raw response JSON (optional)
            output_file: Path to save output file (optional)
        
        Returns:
            TranscriptionResult with transcript and metadata
        """
        
        start_time = time.time()
        
        # Generate transcription
        logger.info(f"Generating transcription with model {self.model_name}...")

        output_text = ""
        finish_reason_as_text = "STOP"
        safety_ratings_as_list: list[dict[str, str]] = []
        token_usage: Dict[str, Any] = {}

        for cur_attempt in range(1, max_attempts + 1):
            response: genai_types.GenerateContentResponse = self.client.models.generate_content(
                model=self.model_name,
                contents=contents,
                config=genai_types.GenerateContentConfig(**generate_config_params)
            )

            # Log finish reason and other diagnostics
            finish_reason_as_text = self._get_finish_reason(response)
            attempt_text = self._get_output_text(response)
            safety_ratings_as_list = self._get_safety_ratings(response)

            # Extract token usage information
            if hasattr(response, 'usage_metadata') and response.usage_metadata:
                token_usage = {
                    'prompt_token_count': getattr(response.usage_metadata, 'prompt_token_count', 0),
                    'cached_content_token_count': getattr(response.usage_metadata, 'cached_content_token_count', 0),
                    'candidates_token_count': getattr(response.usage_metadata, 'candidates_token_count', 0),
                    'total_token_count': getattr(response.usage_metadata, 'total_token_count', 0),
                }

            # Save raw response as JSON if path provided
            if raw_output_file:
                raw_response_dict = {
                    'raw_response': str(response),
                    'metadata': {
                        'file_name': file_path.name,
                        'timestamp': datetime.now().isoformat(),
                        'model_used': self.model_name,
                        'finish_reason': finish_reason_as_text,
                        'safety_ratings': safety_ratings_as_list,
                        'token_usage': token_usage
                    }
                }
                
                # Ensure parent directory exists
                raw_output_file.parent.mkdir(parents=True, exist_ok=True)
                
                with open(str(raw_output_file).replace(".json", f"_{cur_attempt}.json"), 'w', encoding='utf-8') as f:
                    json.dump(raw_response_dict, f, ensure_ascii=False, indent=2)
                
                logger.info(f"Raw response with finish_reason = {finish_reason_as_text} saved to: {raw_output_file}")
            
            if finish_reason_as_text == "STOP":
                output_text = attempt_text
                break

            output_text = attempt_text
            if cur_attempt < max_attempts:
                logger.info(f"Retrying due to finish_reason={finish_reason_as_text} (attempt {cur_attempt}/{max_attempts})...")
                time.sleep(0.5)
                continue
        
        # Calculate costs
        cost_estimation = self._calculate_cost(token_usage)
        
        processing_time = time.time() - start_time
        file_size_mb = file_path.stat().st_size / (1024 * 1024)
        
        # Log cost information
        logger.info(f"Transcription completed in {processing_time:.1f}s")
        logger.info(f"Token usage: {token_usage}")
        logger.info(f"Estimated cost: ${cost_estimation['total_cost']:.6f}")
        
        result = ProcessingResult(
            output=output_text,
            model_used=self.model_name,
            file_name=file_path.name,
            file_size_mb=file_size_mb,
            processing_time_seconds=processing_time,
            token_usage=token_usage,
            cost_estimation=cost_estimation,
            timestamp=datetime.now().isoformat(),
            finish_reason=finish_reason_as_text,
            safety_ratings=safety_ratings_as_list
        )
        
        return result
        

    def delete_uploaded_file(self, uploaded_file: genai_types.File) -> None:
        if not uploaded_file.name:
            raise ValueError("The name if uploaded_file is not allowed to be None.")
        # Clean up uploaded file
        try:
            self.client.files.delete(name=uploaded_file.name)
            logger.info(f"Uploaded file deleted successfully: {uploaded_file.name}")
        except Exception as e:
            logger.warning(f"Failed to clean up uploaded file: {e}")


    def save_output(self, result: ProcessingResult, output_path: Path, headline: str, add_metadata: bool) -> None:
        """Save transcription result to file."""
        
        # Adjust filename if finish_reason is not STOP
        problem_output_path = output_path.with_name(f"{output_path.stem}_problem{output_path.suffix}")
        problem_output_path.unlink() if problem_output_path.exists() else None
        if result.finish_reason != "STOP":
            output_path = problem_output_path

        content: list[str] = [f"## {headline}", "", result.output]

        if add_metadata:
            content.extend([
                f"# Transcript: {result.file_name}",
                "",
                f"**Generated:** {result.timestamp}",
                f"**Model:** {result.model_used}",
                f"**File Size:** {result.file_size_mb:.1f} MB",
                f"**Processing Time:** {result.processing_time_seconds:.1f} seconds",
                f"**Estimated Cost:** ${result.cost_estimation['total_cost']:.6f}",
                f"**Finish Reason:** {result.finish_reason or 'N/A'}",
                "",
                "## Safety Ratings",
            ])

            if result.safety_ratings:
                for rating in result.safety_ratings:
                    content.append(f"- Category: {rating.get('category', 'N/A')}, Probability: {rating.get('probability', 'N/A')}, Severity: {rating.get('severity', 'N/A')}")
            else:
                content.append("- No safety ratings available.")
            
            content.extend([
                "",
                "## Token Usage",
                f"- Prompt Tokens: {result.token_usage.get('prompt_token_count', 'N/A')}",
                f"- Output Tokens: {result.token_usage.get('candidates_token_count', 'N/A')}",
                f"- Total Tokens: {result.token_usage.get('total_token_count', 'N/A')}",
                "",
                "## Transcript",
                "",
                result.output
            ])

        output_path.write_text("\n".join(content), encoding='utf-8')
        logger.info(f"Transcript saved to: {output_path}")

def process_this(
    transcriber: GeminiAudioTranscriber,
    transcript_config: Dict[str, Any],
    file_path: Path,
    transcribe_output_path: Path,
    transcribe_raw_output_file: Path,
    *,
    upload_cache: UploadCache | None = None,
    reuse_remote_uploads: bool = False,
) -> ProcessingResult:
    uploaded_file: genai_types.File | None = None
    try:
        # Transcription
        uploaded_file = transcriber.validate_and_upload(
            file_path,
            upload_cache=upload_cache,
            reuse_remote_uploads=reuse_remote_uploads,
        )
        print("Starting transcript for", transcribe_output_path)
        # Note: transcribe_raw_output_file is not defined in this scope, assuming it's a global or needs to be passed.
        # For now, I'll assume it's accessible or will be defined.
        transcribe_result = transcriber.process_prompt([transcribe_prompt, uploaded_file], file_path, transcript_config, transcribe_raw_output_file)
        transcriber.save_output(transcribe_result, transcribe_output_path, "Transcript", add_metadata=False)
        return transcribe_result
    except Exception as e:
        logger.exception(f"Failed to process {file_path}: {e}")
        raise e
    finally:
        if uploaded_file and not reuse_remote_uploads:
            print(f"Deleting uploaded file: {uploaded_file.name}")
            transcriber.delete_uploaded_file(uploaded_file)

summarize_prompt_parts = [
    "Erstellen Sie eine Zusammenfassung des Sitzungsprotokolls in folgenden Abschnitten.",
    "- Abschnitt 1: Wer macht was bis wann",
    "- Abschnitt 2: Getroffenen Entscheidungen",
    "- Abschnitt 3: Die wichtigsten besprochenen Themen",
    "- Abschnitt 4: Bemerkenswert lange thematisierte Themen, Aspekte und Unklarheiten",
    "- Abschnitt 5: allgemeinen Zusammenfassung"
]
summarize_prompt = "\n".join(summarize_prompt_parts)


transcribe_prompt_parts = [
    "Bitte erstellen Sie eine hochwertige, genaue Transkription dieser Audiodatei.",
    "Anforderungen:",
    "- Halten Sie die exakten gesprochenen Wörter und Phrasen bei",
    "- Verwenden Sie korrekte Interpunktion und Groß-/Kleinschreibung",
    "- Bewahren Sie natürliche Sprechmuster und Pausen",
    "- Fügen Sie keine Zeitstempel im MM:SS-Format ein",
    "- Kennzeichnen Sie verschiedene Sprecher mit ihrem Namen, mit dem diese angesprochen wurden",
    "- Kennzeichnen Sie verschiedene Sprecher jeweils nur bei einem Wechsel des Sprechers.",
    "",
    "Formatieren Sie die Ausgabe als sauberen, lesbaren Text, der für die Dokumentation geeignet ist.",
    "Konzentrieren Sie sich auf Genauigkeit und Klarheit."
]
transcribe_prompt = "\n".join(transcribe_prompt_parts)


def main() -> None:
    """Command-line interface for audio transcription."""
    import argparse
    
    parser = argparse.ArgumentParser(description="High-quality audio transcription using Gemini 2.5")
    parser.add_argument("file", help="Audio file to transcribe (e.g., .mp3, .m4a)")
    parser.add_argument(
        "--reuse-remote-uploads",
        action="store_true",
        help="Reuse previously uploaded audio chunks via a local cache (avoids re-uploading across runs).",
    )
    parser.add_argument(
        "--upload-cache-file",
        default="./transcripts/.gemini_upload_cache.json",
        help="Path to JSON upload cache file (used with --reuse-remote-uploads).",
    )
    
    args = parser.parse_args()
    
    output_dir = Path("./transcripts/")
    raw_output_dir = output_dir
    temp_chunk_dir = output_dir # / "temp_audio_chunks"

    input_file_path = Path(args.file)
    if not input_file_path.exists():
        logger.error(f"Input file does not exist, skipping: {input_file_path}")
        sys.exit(1)

    overall_base_name = input_file_path.stem
    # Create summary file path
    overall_summarize_raw_output_path = raw_output_dir / f"{overall_base_name}_summary_raw_response.json"
    overall_summarize_final_input_path = output_dir / f"{overall_base_name}_summary_input.md"
    overall_summarize_output_path = output_dir / f"{overall_base_name}_summary.md"
    
    # Create transcript file path
    # overall_transcribe_raw_output_file = raw_output_dir / f"{overall_base_name}_transcript_raw_response.json"
    overall_transcribe_output_path = output_dir / f"{overall_base_name}_transcript.md"

    # Early check: skip if output file already exists
    if overall_summarize_output_path.exists() and overall_transcribe_output_path.exists():
        logger.info(f"Both output files already exist, skipping: {input_file_path}")
        sys.exit(0)
    
    # Handle each file type to .mp3 conversion
    if input_file_path.suffix.lower() != '.mp3':
        file_to_process = AudioSplitter.convert_to_mp3(input_file_path, input_file_path.with_suffix('.mp3'))
    else:
        print("Input file is already mp3 format - using that directly.")
        file_to_process = input_file_path

    # THINKING_MIN_FOR_PRO=128
    # model_name = "gemini-2.5-flash"
    model_name = "gemini-3-flash-preview"
    TEMPERATURE = 1
    MAX_OUTPUT_TOKENS_SUMMARY = 8192
    MAX_OUTPUT_TOKENS_TRANSCRIPT = 16384
    thinking_budget = 0
    summarize_config: Dict[str, Any] = {
        "temperature": TEMPERATURE,
        "max_output_tokens": MAX_OUTPUT_TOKENS_SUMMARY,
        "thinking_config": genai_types.ThinkingConfig(
            thinking_budget=thinking_budget,
            include_thoughts=False
        )
    }
    transcript_config: Dict[str, Any] = {
        "temperature": TEMPERATURE,
        "max_output_tokens": MAX_OUTPUT_TOKENS_TRANSCRIPT,
        "thinking_config": genai_types.ThinkingConfig(
            thinking_budget=thinking_budget,
            include_thoughts=False
        )
    }
    
    try:
    
        # Split audio file if it's too long
        audio_files_to_process = AudioSplitter.auto_split_audio(file_to_process, temp_chunk_dir)
        if len(audio_files_to_process) == 0:
            logger.info("AudioSplitter.auto_split_audio returned an empty list!")
            sys.exit(1)
        
        is_split = len(audio_files_to_process) > 1

        # List to hold (index, transcript) tuples for sorting later
        processed_transcripts: list[tuple[int, str]] = []
        
        transcriber = GeminiAudioTranscriber(model_name=model_name)
        total_cost: float = 0
        total_processing_time_sec: float = 0

        upload_cache: UploadCache | None = None
        if args.reuse_remote_uploads:
            upload_cache = UploadCache(Path(args.upload_cache_file))

        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
            future_to_index = {}
            for i, file_path in enumerate(audio_files_to_process, 1):
                logger.info(f"Processing file {i}/{len(audio_files_to_process)}: {file_path.name}")
                
                part_base_name = file_to_process.stem if not is_split else f"{file_to_process.stem}_part_{i}"

                # Create transcript file path
                transcribe_raw_output_path = raw_output_dir / f"{part_base_name}_transcript_raw_response.json"
                transcribe_output_path = output_dir / f"{part_base_name}_transcript.md"

                # Early check: skip if output file already exists
                if transcribe_output_path.exists():
                    logger.info(f"Transcript file already exists, loading content: {transcribe_output_path}")
                    # Assumes the file starts with "## Transcript\n\n"
                    transcript_content = transcribe_output_path.read_text(encoding='utf-8').split("## Transcript\n\n")[1]
                    processed_transcripts.append((i - 1, transcript_content))
                    continue
                
                future = executor.submit(
                    process_this,
                    transcriber,
                    transcript_config,
                    file_path,
                    transcribe_output_path,
                    transcribe_raw_output_path,
                    upload_cache=upload_cache,
                    reuse_remote_uploads=args.reuse_remote_uploads,
                )
                future_to_index[future] = i - 1 # Use 0-based index

            for future in concurrent.futures.as_completed(future_to_index):
                index = future_to_index[future]
                file_path = audio_files_to_process[index]
                try:
                    transcribe_result: ProcessingResult = future.result()
                    if transcribe_result.finish_reason == "STOP":
                        processed_transcripts.append((index, transcribe_result.output))
                    else:
                        print(f"Not adding transcript for {file_path.name} as finish_reason='{transcribe_result.finish_reason}'!")
                    total_cost += transcribe_result.cost_estimation['total_cost']
                    total_processing_time_sec += transcribe_result.processing_time_seconds
                except Exception as exc:
                    logger.exception(f"{file_path.name} generated an exception: {exc}")
        
        # Combine transcripts if the file was split
        # Sort by index to ensure correct order
        processed_transcripts.sort(key=lambda x: x[0])
        
        # Extract the transcript content in the correct order
        all_transcripts = [transcript for _, transcript in processed_transcripts]

        if len(audio_files_to_process) != len(all_transcripts):
            logger.error(f" --> ERROR: {len(audio_files_to_process)} audio files != {len(all_transcripts)} transcripts!")
            sys.exit(1)

        combined_content = "\n\n---\n\n".join(all_transcripts)
        if is_split:
            combined_transcript_path = output_dir / f"{file_to_process.stem}_transcript.md"
            
            final_result = ProcessingResult(
                output=combined_content,
                model_used=model_name,
                file_name=f"{file_to_process.name} (combined)",
                file_size_mb=file_to_process.stat().st_size / (1024 * 1024),
                processing_time_seconds=total_processing_time_sec,
                token_usage={}, # Not accurate for combined
                cost_estimation={'total_cost': total_cost},
                timestamp=datetime.now().isoformat(),
                finish_reason="STOP"
            )
            transcriber.save_output(final_result, combined_transcript_path, "Transcript", add_metadata=False)
            logger.info(f"All parts combined into: {combined_transcript_path}")

        # Now that full transcript exists ...
        print("Starting summary for", overall_summarize_output_path)
        sum_prompt_with_content = "\n\n".join([
            "# Instructions",
            summarize_prompt,
            "# Transcript",
            combined_content,
            "# Instructions repeated",
            summarize_prompt
            ])
        with open(overall_summarize_final_input_path, 'w', encoding='utf-8') as f:
                f.write(sum_prompt_with_content)
        summarize_result = transcriber.process_prompt(
            [sum_prompt_with_content],
            overall_summarize_final_input_path,
            summarize_config,
            overall_summarize_raw_output_path,
        )
        transcriber.save_output(summarize_result, overall_summarize_output_path, "Summary", add_metadata=False)
        total_cost += summarize_result.cost_estimation['total_cost']
        total_processing_time_sec += int(summarize_result.processing_time_seconds)
        print("Storing summary to", overall_summarize_output_path)

        # Clean up temporary chunk files
        # if is_split:
        #     logger.info("Cleaning up temporary audio chunks...")
        #     for chunk_file in audio_files_to_process:
        #         try:
        #             chunk_file.unlink()
        #             logger.info(f"Deleted chunk: {chunk_file.name}")
        #         except OSError as e:
        #             logger.error(f"Error deleting chunk {chunk_file.name}: {e}")
        #     try:
        #         temp_chunk_dir.rmdir()
        #         logger.info(f"Deleted temporary directory: {temp_chunk_dir}")
        #     except OSError as e:
        #         logger.error(f"Error deleting temporary directory {temp_chunk_dir}: {e}")

        print("\n--- Overall Summary ---")
        print(f"Files processed: {len(audio_files_to_process)}")
        print(f"Total processing time: {total_processing_time_sec:.1f} seconds")
        print(f"Total estimated cost: ${total_cost:.6f} USD")

    except Exception as e:
        logger.error(f"Error: {e}")
        import traceback
        logger.error(f"Traceback:\n{traceback.format_exc()}")
        sys.exit(1)

if __name__ == "__main__":
    main()
