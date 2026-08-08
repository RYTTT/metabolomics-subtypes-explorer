from PIL import Image
import glob
import os

images = glob.glob("workshop/result/*_volcano.png")
images = [img for img in images if "Cognitive_CogPos_vs_CogNeg" not in img] # just keep the 4 subtypes vs control
imgs = [Image.open(i) for i in images]

if len(imgs) == 4:
    widths, heights = zip(*(i.size for i in imgs))
    max_width = max(widths)
    max_height = max(heights)

    new_im = Image.new('RGB', (max_width * 2, max_height * 2))

    new_im.paste(imgs[0], (0, 0))
    new_im.paste(imgs[1], (max_width, 0))
    new_im.paste(imgs[2], (0, max_height))
    new_im.paste(imgs[3], (max_width, max_height))

    new_im.save("workshop/result/Combined_Volcano_Plots.png")
    print("Combined plot saved.")
