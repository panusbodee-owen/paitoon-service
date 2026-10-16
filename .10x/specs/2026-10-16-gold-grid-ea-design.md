# Spec: Robbins Gold Grid EA (XAUUSD, MT5)

**วันที่:** 2026-10-16
**Feature slug:** `gold-grid-ea`
**สถานะ:** อนุมัติโดยผู้ใช้ (brainstorming 3 ส่วน + อนุมัติรวม)

## 1. เป้าหมาย

Expert Advisor สำหรับ MetaTrader 5 เทรดทองคำ (XAUUSD) ด้วยวิธี Grid ที่:

1. **RR 1:3 เสมอ** ทั้งระดับไม้ (ทุกไม้ SL = 1R, TP = 3R) และระดับตะกร้า (basket stop −X%, basket target +3X%)
2. **ปรับตัวตามสภาวะตลาด** — แยก Sideway / Breakout / ผันผวนผิดปกติ แล้วเลือกเครื่องยนต์ Grid ให้เหมาะ
3. **บริหารพอร์ต** — risk budget ต่อตะกร้า, daily loss limit, equity hard-stop จากจุดสูงสุด, filter ก่อนเปิดไม้
4. **สไตล์ Robbins World Cup** — ดุดันได้ผ่าน preset (X = 6% ต่อตะกร้าเป็นค่าเริ่มต้น) แต่มีเบรกพอร์ตเสมอ

## 2. ข้อกำหนดที่ตกลงแล้ว

| หัวข้อ | การตัดสินใจ |
|---|---|
| ต้นแบบ | สไตล์ Robbins World Cup (ไม่มี EA ต้นฉบับ — ออกแบบใหม่) |
| แพลตฟอร์ม | MT5, บัญชี **Hedging** เท่านั้น (Netting → EA ไม่ยอมทำงาน) |
| RR | แบบผสม: ไม้ย่อย 1:3 + ตะกร้า 1:3 |
| Lot | Fixed Risk % เท่ากันทุกชั้น — **ไม่มี martingale** |
| แนวทาง | A. Regime-Switching Grid |
| การส่งมอบ | ไฟล์ `.mq5` **ไฟล์เดียว** พร้อม compile (ผู้ใช้ขอ) |

## 3. ตัวตรวจสภาวะตลาด (Regime Detector)

คำนวณเมื่อแท่ง Signal TF (default M15) ปิด ใช้แท่งที่ปิดแล้ว (shift 1) เท่านั้น

| Regime | เงื่อนไข (default) | การยืนยัน |
|---|---|---|
| VOLATILE | ATR(14) > 2.0 × ค่าเฉลี่ย ATR 96 แท่ง **หรือ** อยู่ในหน้าต่างข่าวแรง USD (live เท่านั้น) | ทันที |
| BREAKOUT_UP / DOWN | Close[1] ทะลุ Donchian 24 แท่ง (ไม่รวมแท่ง 1) ≥ 0.2×ATR **และ** (ADX H1 ≥ 20 และกำลังขึ้น **หรือ** BB width กำลังขยาย) | ทันที; ค้างสถานะ (sticky) ต่อได้ถ้า close ยังอยู่นอกระดับที่ทะลุ และยังไม่เกิน 8 แท่ง |
| RANGE | ADX H1 < 20 **และ** BB width percentile ≤ 40 (lookback 100) **และ** กว้างของกรอบ 4–12 ATR **และ** close อยู่ในกรอบ | ต้องติดกัน 2 แท่ง |
| NEUTRAL | อื่นๆ | ต้องติดกัน 2 แท่ง |

## 4. เครื่องยนต์ Grid

กติการ่วม: `RR = 3.0` เป็นค่าคงที่ (ไม่ใช่ input). BUY: SL = E − R, TP = E + 3R. SELL กลับด้าน. SL/TP แนบตั้งแต่วาง pending. หลัง normalize ราคาตาม tick size ต้องได้ RR = 3.0 ± 0.01 ไม่งั้นข้ามไม้.

### 4.1 Breakout Grid
- เริ่มเมื่อ regime **เปลี่ยนเข้า** BREAKOUT และไม่มีตะกร้าค้าง
- R = clamp(1.5 × ATR, MinSL, MaxSL) และ ≥ stop level ของโบรกเกอร์
- ชั้น i (0..L−1): Buy Stop ที่ Ask + (0.1 + 0.5·i)·ATR (Sell Stop สะท้อนจาก Bid)
- risk ต่อไม้ = X / L
- pending หมดอายุหลัง 8 แท่ง Signal TF (ลบเอง ไม่พึ่ง expiration ของโบรกเกอร์)
- ไม่ re-arm

### 4.2 Range Grid
- เริ่มเมื่อ regime = RANGE และไม่มีตะกร้าค้าง; จำกรอบ Low/High (Donchian แท่ง 1..24), W = High − Low
- R = clamp(max(0.25·W, 1.0·ATR), MinSL, MaxSL)
- Buy Limit ชั้น i ที่ Low + (0.20 − 0.10·i)·W ; Sell Limit ที่ High − (0.20 − 0.10·i)·W
- risk ต่อไม้ = X / (2L)
- **Re-arm**: ระหว่าง regime ยังเป็น RANGE ชั้นที่ว่าง (ไม้ปิดแล้ว ไม่มี pending) จะถูกวางใหม่ ถ้าราคาอยู่ฝั่งที่ถูกต้องสำหรับ limit และผ่าน risk budget
- ชั้นที่ราคาอยู่ผิดฝั่ง (limit วางไม่ได้) ข้ามไว้ก่อน

### 4.3 Lot
- lot = floor((risk money) / |OrderCalcProfit(1 lot, E→SL)| / volume_step) × volume_step
- ต่ำกว่า volume_min → **ข้ามไม้** (ไม่ปัดขึ้น); เกิน volume_max → ตัดที่ max
- margin ที่ต้องใช้ต้อง ≤ 90% ของ free margin ไม่งั้นข้าม
- risk money อ้างอิง **equity ตอนเริ่มตะกร้า** (คงที่ตลอดตะกร้า)

## 5. ตะกร้าและการบริหารพอร์ต

**ตะกร้า** = 1 รอบของโหมดหนึ่ง เริ่มเมื่อวางออเดอร์แรก จบเมื่อไม่มีไม้และ pending เหลือ หรือถูกปิดด้วย basket stop/target

- `net = realized (deals ของ EA ตั้งแต่เริ่มตะกร้า: profit+swap+commission+fee) + floating (profit+swap ของไม้ที่เปิด)`
- **Basket stop:** net ≤ −X → ปิดทุกไม้ ลบ pending, cooldown 4 แท่ง
- **Basket target:** net ≥ +3X → ปิดทุกไม้ ลบ pending, cooldown 4 แท่ง
- **Invariant (กฎเหล็ก):** ก่อนวางทุกออเดอร์ `realized + Σ P/L@SL(ไม้ที่เปิด) + Σ P/L@SL(pending) + P/L@SL(ไม้ใหม่) ≥ −X`
- ตะกร้าเดียวต่อครั้ง; เปลี่ยน regime → ลบ pending ของโหมดเก่า (ไม้ที่เปิดถือต่อด้วย SL/TP ของตัวเอง)

**ด่านกันพอร์ต (ตรวจทุก tick ตามลำดับ)**
1. **Equity hard-stop:** equity ≤ peak × (1 − MaxDD%) → ปิดทั้งหมด, halt ถาวร (persist) จนกว่าผู้ใช้ตั้ง `InpResetHardStop = true`
2. **Daily loss:** equity ≤ dayStart × (1 − DailyLoss%) → ปิดทั้งหมด, หยุดถึงวันใหม่ (เวลาเซิร์ฟเวอร์)
3. **Risk throttle (v1.10, ADR-003):** X ของตะกร้าใหม่ = min(X, ที่ว่างรายวัน, ที่ว่าง DD); ถ้าที่ว่างใดน้อยกว่า 0.25·X → halt แบบประกาศชัด (DD → hard-stop, รายวัน → พักถึงวันใหม่). ~~v1.00: gate ต้องมีที่ว่างเต็ม X~~ — ทำให้หยุดเทรดถาวรแบบเงียบ
4. **Filter:** spread ≤ 0.50, ชั่วโมงเทรด 07–21 (server), เลี่ยง rollover 23:00–01:00, ศุกร์ ≥ 20:00 ไม่เปิดใหม่; นอกช่วงเวลา/ศุกร์ → ลบ pending
4b. **Daily target (v1.20, ADR-004):** equity ≥ dayStart × 1.05 → ปิดทั้งหมด หยุดถึงวันใหม่; X = min(X preset, (เป้า − กำไรวันนี้≥0) ÷ 3) — วันขาดทุนไม่เพิ่ม X
5. **Break-even:** ราคาไปได้ ≥ 1R → SL ไปที่ entry ± 0.05R (TP คงที่ 3R)
6. **ไม้ไม่มี SL:** ใส่ SL/TP 1:3 ทันที; ถ้าราคาเลย SL ที่ควรเป็นไปแล้ว → ปิดไม้

**Preset**

| Preset | X | 3X | DailyLoss | MaxDD |
|---|---|---|---|---|
| Conservative | 1.5% | 4.5% | 3% | 10% |
| Balanced | 3% | 9% | 6% | 15% |
| Robbins (default) | 6% | 18% | 12% | 30% |
| Custom | input | 3×input | input | input |

## 6. สถานะที่ต้องจำ (Persistence)
GlobalVariables ของเทอร์มินัล prefix `RGG.<symbol>.<magic>.` — peak equity, day stamp, day-start equity, daily halt, hard halt, cooldown, ข้อมูลตะกร้า (active, type, dir, start time, start equity, X money, R, range low/high). ไม้และ pending อ่านจากเทอร์มินัลจริงเสมอ (stateless) ระบุด้วย Magic + comment `RGG|<R|B>|<B|S>|<level>`

## 7. Error handling
- Netting / symbol ไม่ใช่ทอง / input ผิด → `INIT_FAILED` / `INIT_PARAMETERS_INCORRECT` พร้อมข้อความ
- Filling mode: market ใช้ตาม symbol (FOK→IOC→RETURN), pending เริ่มที่ RETURN แล้ว fallback
- Requote/price changed/timeout → retry ≤ 3 ครั้ง
- Pending time type: GTC ถ้าโบรกเกอร์รองรับ ไม่งั้น DAY
- ทุกการตัดสินใจ log ด้วย prefix `[RGG]`

## 8. การทดสอบ
- Python (stdlib `unittest`, ไม่มี dependency) mirror สูตรเดียวกับ MQL5: levels, RR exactness, lot sizing, risk budget invariant, gates, regime classifier, basket simulation แบบสุ่ม
- ผู้ใช้: compile ใน MetaEditor (เป้า 0 error), Strategy Tester "Every tick based on real ticks" 2022–2025, demo ≥ 1 เดือน
- ส่งมอบ `.set` 3 preset + checklist

## 9. นอกขอบเขต
- MT4, บัญชี Netting, หลาย symbol พร้อมกันในตัวเดียว, martingale, การรับประกันกำไร
