import { useParams, Link } from "react-router-dom";
import { Star } from "lucide-react";
import { PRODUCTS } from "../data/products";
import { useCart } from "../context/CartContext";

const stockInfo = {
  in: { color: "#4CAF7D", label: "มีสินค้า พร้อมส่ง" },
  low: { color: "#F5B700", label: "เหลือสินค้าน้อย" },
  out: { color: "#E2574C", label: "สินค้าหมดชั่วคราว" },
};

export default function ProductDetail() {
  const { sku } = useParams();
  const { addToCart } = useCart();
  const product = PRODUCTS.find((p) => p.sku === sku);

  if (!product) {
    return (
      <div className="max-w-[1180px] mx-auto px-5 py-16 text-center">
        <p className="text-[var(--color-muted)] mb-4">ไม่พบสินค้านี้</p>
        <Link to="/products" className="text-[var(--color-red)]">
          กลับไปหน้าสินค้าทั้งหมด
        </Link>
      </div>
    );
  }

  const s = stockInfo[product.stock];

  return (
    <div className="max-w-[1180px] mx-auto px-5 py-9">
      <div className="text-xs text-[var(--color-muted)] mb-5">
        <Link to="/products" className="hover:underline">
          สินค้าทั้งหมด
        </Link>{" "}
        / {product.category} / {product.name}
      </div>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-10">
        <div className="h-[320px] bg-white border border-[var(--color-border)] rounded-2xl flex items-center justify-center text-[var(--color-muted)]">
          ภาพสินค้า
        </div>
        <div>
          <div className="mono text-xs text-[var(--color-muted)] mb-1">{product.sku}</div>
          <h1 className="disp text-2xl font-semibold mb-2">{product.name}</h1>
          <div className="flex items-center gap-2 mb-4">
            {[1, 2, 3, 4, 5].map((i) => (
              <Star
                key={i}
                size={14}
                fill={i <= Math.round(product.rating) ? "#F5B700" : "none"}
                color="#F5B700"
              />
            ))}
            <span className="text-sm text-[var(--color-muted)]">
              {product.rating} ({product.reviews} รีวิว)
            </span>
          </div>

          <div className="flex items-baseline gap-3 mb-4">
            <span className="text-[var(--color-red)] font-bold text-3xl">
              ฿{product.price.toLocaleString()}
            </span>
            {product.oldPrice && (
              <span className="text-[var(--color-muted)] line-through text-lg">
                ฿{product.oldPrice.toLocaleString()}
              </span>
            )}
          </div>

          <div className="flex items-center gap-2 mb-5 text-sm">
            <span className="w-2 h-2 rounded-full inline-block" style={{ background: s.color }} />
            <span style={{ color: s.color }}>{s.label}</span>
          </div>

          <p className="text-sm text-[#4A4D52] leading-relaxed mb-5">{product.description}</p>

          <div className="mb-6">
            <div className="text-xs text-[var(--color-muted)] mb-2">รุ่นรถที่ใช้ได้</div>
            <div className="flex gap-2 flex-wrap">
              {product.compatibleModels.map((m) => (
                <span
                  key={m}
                  className="text-xs border border-[var(--color-border)] rounded-md px-2.5 py-1"
                >
                  {m}
                </span>
              ))}
            </div>
          </div>

          <button
            onClick={() => addToCart(product)}
            disabled={product.stock === "out"}
            className="bg-[var(--color-red)] text-white rounded-lg px-8 py-3 font-semibold disabled:bg-[var(--color-border)] disabled:text-[var(--color-muted)] disabled:cursor-not-allowed"
          >
            {product.stock === "out" ? "หมดสต็อก" : "ใส่ตะกร้า"}
          </button>
        </div>
      </div>
    </div>
  );
}
