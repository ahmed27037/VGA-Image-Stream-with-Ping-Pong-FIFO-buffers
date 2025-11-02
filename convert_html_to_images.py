#!/usr/bin/env python3
"""
Convert HTML diagram files to JPG images for README display.
"""

import os
import sys
from pathlib import Path

try:
    from playwright.sync_api import sync_playwright
    PLAYWRIGHT_AVAILABLE = True
except ImportError:
    PLAYWRIGHT_AVAILABLE = False
    try:
        from html2image import Html2Image
        HTML2IMAGE_AVAILABLE = True
    except ImportError:
        HTML2IMAGE_AVAILABLE = False

def convert_with_playwright(html_file, output_file):
    """Convert HTML to JPG using Playwright."""
    with sync_playwright() as p:
        browser = p.chromium.launch(headless=True)
        page = browser.new_page()
        page.goto(f"file://{os.path.abspath(html_file)}")
        
        # Wait for page to fully load
        page.wait_for_load_state("networkidle")
        
        # Take screenshot
        page.screenshot(path=output_file, full_page=True, type='jpeg', quality=90)
        browser.close()

def convert_with_html2image(html_file, output_file):
    """Convert HTML to JPG using html2image."""
    hti = Html2Image(size=(1920, 1080))
    
    # Use absolute path for html_file
    html_path = os.path.abspath(html_file)
    output_path = os.path.abspath(output_file)
    
    # Take screenshot using file path
    hti.screenshot(
        html_file=html_path,
        save_as=os.path.basename(output_path),
        size=(1920, 1080)
    )
    
    # Move file if needed (html2image saves to current dir by default)
    if os.path.basename(output_path) != output_path:
        import shutil
        if os.path.exists(os.path.basename(output_path)):
            shutil.move(os.path.basename(output_path), output_path)

def convert_html_to_jpg(html_file, output_file=None):
    """Convert an HTML file to JPG image."""
    html_path = Path(html_file)
    if not html_path.exists():
        print(f"Error: {html_file} not found")
        return False
    
    if output_file is None:
        output_file = html_path.with_suffix('.jpg')
    
    output_path = Path(output_file)
    
    print(f"Converting {html_path.name} to {output_path.name}...")
    
    try:
        if PLAYWRIGHT_AVAILABLE:
            convert_with_playwright(html_path, output_path)
            print(f"  [OK] Successfully created {output_path}")
            return True
        elif HTML2IMAGE_AVAILABLE:
            convert_with_html2image(html_path, output_path)
            print(f"  [OK] Successfully created {output_path}")
            return True
        else:
            print("  [ERROR] Neither playwright nor html2image is available")
            print("  Install one with: pip install playwright (then run: playwright install chromium)")
            print("  Or: pip install html2image")
            return False
    except Exception as e:
        print(f"  [ERROR] {e}")
        return False

if __name__ == "__main__":
    diagrams_dir = Path("diagrams")
    
    if not diagrams_dir.exists():
        print(f"Error: {diagrams_dir} directory not found")
        sys.exit(1)
    
    html_files = list(diagrams_dir.glob("*.html"))
    
    if not html_files:
        print(f"No HTML files found in {diagrams_dir}")
        sys.exit(1)
    
    print(f"Found {len(html_files)} HTML file(s) to convert\n")
    
    # Check if we have the required libraries
    if not PLAYWRIGHT_AVAILABLE and not HTML2IMAGE_AVAILABLE:
        print("Installing required packages...")
        print("Installing playwright...")
        os.system("pip install playwright")
        
        try:
            from playwright.sync_api import sync_playwright
            PLAYWRIGHT_AVAILABLE = True
            print("  [OK] playwright installed")
            print("  Installing browser (this may take a minute)...")
            os.system("python -m playwright install chromium")
            print("  [OK] Browser installed\n")
        except ImportError:
            print("  [ERROR] playwright installation failed")
            print("  Trying html2image as fallback...")
            os.system("pip install html2image")
            try:
                from html2image import Html2Image
                HTML2IMAGE_AVAILABLE = True
                print("  [OK] html2image installed successfully\n")
            except ImportError:
                print("  [ERROR] html2image installation also failed")
                print("\nPlease manually install: pip install playwright")
                sys.exit(1)
    
    success_count = 0
    for html_file in html_files:
        if convert_html_to_jpg(html_file):
            success_count += 1
        print()
    
    print(f"Conversion complete: {success_count}/{len(html_files)} files converted")
    
    if success_count == len(html_files):
        print("\nAll files converted successfully! [OK]")
    else:
        print(f"\nWarning: {len(html_files) - success_count} file(s) failed to convert")

