export type FoodCategory = "food" | "drink" | "dessert";

export interface Restaurant {
  id: string;
  name: string;
  category: FoodCategory;
  area: string;
  description: string;
  tags: string[];
}

export const FOOD_CATEGORIES: { id: FoodCategory; label: string; emoji: string }[] = [
  { id: "food", label: "อาหาร", emoji: "🍜" },
  { id: "drink", label: "เครื่องดื่ม", emoji: "🧋" },
  { id: "dessert", label: "ของหวาน", emoji: "🍰" },
];

export const RESTAURANTS: Restaurant[] = [
  // อาหาร
  {
    id: "jayfai",
    name: "เจ๊ไฝ (Jay Fai)",
    category: "food",
    area: "เสาชิงช้า",
    description: "ไข่เจียวปูและผัดขี้เมาทะเลระดับมิชลินสตาร์ ต้นตำรับสตรีทฟู้ดชื่อดังของกรุงเทพฯ",
    tags: ["มิชลิน", "สตรีทฟู้ด", "ไข่เจียวปู"],
  },
  {
    id: "thipsamai",
    name: "ทิพย์สมัย ผัดไทยประตูผี",
    category: "food",
    area: "ประตูผี",
    description: "ผัดไทยห่อไข่สูตรดั้งเดิมที่เปิดมากว่า 80 ปี เมนูต้องสั่งเมื่อมาเยือนย่านเมืองเก่า",
    tags: ["ผัดไทย", "ร้านเก่าแก่"],
  },
  {
    id: "kruaapsorn",
    name: "ครัวอัปษร (Krua Apsorn)",
    category: "food",
    area: "บวรนิเวศ",
    description: "อาหารไทยรสมือแม่ เมนูเด็ดคือปูผัดผงกะหรี่และยำผักกระเฉดกุ้งสด",
    tags: ["อาหารไทย", "ปูผัดผงกะหรี่"],
  },
  {
    id: "somtamnua",
    name: "ส้มตำนัว สยามสแควร์",
    category: "food",
    area: "สยามสแควร์",
    description: "ส้มตำและอาหารอีสานรสจัดจ้าน คิวยาวตลอดวันแต่คุ้มค่าการรอ",
    tags: ["อีสาน", "ส้มตำ"],
  },
  {
    id: "wattanapanich",
    name: "วัฒนาพานิช เนื้อตุ๋น",
    category: "food",
    area: "เอกมัย",
    description: "ก๋วยเตี๋ยวเนื้อตุ๋นน้ำซุปข้นที่เคี่ยวต่อเนื่องมากว่า 50 ปี",
    tags: ["ก๋วยเตี๋ยวเนื้อ", "ร้านเก่าแก่"],
  },
  {
    id: "sukiteenoi",
    name: "สุกี้ตี๋น้อย",
    category: "food",
    area: "หลายสาขา",
    description: "สุกี้บุฟเฟต์ราคาคุ้มค่า เปิดดึก มีทั้งน้ำจิ้มสูตรพิเศษและวัตถุดิบให้เลือกจุใจ",
    tags: ["สุกี้", "บุฟเฟต์"],
  },
  {
    id: "boatnoodle",
    name: "ก๋วยเตี๋ยวเรือประตูน้ำ",
    category: "food",
    area: "ประตูน้ำ",
    description: "ก๋วยเตี๋ยวเรือรสจัดชามเล็กราคาย่อมเยา สั่งได้หลายชามไม่มีเบื่อ",
    tags: ["ก๋วยเตี๋ยวเรือ", "สตรีทฟู้ด"],
  },
  {
    id: "baankhunmae",
    name: "บ้านคุณแม่ สยามสแควร์",
    category: "food",
    area: "สยามสแควร์",
    description: "อาหารไทยจานเดียวและกับข้าวรสชาติเป็นกันเอง เหมาะสำหรับมื้อกลางวัน",
    tags: ["อาหารไทย", "จานเดียว"],
  },
  {
    id: "mkrestaurant",
    name: "MK สุกี้",
    category: "food",
    area: "หลายสาขา",
    description: "สุกี้แบรนด์คนไทยที่คุ้นเคย บริการเร็ว เมนูครบ เหมาะกับมื้อครอบครัว",
    tags: ["สุกี้", "แบรนด์คนไทย"],
  },
  {
    id: "nahm",
    name: "Nahm",
    category: "food",
    area: "สาทร",
    description: "อาหารไทยร่วมสมัยแนวไฟน์ไดนิ่ง ตีความสูตรโบราณให้ทันสมัย ติดมิชลิน",
    tags: ["ไฟน์ไดนิ่ง", "มิชลิน"],
  },
  // เครื่องดื่ม
  {
    id: "rocketcoffeebar",
    name: "Rocket Coffeebar",
    category: "drink",
    area: "ทองหล่อ",
    description: "ร้านกาแฟสเปเชียลตี้บรรยากาศดี เมล็ดกาแฟคุณภาพ เหมาะนั่งทำงานหรือนัดเพื่อน",
    tags: ["กาแฟ", "สเปเชียลตี้"],
  },
  {
    id: "casalapin",
    name: "Casa Lapin",
    category: "drink",
    area: "หลายสาขา",
    description: "คาเฟ่สไตล์มินิมอลชื่อดัง เมนูกาแฟและเลมอนซอร์เบ็ตเป็นซิกเนเจอร์",
    tags: ["คาเฟ่", "กาแฟ"],
  },
  {
    id: "factorycoffee",
    name: "Factory Coffee",
    category: "drink",
    area: "เอกมัย",
    description: "โรงคั่วกาแฟและร้านกาแฟที่คอกาแฟตัวจริงต้องแวะ รสชาติกลมกล่อมคัดสรรพิเศษ",
    tags: ["กาแฟ", "โรงคั่ว"],
  },
  {
    id: "ceresia",
    name: "Ceresia Coffee Roasters",
    category: "drink",
    area: "สุขุมวิท",
    description: "ร้านกาแฟคั่วเอง บรรยากาศอบอุ่น เหมาะกับการนั่งจิบกาแฟช้าๆ",
    tags: ["กาแฟ", "โรงคั่ว"],
  },
  {
    id: "rootscoffee",
    name: "Roots Coffee Roaster",
    category: "drink",
    area: "ทองหล่อ",
    description: "หนึ่งในร้านกาแฟที่บุกเบิกวงการกาแฟสเปเชียลตี้ในกรุงเทพฯ",
    tags: ["กาแฟ", "สเปเชียลตี้"],
  },
  {
    id: "chatramue",
    name: "ชาตรามือ (Cha Tra Mue)",
    category: "drink",
    area: "หลายสาขา",
    description: "ชาไทยแบรนด์ต้นตำรับ รสเข้มข้นหอมมัน เมนูคลาสสิกที่ทุกคนรู้จัก",
    tags: ["ชาไทย", "แบรนด์ไทย"],
  },
  {
    id: "ichinihontea",
    name: "Ichi Nihon Tea",
    category: "drink",
    area: "หลายสาขา",
    description: "ชาเขียวมัทฉะและชาญี่ปุ่นแท้ต้นตำรับ เมนูยอดฮิตคือลาเต้มัทฉะ",
    tags: ["ชาเขียว", "มัทฉะ"],
  },
  {
    id: "bluecup",
    name: "Bluecup Coffee",
    category: "drink",
    area: "หลายสาขา",
    description: "ร้านกาแฟสายเขียวรักษ์โลก เมนูเครื่องดื่มหลากหลายราคาจับต้องได้",
    tags: ["กาแฟ", "ราคาคุ้มค่า"],
  },
  {
    id: "kokotea",
    name: "KOI Thé",
    category: "drink",
    area: "หลายสาขา",
    description: "ชานมไข่มุกและชาผลไม้สไตล์ไต้หวัน เมนูฮิตคือชานมไข่มุกทองคำ",
    tags: ["ชานมไข่มุก", "ไต้หวัน"],
  },
  {
    id: "mistercoconut",
    name: "Mister Coconut",
    category: "drink",
    area: "หลายสาขา",
    description: "น้ำมะพร้าวสดและเครื่องดื่มจากมะพร้าวคลายร้อนสไตล์ไทย",
    tags: ["น้ำมะพร้าว", "เครื่องดื่มสดชื่น"],
  },
  // ของหวาน
  {
    id: "afteryou",
    name: "After You Dessert Café",
    category: "dessert",
    area: "หลายสาขา",
    description: "ต้นตำรับชิบูย่าโทสต์และฮันนี่โทสต์สุดฟิน เมนูขนมหวานยอดนิยมของคนกรุงเทพฯ",
    tags: ["ฮันนี่โทสต์", "คาเฟ่ขนมหวาน"],
  },
  {
    id: "montnomsod",
    name: "มนต์นมสด (Mont Nom Sod)",
    category: "dessert",
    area: "บางลำพู",
    description: "ขนมปังปิ้งนมสดต้นตำรับที่เปิดมานาน เมนูซิกเนเจอร์คือขนมปังปิ้งหน้าสังขยา",
    tags: ["ขนมปังปิ้ง", "ร้านเก่าแก่"],
  },
  {
    id: "korpanich",
    name: "ข้าวเหนียวมูนกรอบเนียน ก่อพานิช",
    category: "dessert",
    area: "บางรัก",
    description: "ข้าวเหนียวมะม่วงและข้าวเหนียวมูนต้นตำรับที่คนต่อคิวซื้อกลับบ้านทุกวัน",
    tags: ["ข้าวเหนียวมะม่วง", "ร้านเก่าแก่"],
  },
  {
    id: "iberry",
    name: "iberry Garden",
    category: "dessert",
    area: "ประเวศ",
    description: "คาเฟ่ไอศกรีมโฮมเมดท่ามกลางสวนสีเขียว บรรยากาศร่มรื่นเหมาะพักผ่อน",
    tags: ["ไอศกรีม", "คาเฟ่สวน"],
  },
  {
    id: "kadkokoa",
    name: "Kad Kokoa",
    category: "dessert",
    area: "เอกมัย",
    description: "ร้านช็อกโกแลตและขนมหวานโฮมเมด เมนูเด็ดคือฮ็อตช็อกโกแลตข้นเข้ม",
    tags: ["ช็อกโกแลต", "คาเฟ่"],
  },
  {
    id: "cheevitcheeva",
    name: "Cheevit Cheeva",
    category: "dessert",
    area: "เอกมัย",
    description: "คาเฟ่ขนมหวานสไตล์มินิมอล เมนูซิกเนเจอร์คือเค้กและขนมโฮมเมดหน้าตาน่ารัก",
    tags: ["เค้ก", "คาเฟ่มินิมอล"],
  },
  {
    id: "erawantearoom",
    name: "Erawan Tea Room",
    category: "dessert",
    area: "ราชประสงค์",
    description: "ข้าวเหนียวมะม่วงและขนมไทยประยุกต์ในบรรยากาศหรูใจกลางเมือง",
    tags: ["ข้าวเหนียวมะม่วง", "ขนมไทย"],
  },
  {
    id: "bualoynana",
    name: "บัวลอยเยาวราช",
    category: "dessert",
    area: "เยาวราช",
    description: "บัวลอยไข่หวานร้อนๆ สูตรดั้งเดิมย่านไชน่าทาวน์ ของหวานเรียกความทรงจำวัยเด็ก",
    tags: ["บัวลอย", "ไชน่าทาวน์"],
  },
  {
    id: "douhua",
    name: "เต้าฮวยเจ้าเก่า เยาวราช",
    category: "dessert",
    area: "เยาวราช",
    description: "เต้าฮวยนุ่มละมุนราดน้ำขิงหอมกรุ่น ของหวานต้นตำรับย่านเยาวราช",
    tags: ["เต้าฮวย", "ไชน่าทาวน์"],
  },
];

/** ลิงก์ค้นหาร้านนี้บนแพลตฟอร์มสั่งอาหารเดลิเวอรี — เปิดผลค้นหาของร้านบนแพลตฟอร์มนั้นๆ */
export function getOrderLinks(name: string) {
  const q = encodeURIComponent(`${name} กรุงเทพ`);
  return [
    {
      id: "lineman",
      label: "LINE MAN",
      color: "#00B900",
      url: `https://www.google.com/search?q=${q}+site:food.lineman.line.me`,
    },
    {
      id: "grab",
      label: "Grab",
      color: "#00B14F",
      url: `https://www.google.com/search?q=${q}+site:food.grab.com`,
    },
    {
      id: "shopeefood",
      label: "ShopeeFood",
      color: "#EE4D2D",
      url: `https://www.google.com/search?q=${q}+site:shopeefood.co.th`,
    },
  ];
}
