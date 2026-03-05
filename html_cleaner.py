# /// script
# dependencies = ["beautifulsoup4", "lxml"]
# ///

import argparse
from bs4 import BeautifulSoup
import sys
import os
import re # Import the regex module

def clean_html(input_path, output_path, minify=False):
    """
    Cleans an HTML file by removing style-related tags, unwrapping divs,
    and stripping presentation attributes. Optionally minifies the output.

    Args:
        input_path (str): Path to the input HTML file.
        output_path (str): Path to save the cleaned HTML file.
        minify (bool): If True, remove whitespace between tags for single-line output.
    """
    if not os.path.exists(input_path):
        print(f"Error: Input file not found at '{input_path}'", file=sys.stderr)
        sys.exit(1)

    try:
        with open(input_path, 'r', encoding='utf-8') as infile:
            html_content = infile.read()
    except Exception as e:
        print(f"Error reading input file '{input_path}': {e}", file=sys.stderr)
        sys.exit(1)

    # Need original content to potentially extract title later
    original_soup = BeautifulSoup(html_content, 'lxml')

    # Use lxml for parsing - uv will ensure it's installed
    soup = BeautifulSoup(html_content, 'lxml')

    # 1. Remove <style>, <link rel="stylesheet">, and <meta> tags
    tags_to_remove = soup.find_all(['style', 'meta'])
    stylesheet_links = soup.find_all('link', rel='stylesheet')
    tags_to_remove.extend(stylesheet_links)

    for tag in tags_to_remove:
        tag.decompose()

    # 2. Unwrap <div> elements
    for tag in soup.find_all('div'):
        # Use tag.unwrap() which replaces the tag with its contents
        tag.unwrap()

    # 3. Remove presentation-related attributes from all remaining tags
    attributes_to_remove = ['style', 'class', 'id', 'width', 'height', 'cellspacing', 'cellpadding', 'border', 'dir', 'valign']

    for tag in soup.find_all(True): # Iterate over all tags
        attrs = dict(tag.attrs) # Create a copy to iterate over while modifying
        for attr in attrs:
            if attr in attributes_to_remove:
                del tag[attr]

    # Get the cleaned HTML string
    # Using prettify for a more readable output format
    # If <body> exists, use its content, otherwise use the whole soup
    body_content = soup.body if soup.body else soup
    # We want the content *inside* the body tag if it exists
    if body_content and hasattr(body_content, 'prettify'):
         # Get inner content if body exists, otherwise prettify the whole soup fragment
         cleaned_html_fragment = body_content.prettify(formatter="html5")
    else:
         cleaned_html_fragment = str(body_content) # Fallback to string representation

    # Minify if requested
    if minify:
        # Convert the potentially prettified fragment to a basic string first if necessary
        # (or just work from the string representation of body_content)
        temp_fragment = str(body_content) # Use the un-prettified version for minification base
        # Remove whitespace between tags > <
        minified_fragment = re.sub(r'>\s+<', '><', temp_fragment)
        # Remove leading/trailing whitespace and potentially remaining newlines if needed
        # Focusing on > < removal usually handles most inter-tag space.
        # Replace all kinds of newlines just in case.
        cleaned_html_fragment = minified_fragment.replace('\\n', '').replace('\\r', '').strip()
    # else: cleaned_html_fragment remains the prettified version from above

    try:
        # Ensure output directory exists if specified as part of the path
        output_dir = os.path.dirname(output_path)
        if output_dir and not os.path.exists(output_dir):
            os.makedirs(output_dir)

        with open(output_path, 'w', encoding='utf-8') as outfile:
            outfile.write("<!DOCTYPE html>\n")
            outfile.write("<html>\n<head>\n")
            # Try to preserve title from original soup
            title_tag = original_soup.find('title')
            if title_tag:
                outfile.write(f"    {str(title_tag)}\n") # Write title if found
            else:
                 outfile.write("    <title>Cleaned HTML</title>\n") # Default title

            outfile.write("</head>\n<body>\n")
            outfile.write(cleaned_html_fragment) # Write the (potentially minified) fragment
            outfile.write("\n</body>\n</html>\n") # Close tags

        print(f"Successfully cleaned HTML saved to '{output_path}'")
    except Exception as e:
        print(f"Error writing output file '{output_path}': {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description='Clean HTML file: remove styles, unwrap divs, strip presentation attributes.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Example usage:
  uv run html_cleaner.py input.html output_cleaned.html
  python html_cleaner.py input.html output_cleaned.html (if beautifulsoup4 and lxml are installed)
+ Minify output:
+   uv run html_cleaner.py --minify input.html output_minified.html
"""
    )
    parser.add_argument('input_file', help='Path to the input HTML file.')
    parser.add_argument('output_file', help='Path to save the cleaned HTML file.')
    parser.add_argument(
        '--minify',
        action='store_true', # Store true if flag is present
        help='Minify the output HTML into a single line, removing whitespace between tags.'
    )

    args = parser.parse_args()

    # Optional: Check for dependencies if not running via uv run
    # Use _UV_SCRIPT which is set by 'uv run'
    if os.environ.get("_UV_SCRIPT") is None:
         try:
             import bs4
             import lxml
         except ImportError:
             print("Warning: beautifulsoup4 or lxml not found in the current environment.", file=sys.stderr)
             print("         Consider running with 'uv run html_cleaner.py ...' or install dependencies manually:", file=sys.stderr)
             print("         pip install beautifulsoup4 lxml", file=sys.stderr)
             # Let the script fail later if imports are truly missing

    clean_html(args.input_file, args.output_file, args.minify) 