# 🏆 Tennis-Scoreboard-FPGA

Teniski semafor realizovan na FPGA (Nexys A7) korišćenjem VHDL-a, sa kompletnom logikom igre uključujući deuce, tie-break, undo i kontrolu meča.

---

## 📌 Opis

Ovaj projekat implementira digitalni sistem za praćenje teniskog meča na FPGA ploči. Sistem omogućava prikaz:

- poena (0, 15, 30, 40, Ad)
- gemova
- setova
- tie-break rezultata

na 7-segmentnom displeju.

---

## ⚙️ Tehnologije

- VHDL  
- AMD Vivado Design Suite  
- Nexys A7-100T FPGA  

---

## 🎮 Kontrole

| Dugme | Funkcija |
|------|--------|
| BTNL | Poen za igrača A |
| BTNR | Poen za igrača B |
| BTNU | Undo A |
| BTND | Undo B |
| BTNC | Reset |

---

## 🚀 Pokretanje

1. Otvoriti projekat u Vivado  
2. Postaviti `TennisTop` kao top modul  
3. Pokrenuti:
   - Synthesis  
   - Implementation  
   - Generate Bitstream  
4. Programirati FPGA ploču  

---

## 📖 Dokumentacija

👉 Detaljno objašnjenje projekta dostupno je u Wiki sekciji ovog repozitorijuma.

---

## 📌 Napomena

Projekat implementira realna pravila tenisa uključujući deuce, advantage, tie-break i završetak meča nakon 3 seta.
