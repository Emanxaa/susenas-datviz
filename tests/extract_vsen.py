import pypdf

pdf_path = "SUSENAS/JAWA BARAT/2023/Metadata dan Kuisoner/KOR 2023 VSEN23.pdf"
reader = pypdf.PdfReader(pdf_path)

with open("tests/vsen23_extracted_blocks.txt", "w", encoding="utf-8") as f:
    f.write("=== PAGE 1 (BLOK I & II) ===\n")
    f.write(reader.pages[0].extract_text() + "\n\n")
    
    f.write("=== PAGE 2 (BLOK III) ===\n")
    f.write(reader.pages[1].extract_text() + "\n\n")
    
    f.write("=== PAGE 20 (BLOK XVII - AKSES TERHADAP MAKANAN) ===\n")
    f.write(reader.pages[19].extract_text() + "\n\n")
    
    f.write("=== PAGE 4 (BLOK IV - KETERANGAN ANGGOTA RUMAH TANGGA / UMUR) ===\n")
    f.write(reader.pages[3].extract_text() + "\n\n")

print("Extracted successfully!")
