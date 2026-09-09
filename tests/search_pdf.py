import pypdf
import re

pdf_path = "SUSENAS/JAWA BARAT/2023/Metadata dan Kuisoner/KOR 2023 VSEN23.pdf"
reader = pypdf.PdfReader(pdf_path)
print(f"Total pages in VSEN23: {len(reader.pages)}")

# Search for R101, R102, R105, R301, and FIES questions
keywords = ["BLOK I", "BLOK III", "BLOK XVII", "KERAWANAN PANGAN", "R101", "R105", "R301", "khawatir", "menolak menjawab"]

for idx, page in enumerate(reader.pages):
    text = page.extract_text()
    for kw in ["BLOK I.", "BLOK III.", "BLOK XVII", "KERAWANAN PANGAN", "tidak memiliki cukup makanan"]:
        if kw.lower() in text.lower():
            print(f"\n--- MATCH '{kw}' on PAGE {idx+1} ---")
            lines = text.split('\n')
            for l in lines[:15]:
                print("  ", l)
            for l in lines:
                if any(v in l for v in ["1701", "1702", "1703", "1704", "1705", "1706", "1707", "1708", "101.", "102.", "105.", "301."]):
                    print("   >> ", l)
