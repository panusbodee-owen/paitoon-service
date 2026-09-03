# ไพฑูรณ์ Service

เว็บไซต์ร้านขายอะไหล่รถยนต์ พัฒนาด้วย `React + TypeScript + Vite + Tailwind CSS`
Deploy ผ่าน GitHub Actions ไป GitHub Pages

## เริ่มใช้งานในเครื่อง

```
npm install
npm run dev
```

เปิดที่: http://localhost:5173/

## คำสั่งที่ใช้บ่อย

```
npm run dev      # รันเซิร์ฟเวอร์พัฒนา
npm run build    # build เว็บสำหรับ production
npm run preview  # ดูตัวอย่างหลัง build
```

## โครงสร้างสำคัญ

- `src/data/products.ts` ข้อมูลสินค้าและหมวดหมู่ทั้งหมด — แก้ตรงนี้เพื่อเพิ่ม/แก้สินค้า
- `src/pages/Home.tsx` หน้าแรก
- `src/pages/Products.tsx` หน้าสินค้าทั้งหมด (ค้นหา/กรองตามหมวด)
- `src/pages/ProductDetail.tsx` หน้ารายละเอียดสินค้า
- `src/pages/Cart.tsx` ตะกร้าสินค้า
- `src/pages/RandomRestaurant.tsx` หน้าสุ่มร้านเด็ดกรุงเทพฯ (path `/random-eats`) — เลือกหมวดอาหาร/เครื่องดื่ม/ของหวาน แล้วสุ่มร้านดัง พร้อมลิงก์สั่งผ่าน LINE MAN, Grab, ShopeeFood
- `src/data/restaurants.ts` ข้อมูลร้านและหมวดหมู่สำหรับหน้าสุ่มร้าน — แก้ตรงนี้เพื่อเพิ่ม/แก้ร้าน
- `src/context/CartContext.tsx` ระบบตะกร้า (บันทึกไว้ใน localStorage ของเบราว์เซอร์)
- `src/components/CarHotspots.tsx` ส่วนคลิกตำแหน่งบนรถเพื่อกรองสินค้า
- `src/assets/hrv-hero.png` รูปรถสำหรับ hero — เปลี่ยนได้โดยแทนที่ไฟล์นี้แล้วปรับตำแหน่ง % จุดคลิกใน `CarHotspots.tsx`
- `.github/workflows/deploy.yml` workflow สำหรับ deploy ไป GitHub Pages

## วิธีเอาขึ้น GitHub Pages

### 1. สร้าง GitHub repository

สร้าง repo ใหม่บน GitHub เช่น `paitoon-service`

### 2. Push โค้ดขึ้น GitHub

```
git init
git add .
git commit -m "Initial store website"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/paitoon-service.git
git push -u origin main
```

### 3. เปิด GitHub Pages

ใน GitHub repo: ไปที่ `Settings` > `Pages` > ที่ `Source` เลือก `GitHub Actions`

จากนั้นทุกครั้งที่ push ไปที่ branch `main` ระบบจะ build และ deploy เว็บให้อัตโนมัติ

## URL เว็บไซต์หลัง deploy

```
https://YOUR_USERNAME.github.io/paitoon-service/
```

**หมายเหตุ:** ถ้าตั้งชื่อ repo ไม่ใช่ `paitoon-service` ต้องแก้ `base` ใน `vite.config.ts` ให้ตรงกับชื่อ repo ด้วย

## หมายเหตุอื่นๆ

- โปรเจกต์นี้ใช้ `HashRouter` เพื่อให้ route ภายในทำงานบน GitHub Pages ได้โดยไม่พัง
- ยังไม่มีระบบชำระเงินออนไลน์ ตอนนี้ปุ่ม "ส่งคำสั่งซื้อ" เป็น placeholder — ถ้าต้องการให้ทีมงานติดต่อกลับผ่าน LINE/โทรศัพท์ สามารถเพิ่ม logic ส่งข้อมูลได้ภายหลัง
- สินค้าทั้งหมดตอนนี้เป็นข้อมูลตัวอย่าง แก้ไขได้ที่ `src/data/products.ts`
