import pypdf
import re

pdf_path = "SUSENAS/JAWA BARAT/2023/Metadata dan Kuisoner/KOR 2023 VSEN23.pdf"
reader = pypdf.PdfReader(pdf_path)

# Let's search for R1810A, R1809A, R1809B, R1809C
# And Bansos: R2202, R2204A, R2207
# And Health: R1101_A (or 1101)

results = {}
for idx, page in enumerate(reader.pages):
    txt = page.extract_text()
    for v in ["1809", "1810", "2202", "2204", "2207", "1101"]:
        if v in txt:
            lines = txt.split("\n")
            for i, l in enumerate(lines):
                if v in l:
                    ctx = "\n".join(lines[max(0, i-1):min(len(lines), i+6)])
                    results.setdefault(v, []).append((idx+1, ctx))

with open("tests/vsen23_labels_extracted.txt", "w", encoding="utf-8") as f:
    for v, occurrences in results.items():
        f.write(f"=== VARIABLE {v} ===\n")
        for pg, ctx in occurrences[:2]:
            f.write(f"-- Page {pg} --\n{ctx}\n\n")

print("Done extracting labels!")
