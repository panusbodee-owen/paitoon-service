import { useState } from "react";
import { Link } from "react-router-dom";
import { Heart, Star } from "lucide-react";
import type { Product } from "../data/products";
import { useCart } from "../context/CartContext";

const stockInfo = {
  in: { color: "#4CAF7D", label: "มีสินค้า" },
  low: { color: "#F5B700", label: "เหลือน้อย" },
  out: { color: "#E2574C", label: "สินค้าหมด" },
};

function Stars({ value }: { value: number }) {
  return (
    <div className="flex gap-0.5">
      {[1, 2, 3, 4, 5].map((i) => (
        <Star
          key={i}
          size={12}
          fill={i <= Math.round(value) ? "#F5B700" : "none"}
          color="#F5B700"
        />
      ))}
    </div>
  );
}

export default function ProductCard({ product }: { product: Product }) {
  const { addToCart } = useCart();
  const [wished, setWished] = useState(false);
  const s = stockInfo[product.stock];

  return (
    <div className="bg-white border border-[var(--color-border)] rounded-[10px] p-3.5 relative hover:shadow-lg hover:-translate-y-0.5 transition">
      {product.oldPrice && (
        <span className="absolute top-3 left-3 bg-[var(--color-yellow)] text-[#5A4200] text-[10px] font-semibold rounded px-1.5 py-0.5">
          ลด {Math.round((1 - product.price / product.oldPrice) * 100)}%
        </span>
      )}
      <button
        onClick={() => setWished((w) => !w)}
        className="absolute top-3 right-3 z-10"
        aria-label="เพิ่มในรายการโปรด"
      >
        <Heart size={16} color={wished ? "#E3352B" : "#7C828B"} fill={wished ? "#E3352B" : "none"} />
      </button>
      <Link to={`/product/${product.sku}`}>
        <div className="h-[110px] bg-[var(--color-bg)] rounded-lg flex items-center justify-center text-[var(--color-muted)] text-xs my-5">
          ภาพสินค้า
        </div>
        <div className="text-sm font-medium mb-1.5 min-h-[34px]">{product.name}</div>
      </Link>
      <div className="flex items-center gap-1.5 mb-2">
        <Stars value={product.rating} />
        <span className="text-[11px] text-[var(--color-muted)]">({product.reviews})</span>
      </div>
      <div className="flex items-center gap-1.5 mb-2 text-[11px]">
        <span className="w-1.5 h-1.5 rounded-full inline-block" style={{ background: s.color }} />
        <span style={{ color: s.color }}>{s.label}</span>
      </div>
      <div className="text-[11px] text-[var(--color-muted)] mb-2 truncate" title={product.compatibleModels.join(", ")}>
        ใช้ได้กับ: {product.compatibleModels.join(", ")}
      </div>
      <div className="flex items-baseline gap-1.5 mb-2.5">
        <span className="text-[var(--color-red)] font-bold text-[15px]">
          ฿{product.price.toLocaleString()}
        </span>
        {product.oldPrice && (
          <span className="text-[var(--color-muted)] text-xs line-through">
            ฿{product.oldPrice.toLocaleString()}
          </span>
        )}
      </div>
      <button
        onClick={() => addToCart(product)}
        disabled={product.stock === "out"}
        className="w-full rounded-md py-2 text-xs font-semibold text-white disabled:bg-[var(--color-border)] disabled:text-[var(--color-muted)] disabled:cursor-not-allowed"
        style={{ background: product.stock === "out" ? undefined : "#E3352B" }}
      >
        {product.stock === "out" ? "หมดสต็อก" : "ใส่ตะกร้า"}
      </button>
    </div>
  );
}
