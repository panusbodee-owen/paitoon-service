import { Link } from "react-router-dom";
import { Minus, Plus, Trash2 } from "lucide-react";
import { useCart } from "../context/CartContext";

export default function Cart() {
  const { items, updateQty, removeFromCart, totalPrice } = useCart();

  if (items.length === 0) {
    return (
      <div className="max-w-[1180px] mx-auto px-5 py-20 text-center">
        <h1 className="disp text-xl font-semibold mb-3">ตะกร้าของคุณยังว่างอยู่</h1>
        <p className="text-[var(--color-muted)] mb-6">เลือกซื้ออะไหล่ที่ต้องการแล้วกดใส่ตะกร้าได้เลย</p>
        <Link
          to="/products"
          className="inline-block bg-[var(--color-red)] text-white rounded-lg px-6 py-3 text-sm font-semibold"
        >
          เลือกซื้อสินค้า
        </Link>
      </div>
    );
  }

  return (
    <div className="max-w-[1180px] mx-auto px-5 py-9">
      <h1 className="disp text-2xl font-semibold mb-6">ตะกร้าสินค้า</h1>
      <div className="grid grid-cols-1 md:grid-cols-[1fr_320px] gap-8">
        <div className="space-y-3">
          {items.map(({ product, qty }) => (
            <div
              key={product.sku}
              className="bg-white border border-[var(--color-border)] rounded-xl p-4 flex items-center gap-4"
            >
              <div className="w-20 h-20 bg-[var(--color-bg)] rounded-lg flex items-center justify-center text-[var(--color-muted)] text-[11px] shrink-0">
                ภาพสินค้า
              </div>
              <div className="flex-1 min-w-0">
                <div className="text-sm font-medium truncate">{product.name}</div>
                <div className="mono text-xs text-[var(--color-muted)]">{product.sku}</div>
                <div className="text-[var(--color-red)] font-semibold mt-1">
                  ฿{product.price.toLocaleString()}
                </div>
              </div>
              <div className="flex items-center gap-2 border border-[var(--color-border)] rounded-lg px-2 py-1">
                <button onClick={() => updateQty(product.sku, qty - 1)} aria-label="ลดจำนวน">
                  <Minus size={14} />
                </button>
                <span className="w-6 text-center text-sm">{qty}</span>
                <button onClick={() => updateQty(product.sku, qty + 1)} aria-label="เพิ่มจำนวน">
                  <Plus size={14} />
                </button>
              </div>
              <button
                onClick={() => removeFromCart(product.sku)}
                className="text-[var(--color-muted)] hover:text-[var(--color-red)]"
                aria-label="ลบออกจากตะกร้า"
              >
                <Trash2 size={18} />
              </button>
            </div>
          ))}
        </div>

        <div className="bg-white border border-[var(--color-border)] rounded-xl p-5 h-fit">
          <h2 className="disp font-semibold mb-4">สรุปคำสั่งซื้อ</h2>
          <div className="flex justify-between text-sm mb-2">
            <span className="text-[var(--color-muted)]">ยอดรวมสินค้า</span>
            <span>฿{totalPrice.toLocaleString()}</span>
          </div>
          <div className="flex justify-between text-sm mb-4">
            <span className="text-[var(--color-muted)]">ค่าจัดส่ง</span>
            <span>คำนวณตอนติดต่อร้าน</span>
          </div>
          <div className="border-t border-[var(--color-border)] pt-4 flex justify-between font-semibold text-lg mb-5">
            <span>ยอดรวม</span>
            <span className="text-[var(--color-red)]">฿{totalPrice.toLocaleString()}</span>
          </div>
          <button className="w-full bg-[var(--color-red)] text-white rounded-lg py-3 font-semibold">
            ส่งคำสั่งซื้อ
          </button>
          <p className="text-[11px] text-[var(--color-muted)] mt-3 text-center">
            ทีมงานจะติดต่อกลับเพื่อยืนยันออเดอร์และแจ้งช่องทางชำระเงิน
          </p>
        </div>
      </div>
    </div>
  );
}
