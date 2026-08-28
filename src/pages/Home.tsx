import { Link } from "react-router-dom";
import { Truck, Percent } from "lucide-react";
import CarHotspots from "../components/CarHotspots";
import ProductCard from "../components/ProductCard";
import { CATEGORIES, PRODUCTS } from "../data/products";

export default function Home() {
  const featured = PRODUCTS.slice(0, 4);
  const deals = PRODUCTS.filter((p) => p.oldPrice).slice(0, 4);

  return (
    <>
      <section className="bg-[var(--color-black)] py-12">
        <div className="max-w-[1180px] mx-auto px-5 grid grid-cols-1 md:grid-cols-[1.2fr_0.9fr] gap-8">
          <div>
            <div className="text-[var(--color-muted)] text-xs mb-2.5 tracking-wide">
              ร้านอะไหล่รถยนต์ที่คุณวางใจ
            </div>
            <h1 className="disp text-4xl font-bold text-white leading-tight mb-3.5">
              ลดสูงสุด <span className="text-[var(--color-red)]">30%</span>
              <br />
              อะไหล่รถยนต์แท้
            </h1>
            <p className="text-[#A7ABB2] text-sm max-w-[380px] mb-6">
              เลือกซื้ออะไหล่ตรงรุ่น พร้อมส่ง ราคาชัดเจน ตรวจสอบสต็อกได้ทันที
            </p>
            <Link
              to="/products"
              className="inline-block bg-[var(--color-red)] text-white rounded-md px-6 py-3 text-sm font-semibold"
            >
              สั่งซื้อเลย
            </Link>

            <div className="bg-[#1C1D20] rounded-xl p-4.5 mt-9 grid grid-cols-2 sm:grid-cols-4 gap-2.5 items-end">
              {["ยี่ห้อรถ", "รุ่นรถ", "ปีรถ"].map((label) => (
                <div key={label}>
                  <div className="text-[#8A8E96] text-[11px] mb-1.5">{label}</div>
                  <select className="w-full bg-[#26272B] border-none rounded-md text-white text-sm px-2.5 py-2">
                    <option>เลือก{label}</option>
                  </select>
                </div>
              ))}
              <Link
                to="/products"
                className="bg-[var(--color-red)] rounded-md text-white px-3.5 py-2.5 text-center text-sm"
              >
                ค้นหา
              </Link>
            </div>
          </div>

          <div className="bg-white rounded-xl p-5">
            <div className="flex justify-between items-center mb-3.5">
              <span className="disp font-semibold text-[15px]">ดีลพิเศษวันนี้</span>
              <span className="bg-[var(--color-yellow)] text-[#5A4200] text-[11px] font-semibold rounded px-2 py-0.5">
                -25%
              </span>
            </div>
            <div className="h-[130px] bg-[var(--color-bg)] rounded-lg flex items-center justify-center text-[var(--color-muted)] text-xs mb-3">
              ภาพสินค้า
            </div>
            <div className="text-sm font-semibold mb-1">ชุดผ้าเบรกหน้า-หลัง</div>
            <div className="flex gap-2 items-baseline">
              <span className="text-[var(--color-red)] font-bold text-lg">฿1,490</span>
              <span className="text-[var(--color-muted)] text-[13px] line-through">฿1,990</span>
            </div>
          </div>
        </div>
      </section>

      <section className="max-w-[1180px] mx-auto px-5 pt-10 pb-2">
        <CarHotspots />
      </section>

      <section className="max-w-[1180px] mx-auto px-5 py-9">
        <h2 className="disp text-lg font-semibold mb-4">หมวดหมู่สินค้า</h2>
        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-3">
          {CATEGORIES.map((c) => (
            <Link
              key={c.id}
              to={`/products?category=${encodeURIComponent(c.label)}`}
              className="bg-white border border-[var(--color-border)] rounded-[10px] py-4.5 px-2.5 text-center hover:shadow-md transition"
            >
              <div className="w-10 h-10 rounded-full bg-[var(--color-bg)] mx-auto mb-2.5 flex items-center justify-center text-[var(--color-red)]">
                <Percent size={16} />
              </div>
              <div className="text-xs font-medium">{c.label}</div>
            </Link>
          ))}
        </div>
      </section>

      <section className="max-w-[1180px] mx-auto px-5 pb-9">
        <div className="flex justify-between items-baseline mb-4">
          <h2 className="disp text-lg font-semibold">สินค้าที่คุณกำลังมองหา</h2>
          <Link to="/products" className="text-[var(--color-red)] text-sm">
            ดูทั้งหมด →
          </Link>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {featured.map((p) => (
            <ProductCard key={p.sku} product={p} />
          ))}
        </div>
      </section>

      <section className="max-w-[1180px] mx-auto px-5 pb-12">
        <div className="bg-[var(--color-black)] rounded-2xl p-6">
          <div className="flex justify-between items-baseline mb-4.5">
            <h2 className="disp text-white text-lg font-semibold">ดีลประจำสัปดาห์</h2>
            <span className="text-[var(--color-red)] text-xs flex items-center gap-1">
              <Truck size={14} /> จัดส่งฟรีทุกออเดอร์ในดีลนี้
            </span>
          </div>
          <div className="grid grid-cols-2 md:grid-cols-4 gap-3.5">
            {deals.map((d) => (
              <Link key={d.sku} to={`/product/${d.sku}`} className="bg-[#1C1D20] rounded-xl p-3">
                <div className="h-20 bg-[#26272B] rounded-md flex items-center justify-center text-[#6A6E76] text-[11px] mb-2.5">
                  ภาพสินค้า
                </div>
                <div className="text-white text-xs mb-1.5">{d.name}</div>
                <div>
                  <span className="text-[var(--color-red)] font-bold text-sm">
                    ฿{d.price.toLocaleString()}
                  </span>
                  {d.oldPrice && (
                    <span className="text-[#6A6E76] text-[11px] line-through ml-1.5">
                      ฿{d.oldPrice.toLocaleString()}
                    </span>
                  )}
                </div>
              </Link>
            ))}
          </div>
        </div>
      </section>
    </>
  );
}
