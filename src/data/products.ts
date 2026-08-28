export interface Product {
  sku: string;
  name: string;
  category: string;
  brand: string;
  compatibleModels: string[];
  price: number;
  oldPrice?: number;
  stock: "in" | "low" | "out";
  rating: number;
  reviews: number;
  description: string;
}

export const CATEGORIES = [
  { id: "engine", label: "อะไหล่เครื่องยนต์" },
  { id: "suspension", label: "ช่วงล่าง/โช้ค" },
  { id: "tire", label: "ยาง/ล้อ" },
  { id: "light", label: "ไฟหน้า/ไฟท้าย" },
  { id: "battery", label: "แบตเตอรี่" },
  { id: "oil", label: "น้ำมันเครื่อง" },
];

export const PRODUCTS: Product[] = [
  {
    sku: "SP-4410",
    name: "โช้คอัพหลัง สปอร์ต",
    category: "ช่วงล่าง/โช้ค",
    brand: "KYB",
    compatibleModels: ["HR-V", "City", "Civic"],
    price: 1590,
    oldPrice: 1990,
    stock: "in",
    rating: 4.5,
    reviews: 128,
    description: "โช้คอัพหลังสำหรับรถเก๋งและครอสโอเวอร์ รองรับน้ำหนักดี ขับนุ่มขึ้น",
  },
  {
    sku: "TR-0921",
    name: "ยางนอก 215/55R17",
    category: "ยาง/ล้อ",
    brand: "Bridgestone",
    compatibleModels: ["HR-V", "CR-V"],
    price: 2100,
    stock: "in",
    rating: 4.8,
    reviews: 302,
    description: "ยางเกรดพรีเมียม เกาะถนนดี เสียงเบา เหมาะกับการขับในเมืองและทางไกล",
  },
  {
    sku: "OL-1187",
    name: "น้ำมันเครื่องสังเคราะห์ 4L",
    category: "น้ำมันเครื่อง",
    brand: "Mobil 1",
    compatibleModels: ["ทั่วไป"],
    price: 890,
    oldPrice: 1050,
    stock: "in",
    rating: 4.6,
    reviews: 210,
    description: "น้ำมันเครื่องสังเคราะห์แท้ 100% เปลี่ยนถ่ายทุก 10,000 กม.",
  },
  {
    sku: "SP-3350",
    name: "โช้คอัพหน้า ปรับได้",
    category: "ช่วงล่าง/โช้ค",
    brand: "Tein",
    compatibleModels: ["Civic FC", "City"],
    price: 2450,
    stock: "low",
    rating: 4.3,
    reviews: 76,
    description: "โช้คอัพหน้าปรับความหนืดได้ 16 ระดับ เหมาะกับสายซิ่งและใช้งานทั่วไป",
  },
  {
    sku: "BR-2201",
    name: "ผ้าเบรกหน้า เซรามิก",
    category: "อะไหล่เครื่องยนต์",
    brand: "Akebono",
    compatibleModels: ["HR-V", "Civic", "City"],
    price: 890,
    oldPrice: 1190,
    stock: "in",
    rating: 4.7,
    reviews: 154,
    description: "ผ้าเบรกเซรามิกฝุ่นน้อย เสียงเงียบ ระยะเบรกสั้นกว่าผ้าเบรกทั่วไป",
  },
  {
    sku: "LT-2276",
    name: "โคมไฟหน้า LED คู่",
    category: "ไฟหน้า/ไฟท้าย",
    brand: "Philips",
    compatibleModels: ["Altis", "Camry"],
    price: 2450,
    oldPrice: 2900,
    stock: "in",
    rating: 4.4,
    reviews: 98,
    description: "โคมไฟหน้า LED ความสว่างสูง แสงขาวธรรมชาติ ติดตั้งง่าย",
  },
  {
    sku: "LT-3390",
    name: "ไฟท้าย LED ตรงรุ่น (ข้างขวา)",
    category: "ไฟหน้า/ไฟท้าย",
    brand: "TYC",
    compatibleModels: ["HR-V"],
    price: 1890,
    stock: "in",
    rating: 4.3,
    reviews: 37,
    description: "ไฟท้าย LED ตรงรุ่น HR-V ทรงเดิมติดรถ เปลี่ยนตรงไม่ต้องดัดแปลง",
  },
  {
    sku: "BT-5510",
    name: "แบตเตอรี่ 12V 45AH",
    category: "แบตเตอรี่",
    brand: "GS",
    compatibleModels: ["ทั่วไป"],
    price: 2350,
    stock: "in",
    rating: 4.6,
    reviews: 187,
    description: "แบตเตอรี่รถยนต์ ไม่ต้องเติมน้ำกลั่น รับประกัน 1 ปี",
  },
  {
    sku: "FL-1092",
    name: "กรองอากาศเครื่องยนต์",
    category: "อะไหล่เครื่องยนต์",
    brand: "Denso",
    compatibleModels: ["Vios", "Yaris"],
    price: 320,
    stock: "out",
    rating: 4.5,
    reviews: 64,
    description: "กรองอากาศแท้ตรงรุ่น ช่วยให้เครื่องยนต์เผาไหม้สมบูรณ์ ประหยัดน้ำมันขึ้น",
  },
];
