import { Link } from "react-router-dom";
import { Search, ShoppingCart, Heart, GitCompare, User } from "lucide-react";
import { useCart } from "../context/CartContext";
import { CATEGORIES } from "../data/products";

export default function Header() {
  const { totalCount } = useCart();

  return (
    <header className="bg-white border-b border-[var(--color-border)] sticky top-0 z-30">
      <div className="bg-[var(--color-black)] text-[#C7C9CC] text-xs">
        <div className="max-w-[1180px] mx-auto px-5 py-1.5 flex justify-between items-center">
          <span>ยินดีต้อนรับสู่ร้านไพฑูรณ์ Service · ส่งฟรีเมื่อซื้อครบ 1,500 บาท</span>
          <div className="flex items-center gap-4">
            <Link to="/random-eats" className="text-[var(--color-yellow)] hover:underline">
              🎲 สุ่มร้านเด็ดกรุงเทพฯ
            </Link>
            <span>โทร 08X-XXX-XXXX</span>
          </div>
        </div>
      </div>
      <div className="max-w-[1180px] mx-auto px-5 py-4 flex items-center gap-5">
        <Link to="/" className="disp text-xl font-bold whitespace-nowrap">
          ไพฑูรณ์<span className="text-[var(--color-red)]"> Service</span>
        </Link>
        <div className="flex-1 flex items-center bg-[var(--color-bg)] border border-[var(--color-border)] rounded-lg overflow-hidden">
          <input
            placeholder="ค้นหาสินค้า, รหัสอะไหล่..."
            className="flex-1 border-none outline-none bg-transparent px-3.5 py-2.5 text-sm"
          />
          <button className="bg-[var(--color-red)] text-white px-4 py-2.5 flex items-center">
            <Search size={16} />
          </button>
        </div>
        <div className="flex items-center gap-4">
          <GitCompare size={19} />
          <Heart size={19} />
          <User size={19} />
          <Link to="/cart" className="relative flex items-center">
            <ShoppingCart size={19} />
            {totalCount > 0 && (
              <span className="absolute -top-2 -right-2.5 bg-[var(--color-red)] text-white text-[10px] font-semibold rounded-full px-1.5">
                {totalCount}
              </span>
            )}
          </Link>
        </div>
      </div>
      <div className="bg-[var(--color-red)]">
        <div className="max-w-[1180px] mx-auto px-5 flex gap-6 text-sm text-white overflow-x-auto">
          {CATEGORIES.map((c) => (
            <Link key={c.id} to={`/products?category=${encodeURIComponent(c.label)}`} className="py-2.5 whitespace-nowrap">
              {c.label}
            </Link>
          ))}
        </div>
      </div>
    </header>
  );
}
