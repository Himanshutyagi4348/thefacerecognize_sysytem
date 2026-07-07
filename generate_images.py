from PIL import Image, ImageDraw
import os

os.makedirs("images", exist_ok=True)

bg = Image.new("RGB", (1080, 1920), (30, 30, 60))
d = ImageDraw.Draw(bg)
d.rectangle([0, 0, 1080, 200], fill=(24, 24, 40))
d.text((60, 60), "Face Recognition", fill=(255, 255, 255))
bg.save("images/bg_generated.jpg", quality=95)

logo = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
d2 = ImageDraw.Draw(logo)
d2.ellipse([56, 56, 456, 456], fill=(46, 135, 255, 255))
d2.ellipse([156, 156, 356, 356], fill=(255, 255, 255, 255))
d2.text((176, 212), "FR", fill=(46, 135, 255, 255))
logo.save("images/logo_generated.png")

print("created images/bg_generated.jpg and images/logo_generated.png")
