# Robbins Gold Grid EA (XAUUSD, MetaTrader 5)

EA เทรดทองคำแบบ Grid ที่ปรับตัวตามสภาวะตลาด RR **1:3 เสมอ** ทั้งรายไม้และรายตะกร้า มีระบบบริหารพอร์ตในตัว

> ⚠️ **คำเตือน:** การเทรดทองคำมีความเสี่ยงสูง EA นี้รับประกันว่า**ทำงานตามกติกาที่ออกแบบไว้** แต่ **ไม่รับประกันกำไร** ต้องทดสอบใน Strategy Tester และบัญชี Demo อย่างน้อย 1 เดือนก่อนใช้เงินจริงทุกครั้ง

## ไฟล์ในโฟลเดอร์นี้

| ไฟล์ | ใช้ทำอะไร |
|---|---|
| `RobbinsGoldGrid.mq5` | ตัว EA (ไฟล์เดียว พร้อม compile) |
| `presets/*.set` | ค่าตั้งต้น 3 แบบ: Conservative / Balanced / Robbins |
| `sim/` | ตัวจำลองตรรกะ (Python) + ชุดทดสอบ ใช้ตรวจสูตรคำนวณ |

## 1. ติดตั้งและ Compile (5 นาที)

1. เปิด MetaTrader 5 แล้วไปที่ **File → Open Data Folder**
2. คัดลอก `RobbinsGoldGrid.mq5` ไปไว้ใน `MQL5\Experts\`
3. คัดลอกไฟล์ `presets\*.set` ไปไว้ใน `MQL5\Presets\` (ไม่บังคับ)
4. เปิด **MetaEditor** (กด F4) แล้วดับเบิลคลิก `RobbinsGoldGrid.mq5` จากแถบ Navigator
5. กด **F7 (Compile)** ต้องขึ้น `0 errors` ถ้ามี error ให้ copy ข้อความในแท็บ Errors ส่งกลับมาให้ทีมแก้
6. กลับไปที่ MT5 แล้วกด Refresh ในหน้า Navigator → Expert Advisors

**ข้อกำหนดบัญชี:** ต้องเป็นบัญชีแบบ **Hedging** ถ้าเป็น Netting EA จะไม่ยอมเริ่มทำงานและแจ้งเหตุผลในแท็บ Experts

## 2. ใช้งาน

1. เปิดกราฟ **XAUUSD** (หรือชื่อทองของโบรกเกอร์ เช่น `XAUUSDm`, `GOLD`) ที่ timeframe ใดก็ได้ เพราะ EA ใช้ M15/H1 ตาม input เอง
2. ลาก EA ลงกราฟ แล้วติ๊ก **Allow Algo Trading**
3. เลือก `InpRiskPreset` หรือกด **Load** เพื่อโหลดไฟล์ `.set`
4. กดปุ่ม **Algo Trading** บน toolbar ให้เป็นสีเขียว

### วิธีทำงานโดยย่อ

```
ทุกแท่ง M15 ปิด → ตรวจสภาวะตลาด
  ├─ RANGE (ADX H1 < 20, BB แคบ, กรอบกว้าง 4–12 ATR)
  │     → Range Grid: Buy Limit ขอบล่าง 3 ชั้น + Sell Limit ขอบบน 3 ชั้น
  │       R = 25% ของความกว้างกรอบ, TP 3R ≈ อีกฝั่งของกรอบ, re-arm เมื่อชั้นว่าง
  ├─ BREAKOUT (ปิดทะลุกรอบ 24 แท่ง ≥ 0.2 ATR + ADX ขึ้น หรือ BB ขยาย)
  │     → Breakout Grid: Buy/Sell Stop 3 ชั้นตามทิศ ห่างกัน 0.5 ATR, R = 1.5 ATR
  ├─ VOLATILE (ATR > 2 เท่าค่าเฉลี่ย หรือข่าวแรง USD) → หยุดเปิดใหม่
  └─ NEUTRAL → หยุดเปิดใหม่ ดูแลไม้เดิม
```

### กติกา RR 1:3

- **ทุกไม้:** SL = 1R และ TP = 3R แนบไปตั้งแต่วาง pending ค่า `RR = 3.0` ถูกล็อกไว้ในโค้ด ไม่มี input ให้แก้
- **ทุกตะกร้า:** ตัดขาดทุนที่ −X% และปิดทำกำไรที่ +3X% ของ equity ตอนเริ่มตะกร้า
- **กฎเหล็ก:** ก่อนวางทุกออเดอร์ EA เช็กว่า "ถ้าทุกไม้โดน SL ตะกร้าจะเสียไม่เกิน X" ถ้าไม่ผ่านจะไม่วาง
- **Lot:** คำนวณให้แต่ละไม้เสียเท่ากัน ปัดลงเสมอ ถ้าต่ำกว่า lot ขั้นต่ำจะข้ามไม้นั้น ไม่ปัดขึ้น และไม่มี martingale
- **Risk throttle (v1.10):** เมื่อ DD ลึกขึ้น X ของตะกร้าใหม่จะถูกลดลงให้พอดีกับพื้นที่ที่เหลือก่อนชนลิมิต ถ้าพื้นที่เหลือน้อยกว่า 25% ของ X (`InpMinRiskFraction`) EA จะประกาศหยุดให้เห็นชัด คือ hard-stop หรือพักถึงวันใหม่ ไม่มีการหยุดเงียบๆ อีก

### Preset ความเสี่ยง

| Preset | X ต่อตะกร้า | เป้าตะกร้า | Daily loss | Hard-stop (DD จากจุดสูงสุด) |
|---|---|---|---|---|
| Conservative | 1.5% | 4.5% | 3% | 10% |
| Balanced | 3% | 9% | 6% | 15% |
| **Robbins** (default) | **6%** | **18%** | **12%** | **30%** |
| Custom | `InpCustomBasketPct` | 3 × X | `InpCustomDailyPct` | `InpCustomMaxDDPct` |

ความเสี่ยงต่อไม้คำนวณจาก X: Breakout ไม้ละ X ÷ 3 ส่วน Range ไม้ละ X ÷ 6 เพราะวางทั้งสองฝั่ง

## 3. Backtest ใน Strategy Tester

| ตั้งค่า | ค่า |
|---|---|
| Expert | RobbinsGoldGrid |
| Symbol | XAUUSD ของโบรกเกอร์ที่จะใช้จริง |
| Timeframe | M15 |
| Date | 2022-01-01 ถึงปัจจุบัน (ควรทดสอบแยกปีด้วย) |
| Modeling | **Every tick based on real ticks** |
| Deposit / Leverage | ตามบัญชีจริง |
| Delays | เปิด "Random delay" เพื่อจำลองสภาพจริง |

**Checklist หลัง backtest** (ติ๊กให้ครบก่อนไป Demo)

- [ ] Journal ไม่มีข้อความ `Pending rejected` ต่อเนื่อง (ถ้ามี แปลว่าตั้งค่า filling หรือ stop level ไม่เข้ากับโบรกเกอร์)
- [ ] สุ่มเปิดดู 10 ไม้ในแท็บ History: ระยะ TP ต้องเท่ากับ 3 เท่าของระยะ SL พอดี
- [ ] Max drawdown ในรายงานต้องไม่เกิน Hard-stop ของ preset ที่เลือก
- [ ] Log มีบรรทัด `Basket START` / `Basket END` และ `Regime ... -> ...` ครบทั้ง RANGE และ BREAKOUT
- [ ] ทดสอบซ้ำด้วย spread สูง (เช่น 50 points) เพื่อดูว่า filter spread ทำงาน
- [ ] ดูช่วงข่าวแรง เช่น NFP หรือ FOMC ว่าสถานะเป็น VOLATILE (ใน tester ใช้ ATR spike แทน filter ข่าว)

> หมายเหตุ: Economic Calendar ของ MT5 ใช้ไม่ได้ใน Strategy Tester ระหว่าง backtest filter ข่าวจึงถูกปิดอัตโนมัติ ผลบน live จึงอาจต่างจาก backtest ในช่วงที่มีข่าว

### 3.1 Backtest เพื่อดูความสามารถจริงของกลยุทธ์ (Research mode)

backtest ปกติจะมีด่านกันพอร์ตทำงานอยู่ ซึ่งอาจหยุด EA ก่อนจะได้เห็นผลระยะยาว ถ้าต้องการดูว่าตัวกลยุทธ์เองมี edge หรือไม่ ให้ตั้งค่าดังนี้:

| Input | ค่า | เหตุผล |
|---|---|---|
| `InpRiskPreset` | Custom | |
| `InpCustomBasketPct` | 6 | ความเสี่ยงต่อตะกร้าเท่ากับ Robbins |
| `InpCustomDailyPct` | 50 | แทบปิดด่านรายวัน |
| `InpCustomMaxDDPct` | 95 | แทบปิด hard-stop เพื่อให้เห็นกราฟครบทั้งช่วงเวลา |
| Initial deposit | **≥ 3,000 USD** (หรือใช้บัญชี cent) | ดูหมายเหตุด้านล่าง |

**ทำไมทุน 500$ ทดสอบไม่ได้ผล:**
- ทอง 0.01 lot = 1$ ต่อการขยับ 1$
- ระยะ R ของ EA อยู่ราว 3–9$ ไม้ที่เล็กที่สุดจึงเสียได้ถึง 3–9$
- ทุน 500$ ได้งบต่อไม้ฝั่ง Range แค่ 5$ หลายชั้นจึงถูกข้าม และขนาดไม้ที่ได้ก็หยาบมาก ผลทดสอบเลยเพี้ยนไปจากแบบที่ออกแบบไว้

**อ่านผลที่ท้ายแท็บ Journal** หลัง backtest จบ EA จะพิมพ์สรุป เช่น:

```
[RGG] RANGE    baskets 120 trades 410 net -85.20 | TP 60 (...) | SL 250 (...) | BE 90 (...) | EA-close 10 (...)
[RGG] BREAKOUT baskets 95 trades 260 net 140.10 | TP 50 (...) | SL 150 (...) | BE 55 (...) | EA-close 5 (...)
[RGG] Regime share of 64000 bars: RANGE 22.0% | BREAKOUT 9.5% | VOLATILE 4.1% | NEUTRAL 64.4%
[RGG] Skipped levels: lot below minimum 0 | margin 0 | risk budget 3 | throttled baskets 12
```

**กติกาที่ต้องรู้:** RR 1:3 จะคุ้มทุนเมื่อชนะ TP เกิน 25% ของไม้ที่ออก (ยังไม่รวม spread และ commission) ถ้าสัดส่วน TP ต่ำกว่านั้นแปลว่าจังหวะเข้ายังไม่มี edge การปรับ RR ไม่ช่วย ต้องปรับที่เงื่อนไขการเข้าไม้

**การทดลองที่แนะนำ** (เปลี่ยนทีละอย่าง):
1. `InpUseBreakEven = false` แล้วเทียบสัดส่วน TP ต่อ BE
2. ปิดเครื่องยนต์ทีละตัว:
   - ดูเฉพาะ Breakout: ตั้ง `InpBBWidthPctRange = 0` ซึ่งทำให้ไม่มีตลาดไหนเข้าเงื่อนไข RANGE
   - ดูเฉพาะ Range: ตั้ง `InpBreakoutBufferATR = 50` ซึ่งทำให้ไม่มี breakout ไหนผ่านเงื่อนไข
3. Optimize ด้วย criterion **"Custom max"**: EA คืนค่ากำไรสุทธิ ÷ max equity DD (Recovery Factor)

## 4. อ่าน Dashboard บนกราฟ

```
Robbins Gold Grid v1.10 | XAUUSD | magic 20261016
Preset Robbins: X 6.0%  daily 12.0%  max DD 30.0%  RR 1:3
Regime: RANGE (candidate RANGE 2/2)  ATR 4.12  spread 0.22
Basket: RANGE  R=5.00  X=600.00
  Net 120.50 (realized 80.00, floating 40.50)  stop -600.00 / target 1800.00
Positions 2  pendings 4
Day P/L 95.00 (0.95%)  peak 10250.00  DD 1.20%
Status: ACTIVE
```

`Status` ที่อาจเจอ:
- `ACTIVE`: ทำงานปกติ
- `waiting: spread / outside session / news / cooldown`: รอเงื่อนไขให้ผ่านก่อน
- `PAUSED (daily loss limit)`: เสียครบลิมิตรายวันแล้ว รอเปิดใหม่วันถัดไปตามเวลาเซิร์ฟเวอร์
- `HALTED (equity hard-stop)`: เสียถึงลิมิตใหญ่ หยุดถาวร ดูข้อ 5

## 5. Runbook: เมื่อเกิดเหตุ

| เหตุการณ์ | EA ทำอะไรเอง | คุณควรทำ |
|---|---|---|
| Basket stop (−X) | ปิดทุกไม้ ลบ pending พัก 4 แท่ง | ไม่ต้องทำอะไร เป็นการตัดขาดทุนปกติ |
| Daily loss limit | ปิดทุกไม้ หยุดถึงวันใหม่ | ทบทวนว่าวันนั้นมีข่าวหรือ gap หรือไม่ |
| **Equity hard-stop** | ปิดทุกไม้ หยุดถาวร (จำสถานะไว้แม้รีสตาร์ท) | ทบทวน log และพารามิเตอร์ ถ้าจะเริ่มใหม่ให้ตั้ง `InpResetHardStop = true` → OK → แล้วตั้งกลับเป็น `false` |
| VPS หรือ MT5 ดับ | เปิดกลับมาจะอ่านไม้และสถานะเดิมต่อได้ (ทุกไม้มี SL/TP อยู่ที่ฝั่งเซิร์ฟเวอร์) | เช็กว่า Algo Trading ยังเปิดอยู่ |
| ไม้ไม่มี SL | ใส่ SL/TP 1:3 ให้ทันที ถ้าใส่ไม่ได้จะปิดไม้นั้น | ดู log ว่าเกิดจากอะไร |
| `Pending rejected` ซ้ำๆ | ข้ามไม้นั้น | ส่ง log ให้ทีมเพื่อปรับ filling หรือ stop level |

เปิดการแจ้งเตือนเข้ามือถือได้: ตั้ง `InpPushAlerts = true` และใส่ MetaQuotes ID ที่ Tools → Options → Notifications

## 6. ความเสี่ยงที่ระบบป้องกันไม่ได้ (โปรดอ่าน)

1. **Gap หรือ slippage:** ถ้าราคากระโดดข้าม SL เช่น gap หลังเสาร์-อาทิตย์ ไม้จะถูกปิดที่ราคาตลาด อาจเสียเกิน 1R และเกิน X ได้ ตัวจำลองพบว่า gap 40$ ทำให้ตะกร้าเสียได้ถึงราว 6.7X ทางลดความเสี่ยง:
   - ตั้ง `InpCloseAllFriday = true` เพื่อปิดไม้ก่อนสุดสัปดาห์ (ข้อแลกคือไม้ที่ปิดตอนนั้นไม่ได้ออกที่ 1:3)
   - หรือใช้ preset ที่เบาลง
2. **ค่า commission และ swap** อยู่นอก RR ตามราคา แต่ถูกนับรวมในผลของตะกร้า
3. **เปิดได้ทีละตะกร้า:** ถ้ามี breakout เกิดขึ้นตอนที่ตะกร้า Range ยังมีไม้ค้าง EA จะไม่เข้าเทรด breakout นั้น
4. **Margin:** EA เช็ก margin ทีละไม้ตอนวาง แต่ pending หลายไม้ที่ถูกเปิดพร้อมกันอาจใช้ margin รวมเกินคาด ควรใช้ leverage ≥ 1:100

## 7. ทดสอบสูตรคำนวณด้วย Python (ไม่ต้องติดตั้งอะไรเพิ่ม)

```bash
cd gold-grid-ea/sim
python3 -m unittest -v
```

ชุดทดสอบตรวจว่า:
- RR = 3.00 ทุกไม้
- lot ไม่ปัดขึ้น
- กฎเหล็ก X ไม่ถูกละเมิด (สุ่มทดสอบ 300 ตะกร้า)
- ด่าน daily loss และ hard-stop ทำงานถูก
- การจัดสภาวะตลาดถูกต้อง

ไฟล์ `sim/rgg.py` ใช้สูตรเดียวกับ EA ถ้าแก้สูตรฝั่งใดฝั่งหนึ่งต้องแก้อีกฝั่งด้วย

## 8. พารามิเตอร์ที่ควรรู้

| Input | Default | ความหมาย |
|---|---|---|
| `InpRiskPreset` | Robbins | ระดับความเสี่ยง |
| `InpGridLevels` | 3 | จำนวนชั้นต่อฝั่ง (1–10) |
| `InpBreakoutSLATR` | 1.5 | R ของ Breakout = 1.5 × ATR(M15) |
| `InpRangeRiskFrac` | 0.25 | R ของ Range = 25% ของความกว้างกรอบ |
| `InpMinSL` / `InpMaxSL` | 2 / 20 | ขอบเขตของ R (หน่วยราคา = $) |
| `InpUseBreakEven` | true | เลื่อน SL ไปที่ทุน (+0.05R) เมื่อไม้ได้กำไร 1R |
| `InpMaxSpread` | 0.50 | spread สูงสุดที่ยอมเปิดไม้ใหม่ |
| `InpSessionStartHour` / `EndHour` | 7 / 21 | ช่วงเวลาเทรด (ตามเวลาเซิร์ฟเวอร์ของโบรกเกอร์) |
| `InpCloseAllFriday` | false | ปิดไม้ทั้งหมดตอนตัดรอบวันศุกร์ |
| `InpMagic` | 20261016 | ถ้ารันหลายกราฟหรือหลายบัญชีพร้อมกัน ให้ใช้เลขต่างกัน |

## 9. ประวัติเวอร์ชัน

| เวอร์ชัน | การเปลี่ยนแปลง |
|---|---|
| 1.10 | **แก้ bug หยุดเทรดเงียบ:** v1.00 ไม่เปิดตะกร้าใหม่อีกเลยเมื่อ "DD + X > ลิมิต" (backtest ม.ค. 2024 หยุดตั้งแต่วันที่ 10) เปลี่ยนเป็น risk throttle + halt ที่ประกาศชัด, เพิ่ม `InpMinRiskFraction`, เพิ่มสรุปสถิติท้าย backtest และ `OnTester` (Recovery Factor) |
| 1.00 | เวอร์ชันแรก |

ออกแบบโดยทีม 10x ดูเหตุผลการออกแบบได้ที่ `.10x/specs/` และ `.10x/adrs/`
