import { useMemo, useState } from "react";
import { useSearchParams } from "react-router-dom";
import ProductCard from "../components/ProductCard";
import { CATEGORIES, PRODUCTS } from "../data/products";

export default function Products() {
  const [searchParams, setSearchParams] = useSearchParams();
  const activeCategory = searchParams.get("category") || "";
  const activeModel = searchParams.get("model") || "";
  const [query, setQuery] = useState("");

  const filtered = useMemo(() => {
    return PRODUCTS.filter((p) => {
      const matchesCategory = !activeCategory || p.category === activeCategory;
      const matchesModel =
        !activeModel ||
        p.compatibleModels.includes(activeModel) ||
        p.compatibleModels.includes("ทั่วไป");
      const matchesQuery =
        !query ||
        p.name.toLowerCase().includes(query.toLowerCase()) ||
        p.sku.toLowerCase().includes(query.toLowerCase());
      return matchesCategory && matchesModel && matchesQuery;
    });
  }, [activeCategory, activeModel, query]);

  const clearModel = () => {
    searchParams.delete("model");
    setSearchParams(searchParams);
  };

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
      <h1 className="disp text-2xl font-semibold mb-2">สินค้าทั้งหมด</h1>

      {activeModel && (
        <div className="flex items-center gap-2 mb-4">
          <span className="inline-flex items-center gap-1.5 bg-[var(--color-bg)] border border-[var(--color-border)] rounded-full pl-3 pr-1.5 py-1 text-xs">
            เฉพาะอะไหล่ที่ใช้กับ <b>{activeModel}</b>
            <button
              onClick={clearModel}
              aria-label={`ล้างตัวกรองรุ่น ${activeModel}`}
              className="w-5 h-5 rounded-full flex items-center justify-center hover:bg-[var(--color-border)] text-[var(--color-muted)]"
            >
              ✕
            </button>
          </span>
        </div>
      )}

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
          {activeModel && (
            <>
              {" "}หรือ{" "}
              <button onClick={clearModel} className="text-[var(--color-red)] underline">
                ล้างตัวกรองรุ่น {activeModel}
              </button>
            </>
          )}
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
