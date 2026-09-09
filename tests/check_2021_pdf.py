import pypdf

pdf_2021 = "SUSENAS/JAWA BARAT/2021/Metadata dan Kuisoner/KOR 4.14 VSEN21.K Black.pdf"
reader = pypdf.PdfReader(pdf_2021)
print(f"Total pages in VSEN21: {len(reader.pages)}")

for idx, p in enumerate(reader.pages):
    txt = p.extract_text()
    if "AKSES TERHADAP MAKANAN" in txt.upper() or "KERAWANAN PANGAN" in txt.upper() or "1701" in txt:
        print(f"Match in 2021 on page {idx+1}")
        for l in txt.split('\n')[:10]:
            print("  ", l)
