#!/usr/bin/env python3

import sys
import os
from PIL import Image
import argparse

def analyze_image(image_path):
    """
    Analyze an image and generate descriptive notes for game design inspiration.
    This is a basic analysis - can be enhanced with actual ML models.
    """
    try:
        with Image.open(image_path) as img:
            width, height = img.size
            mode = img.mode
            format_type = img.format
            
            # Basic image properties
            aspect_ratio = width / height
            is_landscape = aspect_ratio > 1.2
            is_portrait = aspect_ratio < 0.8
            is_square = 0.8 <= aspect_ratio <= 1.2
            
            # Generate analysis based on basic properties
            analysis = []
            analysis.append(f"Image Analysis for Game Design Inspiration")
            analysis.append(f"=" * 50)
            analysis.append(f"Filename: {os.path.basename(image_path)}")
            analysis.append(f"Dimensions: {width}x{height} pixels")
            analysis.append(f"Format: {format_type}")
            analysis.append(f"Color Mode: {mode}")
            analysis.append("")
            
            # Orientation analysis
            if is_landscape:
                analysis.append("ORIENTATION: Landscape format")
                analysis.append("- Good for: Wide environments, panoramic views, UI layouts")
                analysis.append("- Game design use: Environment concepts, level backgrounds")
            elif is_portrait:
                analysis.append("ORIENTATION: Portrait format")
                analysis.append("- Good for: Character designs, vertical UI elements, mobile layouts")
                analysis.append("- Game design use: Character portraits, mobile UI mockups")
            else:
                analysis.append("ORIENTATION: Square/balanced format")
                analysis.append("- Good for: Icons, avatars, symmetric designs")
                analysis.append("- Game design use: Item icons, ability symbols, profile pictures")
            
            analysis.append("")
            
            # Resolution-based recommendations
            if width >= 1920 and height >= 1080:
                analysis.append("RESOLUTION: High resolution")
                analysis.append("- Suitable for: Detailed environment concepts, high-quality assets")
                analysis.append("- Can be used for: Background art, detailed UI elements")
            elif width >= 512 and height >= 512:
                analysis.append("RESOLUTION: Medium resolution")
                analysis.append("- Suitable for: UI elements, character designs, item concepts")
                analysis.append("- Can be used for: In-game assets, interface components")
            else:
                analysis.append("RESOLUTION: Low resolution")
                analysis.append("- Suitable for: Icons, small UI elements, pixel art inspiration")
                analysis.append("- Can be used for: Button designs, status indicators")
            
            analysis.append("")
            analysis.append("GAME DESIGN CONSIDERATIONS:")
            analysis.append("- Analyze color palette for mood and atmosphere")
            analysis.append("- Consider composition for UI layout inspiration")
            analysis.append("- Look for design patterns applicable to game mechanics")
            analysis.append("- Note artistic style that could influence game aesthetics")
            analysis.append("")
            analysis.append("USER NOTES:")
            analysis.append("(Add your own observations and design ideas below)")
            analysis.append("")
            
            return "\n".join(analysis)
            
    except Exception as e:
        return f"Error analyzing image: {str(e)}"

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Analyze image for game design inspiration')
    parser.add_argument('image_path', help='Path to the image file')
    args = parser.parse_args()
    
    result = analyze_image(args.image_path)
    print(result)
