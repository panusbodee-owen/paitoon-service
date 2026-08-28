import { useState } from "react";
import { useNavigate } from "react-router-dom";
import heroCar from "../assets/hrv-hero.webp";

const HOTSPOTS = [
  { id: "light", label: "ไฟหน้า", top: "41%", left: "96%", category: "ไฟหน้า/ไฟท้าย" },
  { id: "engine", label: "เครื่องยนต์", top: "24%", left: "88%", category: "อะไหล่เครื่องยนต์" },
  { id: "brake-f", label: "เบรกหน้า", top: "70%", left: "82%", category: "อะไหล่เครื่องยนต์" },
  { id: "body", label: "ตัวถัง/กันชน", top: "67%", left: "50%", category: "" },
  { id: "brake-r", label: "เบรกหลัง", top: "70%", left: "17%", category: "อะไหล่เครื่องยนต์" },
  { id: "light-r", label: "ไฟท้าย", top: "31%", left: "4%", category: "ไฟหน้า/ไฟท้าย" },
];

export default function CarHotspots() {
  const [hovered, setHovered] = useState<string | null>(null);
  const navigate = useNavigate();

  return (
    <div className="bg-white border border-[var(--color-border)] rounded-2xl p-6 pb-4">
      <div className="text-center mb-2">
        <h2 className="disp text-lg font-semibold">ค้นหาอะไหล่จากตำแหน่งบนตัวรถ</h2>
        <p className="text-[var(--color-muted)] text-xs mt-1">
          คลิกจุดบนรถ HR-V เพื่อไปดูสินค้าหมวดนั้นทันที
        </p>
      </div>
      <div className="relative max-w-[640px] mx-auto">
        <img src={heroCar} alt="Honda HR-V ตัวอย่างสำหรับเลือกหมวดอะไหล่" className="w-full h-auto" />
        {HOTSPOTS.map((h) => (
          <button
            key={h.id}
            onMouseEnter={() => setHovered(h.id)}
            onMouseLeave={() => setHovered(null)}
            onClick={() =>
              h.category
                ? navigate(`/products?category=${encodeURIComponent(h.category)}`)
                : navigate("/products")
            }
            className="absolute -translate-x-1/2 -translate-y-1/2"
            style={{ top: h.top, left: h.left }}
            aria-label={h.label}
          >
            <span className="relative flex items-center justify-center w-6 h-6">
              <span className="absolute inline-flex h-full w-full rounded-full bg-[var(--color-red)] opacity-30 animate-ping" />
              <span className="relative w-3.5 h-3.5 rounded-full bg-white border-[3px] border-[var(--color-red)]" />
            </span>
            {hovered === h.id && (
              <span className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 whitespace-nowrap bg-[var(--color-black)] text-white text-xs rounded px-2.5 py-1">
                {h.label}
              </span>
            )}
          </button>
        ))}
      </div>
    </div>
  );
}
