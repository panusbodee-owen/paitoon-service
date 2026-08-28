import { useMemo, useState } from "react";
import { useSearchParams } from "react-router-dom";
import ProductCard from "../components/ProductCard";
import { CATEGORIES, PRODUCTS } from "../data/products";

export default function Products() {
  const [searchParams, setSearchParams] = useSearchParams();
  const activeCategory = searchParams.get("category") || "";
  const [query, setQuery] = useState("");

  const filtered = useMemo(() => {
    return PRODUCTS.filter((p) => {
      const matchesCategory = !activeCategory || p.category === activeCategory;
      const matchesQuery =
        !query ||
        p.name.toLowerCase().includes(query.toLowerCase()) ||
        p.sku.toLowerCase().includes(query.toLowerCase());
      return matchesCategory && matchesQuery;
    });
  }, [activeCategory, query]);

  const setCategory = (label: string) => {
    if (label === activeCategory) {
      searchParams.delete("category");
    } else {
      searchParams.set("category", label);
    }
    setSearchParams(searchParams);
  };

  return (
    <div className="max-w-[1180px] mx-auto px-5 py-9">
      <h1 className="disp text-2xl font-semibold mb-5">สินค้าทั้งหมด</h1>

      <input
        value={query}
        onChange={(e) => setQuery(e.target.value)}
        placeholder="ค้นหาชื่อสินค้าหรือรหัส SKU..."
        className="w-full max-w-md border border-[var(--color-border)] rounded-lg px-4 py-2.5 text-sm mb-5 outline-none focus:border-[var(--color-red)]"
      />

      <div className="flex gap-2.5 flex-wrap mb-7">
        {CATEGORIES.map((c) => (
          <button
            key={c.id}
            onClick={() => setCategory(c.label)}
            className={`rounded-full px-4 py-2 text-[13px] border transition ${
              activeCategory === c.label
                ? "bg-[var(--color-red)] text-white border-[var(--color-red)]"
                : "bg-white text-[#1A1B1E] border-[var(--color-border)]"
            }`}
          >
            {c.label}
          </button>
        ))}
      </div>

      <div className="text-sm text-[var(--color-muted)] mb-4">
        พบ {filtered.length} รายการ
      </div>

      {filtered.length === 0 ? (
        <div className="text-center py-16 text-[var(--color-muted)]">
          ไม่พบสินค้าที่ตรงกับเงื่อนไข ลองค้นหาด้วยคำอื่น
        </div>
      ) : (
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {filtered.map((p) => (
            <ProductCard key={p.sku} product={p} />
          ))}
        </div>
      )}
    </div>
  );
}
