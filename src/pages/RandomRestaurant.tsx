import { useRef, useState } from "react";
import { Dices, ExternalLink, MapPin, Sparkles } from "lucide-react";
import {
  FOOD_CATEGORIES,
  RESTAURANTS,
  getOrderLinks,
  type FoodCategory,
  type Restaurant,
} from "../data/restaurants";

type CategoryFilter = FoodCategory | "all";

export default function RandomRestaurant() {
  const [filter, setFilter] = useState<CategoryFilter>("all");
  const [result, setResult] = useState<Restaurant | null>(null);
  const [spinning, setSpinning] = useState(false);
  const spinTimer = useRef<ReturnType<typeof setInterval> | null>(null);

  const pool =
    filter === "all" ? RESTAURANTS : RESTAURANTS.filter((r) => r.category === filter);

  function pickRandom(exclude?: string): Restaurant {
    const options = pool.length > 1 && exclude ? pool.filter((r) => r.id !== exclude) : pool;
    return options[Math.floor(Math.random() * options.length)];
  }

  function handleSpin() {
    if (spinning || pool.length === 0) return;
    setSpinning(true);

    let ticks = 0;
    const totalTicks = 14;
    spinTimer.current = setInterval(() => {
      ticks += 1;
      setResult(pickRandom());
      if (ticks >= totalTicks) {
        if (spinTimer.current) clearInterval(spinTimer.current);
        setResult((prev) => pickRandom(prev?.id));
        setSpinning(false);
      }
    }, 80);
  }

  return (
    <>
      <section className="bg-[var(--color-black)] py-12">
        <div className="max-w-[1180px] mx-auto px-5 text-center">
          <div className="text-[var(--color-muted)] text-xs mb-2.5 tracking-wide">
            หมดตัวเลือก ไม่ต้องคิดเยอะ
          </div>
          <h1 className="disp text-3xl sm:text-4xl font-bold text-white leading-tight mb-3.5">
            สุ่มร้านเด็ด <span className="text-[var(--color-red)]">กรุงเทพฯ</span>
          </h1>
          <p className="text-[#A7ABB2] text-sm max-w-[460px] mx-auto">
            เลือกหมวดอาหาร เครื่องดื่ม หรือของหวาน แล้วกดสุ่ม ระบบจะเลือกร้านดังให้ทันที
            พร้อมช่องทางสั่งผ่าน LINE MAN, Grab และ ShopeeFood
          </p>
        </div>
      </section>

      <section className="max-w-[1180px] mx-auto px-5 py-9">
        <div className="flex flex-wrap justify-center gap-2.5 mb-8">
          <button
            onClick={() => setFilter("all")}
            className={`px-4 py-2 rounded-full text-sm font-medium border transition ${
              filter === "all"
                ? "bg-[var(--color-red)] border-[var(--color-red)] text-white"
                : "bg-white border-[var(--color-border)] text-[#1A1B1E]"
            }`}
          >
            🎲 ทั้งหมด
          </button>
          {FOOD_CATEGORIES.map((c) => (
            <button
              key={c.id}
              onClick={() => setFilter(c.id)}
              className={`px-4 py-2 rounded-full text-sm font-medium border transition ${
                filter === c.id
                  ? "bg-[var(--color-red)] border-[var(--color-red)] text-white"
                  : "bg-white border-[var(--color-border)] text-[#1A1B1E]"
              }`}
            >
              {c.emoji} {c.label}
            </button>
          ))}
        </div>

        <div className="flex justify-center mb-10">
          <button
            onClick={handleSpin}
            disabled={spinning}
            className="disp inline-flex items-center gap-2 bg-[var(--color-red)] disabled:opacity-70 text-white rounded-xl px-8 py-3.5 text-base font-semibold shadow-md hover:brightness-95 transition"
          >
            <Dices size={20} className={spinning ? "animate-spin" : ""} />
            {spinning ? "กำลังสุ่ม..." : result ? "สุ่มใหม่" : "สุ่มร้านเลย"}
          </button>
        </div>

        <div className="max-w-[560px] mx-auto">
          {!result && !spinning && (
            <div className="bg-white border border-dashed border-[var(--color-border)] rounded-2xl p-10 text-center text-[var(--color-muted)] text-sm">
              กดปุ่ม “สุ่มร้านเลย” เพื่อเริ่มค้นหาร้านเด็ดของกรุงเทพฯ
            </div>
          )}

          {result && (
            <div
              className={`bg-white border border-[var(--color-border)] rounded-2xl p-6 shadow-sm transition-opacity ${
                spinning ? "opacity-60" : "opacity-100"
              }`}
            >
              <div className="flex items-center gap-1.5 text-[var(--color-red)] text-xs font-semibold mb-2.5">
                <Sparkles size={14} />
                {FOOD_CATEGORIES.find((c) => c.id === result.category)?.emoji}{" "}
                {FOOD_CATEGORIES.find((c) => c.id === result.category)?.label}
              </div>
              <h2 className="disp text-2xl font-bold mb-1.5">{result.name}</h2>
              <div className="flex items-center gap-1 text-[var(--color-muted)] text-xs mb-3.5">
                <MapPin size={13} />
                {result.area}
              </div>
              <p className="text-sm text-[#3A3C40] mb-4 leading-relaxed">{result.description}</p>
              <div className="flex flex-wrap gap-1.5 mb-6">
                {result.tags.map((tag) => (
                  <span
                    key={tag}
                    className="bg-[var(--color-bg)] text-[var(--color-muted)] text-[11px] rounded-full px-2.5 py-1"
                  >
                    #{tag}
                  </span>
                ))}
              </div>

              <div className="text-xs font-medium text-[var(--color-muted)] mb-2.5">
                สั่งร้านนี้ผ่านแอปเดลิเวอรี
              </div>
              <div className="grid grid-cols-3 gap-2.5">
                {getOrderLinks(result.name).map((link) => (
                  <a
                    key={link.id}
                    href={link.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    style={{ backgroundColor: link.color }}
                    className="flex flex-col items-center justify-center gap-1 text-white rounded-lg py-3 text-xs font-semibold hover:brightness-95 transition"
                  >
                    {link.label}
                    <ExternalLink size={12} className="opacity-80" />
                  </a>
                ))}
              </div>
              <p className="text-[10px] text-[var(--color-muted)] mt-3 text-center">
                ลิงก์จะพาไปหน้าค้นหาชื่อร้านบนแต่ละแพลตฟอร์ม เพื่อยืนยันสาขาก่อนสั่ง
              </p>
            </div>
          )}
        </div>
      </section>
    </>
  );
}
