import pypdf

pdf_path = "SUSENAS/JAWA BARAT/2023/Metadata dan Kuisoner/KOR 2023 VSEN23.pdf"
reader = pypdf.PdfReader(pdf_path)
page21 = reader.pages[20].extract_text()

with open("tests/page21_wash.txt", "w", encoding="utf-8") as f:
    f.write(page21)

print("Page 21 written successfully!")
