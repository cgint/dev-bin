#!/usr/bin/env -S uv run --script
# 
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "google-genai",
#     "Pillow",
#     "pathlib",
# ]
# ///

import sys
import os
import re
import shutil
import subprocess
import time
from pathlib import Path
from collections import Counter
from io import BytesIO
from google import genai
from google.genai.types import GenerateContentConfig, Modality
from PIL import Image



def check_image_tools():
    """Check for available image processing tools"""
    image_processor = "none"
    webp_converter = "none"
    
    # Check for ImageMagick
    try:
        subprocess.run(["magick", "--version"], capture_output=True, check=True)
        print("Using ImageMagick for post-processing")
        image_processor = "imagemagick"
        webp_converter = "imagemagick"
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass
    
    # Check for sips (macOS)
    if image_processor == "none" and sys.platform == "darwin":
        try:
            subprocess.run(["sips", "--version"], capture_output=True, check=True)
            print("Using sips for post-processing (macOS)")
            image_processor = "sips"
        except (subprocess.CalledProcessError, FileNotFoundError):
            pass
    
    # Check for cwebp
    if webp_converter == "none":
        try:
            subprocess.run(["cwebp", "-version"], capture_output=True, check=True)
            print("Using cwebp for WebP conversion")
            webp_converter = "cwebp"
        except (subprocess.CalledProcessError, FileNotFoundError):
            pass
    
    if image_processor == "none":
        print("Warning: No image processing tools found. Post-processing will be skipped.")
        print("To install ImageMagick:")
        print("  - On macOS: brew install imagemagick")
        print("  - On Ubuntu/Debian: sudo apt-get install imagemagick")
    
    if webp_converter == "none":
        print("Warning: No WebP conversion tools found. WebP conversion will be skipped.")
        print("To install WebP tools:")
        print("  - On macOS: brew install webp")
        print("  - On Ubuntu/Debian: sudo apt-get install webp")
    
    return image_processor, webp_converter


def extract_article_info(article_file):
    """Extract article information from TypeScript file"""
    try:
        with open(article_file, 'r', encoding='utf-8') as f:
            content = f.read()
        print(f"Successfully read article file: {article_file}")
    except FileNotFoundError:
        print(f"Article file not found: {article_file}")
        sys.exit(1)
    
    # Extract title
    title_match = re.search(r"overviewTitle: '([^']+)'", content)
    if not title_match:
        print("Section 'overviewTitle' not found!")
        sys.exit(1)
    title = title_match.group(1)
    
    # Extract description
    desc_match = re.search(r"overviewDescription: '([^']+)'", content)
    if not desc_match:
        print("Section 'overviewDescription' not found!")
        sys.exit(1)
    description = desc_match.group(1)
    
    # Extract content between content: ` and `
    content_match = re.search(r'content:\s*`(.*?)`', content, re.DOTALL)
    if not content_match:
        print("Section 'content' not found!")
        sys.exit(1)
    article_content = content_match.group(1)
    
    return title, description, article_content


def extract_key_terms(content):
    """Extract key terms from article content"""
    # Find words that are not common stop words
    words = re.findall(r'\b[A-Za-z][A-Za-z-]+\b', content)
    
    # Common stop words to filter out
    stop_words = {
        'the', 'and', 'for', 'that', 'with', 'have', 'this', 'from', 'they', 
        'will', 'what', 'about', 'their', 'your', 'when', 'would', 'could', 
        'should', 'them', 'these', 'some', 'there', 'than', 'then', 'also', 
        'into', 'only', 'other', 'such', 'both', 'more', 'most', 'much', 
        'must', 'very', 'which'
    }
    
    # Filter out stop words and short words
    filtered_words = [word for word in words if word.lower() not in stop_words and len(word) > 3]
    
    # Count occurrences and get top 10
    word_counts = Counter(filtered_words)
    top_words = [word for word, count in word_counts.most_common(10)]
    
    return ', '.join(top_words)


def create_prompt(title, description, content, target_color="#586e58"):
    """Create the image generation prompt"""
    # Limit content to 10000 characters
    content_summary = re.sub(r'\s+', ' ', content)[:10000]
    
    key_terms = extract_key_terms(content)
    prompt = f"""Create a clean, elegant illustration for a blog article titled '{title}'.

Topic: {description}

Follow these guidelines:
- Create a MINIMALIST design with 3-6 thoughtful graphical elements
- The image MUST specifically illustrate this article's exact topic
- the image should have an artistic and strong 3D-style to it
- The image MUST NOT contain any text
- The image MUST NOT contain any text
- The image MUST NOT contain any text
- The image MUST NOT contain any text
- Pure white background with subtle green '{target_color}' coloring accents and supporting colors
- Use clear, iconic imagery that directly represents the article's specific subject
- IMPORTANT: The illustration, including all graphical elements, should extend up to the very edges of the image, with no artificial borders or extra whitespace at the borders. Avoid margins. All elements should be drawn up to the very border of the image.


REALLY IMPORTANT TO NOT USE TEXT:
- DON'T USE TEXT in the image
- DON'T USE TEXT in the image
- DON'T USE TEXT in the image
- DON'T USE TEXT in the image
- DON'T USE TEXT in the image

Key extracted terms from the article: {key_terms}

Article content summary:
========================

{content_summary}

========================

Based on ONLY this content, create 3-6 specific visual elements that:
- Are DIRECTLY relevant to the main topic and key terms of this article
- Use clean, elegant iconography with appropriate detail
- All visual elements must go all the way to the outer edges of the image; do not leave empty space at the borders.
- Use the color palette: white background with '{target_color}' coloring accents and supporting colors
- Create an immediately recognizable visual that captures the article's essence
- Ensure the design would be distinctive and different from other tech articles
- Can include contextual elements that enhance the main subject

REALLY IMPORTANT TO NOT USE TEXT:
- DON'T USE TEXT in the image
- DON'T USE TEXT in the image
- DON'T USE TEXT in the image
- DON'T USE TEXT in the image
- DON'T USE TEXT in the image

Your illustration should communicate the article's unique focus clearly with a clean, premium aesthetic that balances simplicity with meaningful detail. The entire image, including all visual elements, should be drawn up to the very border, with no frame, padding, or margin.


"""

    return prompt


def _is_rate_limit_error(exc: Exception) -> bool:
    """Check if exception is a 429 rate limit error."""
    msg = str(exc).upper()
    return "429" in msg or "RESOURCE_EXHAUSTED" in msg


def call_genai_api(prompt, number_of_images=1):
    """Call the Google GenAI API with retry on 429 rate limits."""
    project_id = "gen-lang-client-0910640178"
    location = "global"
    model = "gemini-2.5-flash-image"
    max_retries = 5
    delay_between_images = 8  # seconds, to smooth traffic and avoid RPM limits

    # Unset API keys to force Vertex AI usage
    os.environ.pop("GOOGLE_API_KEY", None)
    os.environ.pop("GEMINI_API_KEY", None)

    client = genai.Client(project=project_id, location=location, vertexai=True)

    print(f"Generating {number_of_images} image(s) using model: {model}...")

    responses = []
    for i in range(number_of_images):
        if i > 0:
            print(f"Waiting {delay_between_images}s before next image (rate limit smoothing)...")
            time.sleep(delay_between_images)

        print(f"Generating image {i+1}/{number_of_images}...")
        for attempt in range(max_retries):
            try:
                response = client.models.generate_content(
                    model=model,
                    contents=prompt,
                    config=GenerateContentConfig(
                        response_modalities=[Modality.TEXT, Modality.IMAGE]
                    ),
                )
                responses.append(response)
                break
            except Exception as e:
                if _is_rate_limit_error(e) and attempt < max_retries - 1:
                    wait = min(60, (2 ** attempt) * 2)  # 2, 4, 8, 16, 32 sec
                    print(f"Rate limited (429). Retry {attempt+1}/{max_retries} in {wait}s...")
                    time.sleep(wait)
                else:
                    print(f"Error calling GenAI API: {e}")
                    sys.exit(1)

    return responses


def process_genai_responses(responses, temp_dir):
    """Process the GenAI response objects and save them"""
    images_saved = 0
    
    print("Processing GenAI response objects...")
    
    for i, response in enumerate(responses, 1):
        temp_file = temp_dir / f"raw_{i}.png"
        
        try:
            # Extract image from GenAI response
            if (
                response.candidates
                and response.candidates[0].content
                and response.candidates[0].content.parts
            ):
                for part in response.candidates[0].content.parts:
                    if part.inline_data and part.inline_data.data:
                        image = Image.open(BytesIO(part.inline_data.data))
                        temp_file.parent.mkdir(parents=True, exist_ok=True)
                        image.save(str(temp_file))
                        print(f"Saved raw image to {temp_file}")
                        images_saved += 1
                        break
                else:
                    print(f"Warning: No image data found in response {i}")
            else:
                print(f"Warning: Invalid response structure for image {i}")
        except Exception as e:
            print(f"Error saving image {i}: {e}")
    
    return images_saved


def post_process_images(images_saved, temp_dir, static_dir, image_processor, webp_converter, target_color="#586e58"):
    """Post-process images with resizing, colorizing, and WebP conversion"""
    print("Post-processing images and converting directly to WebP...")
    
    if image_processor == "imagemagick":
        for i in range(1, images_saved + 1):
            raw_file = temp_dir / f"raw_{i}.png"
            webp_file = static_dir / f"logo_{i}.webp"
            
            print(f"Processing image {i} using ImageMagick and converting directly to WebP...")
            
            try:
                subprocess.run([
                    "magick", str(raw_file), "-resize", "512x512",
                    "-fill", target_color, "-colorize", "50%",
                    "-quality", "90", str(webp_file)
                ], check=True)
                print(f"Created WebP image: {webp_file}")
            except subprocess.CalledProcessError as e:
                print(f"Error processing image {i}: {e}")
        
        print("Post-processing complete.")
    
    elif image_processor == "sips":
        for i in range(1, images_saved + 1):
            raw_file = temp_dir / f"raw_{i}.png"
            resized_file = temp_dir / f"resized_{i}.png"
            webp_file = static_dir / f"logo_{i}.webp"
            
            print(f"Processing image {i} using sips and converting to WebP...")
            
            try:
                # Step 1: Resize using sips
                shutil.copy2(raw_file, resized_file)
                subprocess.run([
                    "sips", "-z", "512", "512", str(resized_file)
                ], check=True, capture_output=True)
                
                # Step 2: Convert to WebP
                if webp_converter == "imagemagick":
                    print("Converting to WebP using ImageMagick...")
                    subprocess.run([
                        "magick", str(resized_file), "-quality", "90", str(webp_file)
                    ], check=True)
                elif webp_converter == "cwebp":
                    print("Converting to WebP using cwebp...")
                    subprocess.run([
                        "cwebp", "-q", "90", str(resized_file), "-o", str(webp_file)
                    ], check=True)
                else:
                    print("Skipping WebP conversion due to missing tools")
                    png_file = static_dir / f"logo_{i}.png"
                    shutil.copy2(resized_file, png_file)
                    print(f"Copied resized PNG instead: {png_file}")
                
                print(f"Created WebP image: {webp_file}")
                print("Note: sips can't colorize images. For colorization, consider installing ImageMagick.")
            except subprocess.CalledProcessError as e:
                print(f"Error processing image {i}: {e}")
        
        print("Processing complete.")
    
    else:
        print("Skipping post-processing due to missing image processing tools.")
        # Copy raw files to main directory as PNGs
        for i in range(1, images_saved + 1):
            raw_file = temp_dir / f"raw_{i}.png"
            png_file = static_dir / f"logo_{i}.png"
            shutil.copy2(raw_file, png_file)
            print(f"Copied raw image to: {png_file}")
        
        print("To post-process manually in GIMP:")
        print("1. Open each image in GIMP")
        print("2. Resize to 512x512: Image -> Scale Image -> Set Width and Height to 512")
        print("3. Colorize: Colors -> Colorize -> Set color to '#586e58'")


def create_teaser_image(images_saved, temp_dir, static_dir, image_processor, webp_converter, target_color="#586e58"):
    """Create a final teaser image"""
    print("Creating final teaser image...")
    
    if images_saved > 0:
        teaser_file = static_dir / "teaser_dall-e.webp"
        
        if image_processor == "imagemagick":
            # Create high-quality teaser directly from the first raw image
            raw_file = temp_dir / "raw_1.png"
            try:
                subprocess.run([
                    "magick", str(raw_file), "-resize", "512x512",
                    "-fill", target_color, "-colorize", "50%",
                    "-quality", "95", str(teaser_file)
                ], check=True)
                print(f"Created teaser WebP: {teaser_file}")
            except subprocess.CalledProcessError as e:
                print(f"Error creating teaser: {e}")
        
        elif webp_converter != "none":
            resized_file = temp_dir / "resized_1.png"
            if resized_file.exists():
                try:
                    if webp_converter == "imagemagick":
                        subprocess.run([
                            "magick", str(resized_file), "-quality", "95", str(teaser_file)
                        ], check=True)
                        print(f"Created teaser WebP: {teaser_file}")
                    elif webp_converter == "cwebp":
                        subprocess.run([
                            "cwebp", "-q", "95", str(resized_file), "-o", str(teaser_file)
                        ], check=True)
                        print(f"Created teaser WebP: {teaser_file}")
                except subprocess.CalledProcessError as e:
                    print(f"Error creating teaser: {e}")
            else:
                print("Skipping teaser WebP creation due to missing resized image")
        else:
            print("Skipping teaser WebP creation due to missing tools")
    else:
        print("No images were generated, skipping teaser creation")


def handle_prompt_mode(prompt, target_color="#586e58"):
    """Handle direct prompt mode - generate image from prompt and save as output.png"""
    print("Direct prompt mode: Generating image from prompt")
    print(f"Using target color: {target_color}")
    print(f"Prompt: {prompt}")
    
    # Check for image processing tools
    image_processor, webp_converter = check_image_tools()
    
    # Call GenAI API with just 1 image
    responses = call_genai_api(prompt, 1)
    
    # Create temp directory for processing
    temp_dir = Path("temp_prompt_generation")
    temp_dir.mkdir(exist_ok=True)
    
    # Process GenAI responses and save them
    images_saved = process_genai_responses(responses, temp_dir)
    
    if images_saved > 0:
        # Process the image and save as output.png
        raw_file = temp_dir / "raw_1.png"
        output_file = Path("output.png")
        
        if image_processor == "imagemagick":
            try:
                subprocess.run([
                    "magick", str(raw_file), "-resize", "512x512",
                    "-fill", target_color, "-colorize", "50%",
                    str(output_file)
                ], check=True)
                print(f"Created output image: {output_file}")
            except subprocess.CalledProcessError as e:
                print(f"Error processing image: {e}")
                # Fallback: just copy the raw file
                shutil.copy2(raw_file, output_file)
                print(f"Copied raw image to: {output_file}")
        
        elif image_processor == "sips":
            try:
                # Copy and resize using sips
                shutil.copy2(raw_file, output_file)
                subprocess.run([
                    "sips", "-z", "512", "512", str(output_file)
                ], check=True, capture_output=True)
                print(f"Created output image: {output_file}")
                print("Note: sips can't colorize images. For colorization, consider installing ImageMagick.")
            except subprocess.CalledProcessError as e:
                print(f"Error processing image: {e}")
                # Fallback: just copy the raw file
                shutil.copy2(raw_file, output_file)
                print(f"Copied raw image to: {output_file}")
        
        else:
            # No image processing tools, just copy raw file
            shutil.copy2(raw_file, output_file)
            print(f"Copied raw image to: {output_file}")
            print("No image processing tools found. Image saved as-is.")
    
    # Clean up temp directory
    shutil.rmtree(temp_dir)
    print("Cleaned up temporary files")
    
    print("Direct prompt generation complete. Image saved as output.png")


def main():
    # Check for prompt mode
    if len(sys.argv) >= 3 and (sys.argv[1] == "--prompt" or sys.argv[1] == "-p"):
        if len(sys.argv) < 3:
            print("Usage: python create_logo_blog.py --prompt \"<your prompt>\" [target-color]")
            print("  target-color: Hex color without # symbol (default: 586e58)")
            sys.exit(1)
        
        prompt = sys.argv[2]
        target_color = f"#{sys.argv[3]}" if len(sys.argv) >= 4 else "#586e58"
        
        handle_prompt_mode(prompt, target_color)
        return
    
    # Original article mode
    if len(sys.argv) < 2 or len(sys.argv) > 4:
        print("Usage:")
        print("  Article mode: python create_logo_blog.py <article-id> [number-of-images] [target-color]")
        print("    article-id: The ID of the article to generate logos for")
        print("    number-of-images: Number of images to generate (default: 1, max: 4)")
        print("    target-color: Hex color without # symbol (default: 586e58)")
        print("")
        print("  Prompt mode: python create_logo_blog.py --prompt \"<your prompt>\" [target-color]")
        print("    prompt: Direct prompt for image generation")
        print("    target-color: Hex color without # symbol (default: 586e58)")
        sys.exit(1)
    
    article_id = sys.argv[1]
    number_of_images = int(sys.argv[2]) if len(sys.argv) >= 3 else 1
    target_color = f"#{sys.argv[3]}" if len(sys.argv) == 4 else "#586e58"
    
    if number_of_images < 1 or number_of_images > 4:
        print("Error: Number of images must be between 1 and 4")
        sys.exit(1)
    
    article_file = Path(f"src/lib/articles/{article_id}.ts")
    
    # Check for image processing tools
    image_processor, webp_converter = check_image_tools()
    print(f"Image processor: {image_processor}, WebP converter: {webp_converter}")
    
    # Extract article information
    title, description, content = extract_article_info(article_file)
    
    # Create prompt
    prompt = create_prompt(title, description, content, target_color)
    
    print(f"Generating {number_of_images} logo image(s) for article: {article_id}")
    print(f"Using target color: {target_color}")
    print(f"Prompt: {prompt}")
    
    # Call GenAI API
    responses = call_genai_api(prompt, number_of_images)
    
    # Create directories
    static_dir = Path(f"static/articles/{article_id}")
    static_dir.mkdir(parents=True, exist_ok=True)
    print(f"Created directory: {static_dir}")
    
    temp_dir = static_dir / "temp"
    temp_dir.mkdir(exist_ok=True)
    
    # Process GenAI responses and save them
    images_saved = process_genai_responses(responses, temp_dir)
    
    if images_saved > 0:
        # Post-process images
        post_process_images(images_saved, temp_dir, static_dir, image_processor, webp_converter, target_color)
        
        # Create teaser image
        create_teaser_image(images_saved, temp_dir, static_dir, image_processor, webp_converter, target_color)
    
    # Clean up temp directory
    shutil.rmtree(temp_dir)
    print("Cleaned up temporary files")
    
    print(f"Logo generation complete. {images_saved} images saved to {static_dir}")


if __name__ == "__main__":
    main()