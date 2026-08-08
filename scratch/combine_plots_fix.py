from PIL import Image
import glob

# Get only the 4 subtype volcano plots
images = [
    "workshop/result/Subtypes_Cognitive_vs_Control_volcano.png",
    "workshop/result/Subtypes_Depressive_vs_Control_volcano.png",
    "workshop/result/Subtypes_MildPTSD_vs_Control_volcano.png",
    "workshop/result/Subtypes_SeverePTSD_vs_Control_volcano.png"
]

imgs = [Image.open(i) for i in images]

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
