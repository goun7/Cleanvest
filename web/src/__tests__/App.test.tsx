import { describe, it, expect, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import App from "../App";

// window.ethereum mock (Eip1193Provider benzeri)
const mockRequest = vi.fn();
vi.stubGlobal("ethereum", { request: mockRequest });

/**
 * UI akis testleri. Kullanici gozunden degerlendirme:
 * - dil degisimi kalici mi?
 * - tab degisimi calisir mi?
 * - guvenlik bilgisi gorunur mu?
 *
 * ONEMLI: dil butonu MEVCUT dili gosterir (TR iken "TR"), tiklama
 * hedefini aria-label/title belirtir ("Switch to English").
 */
describe("App — kullanicidan gelen UI akislari", () => {
  beforeEach(() => {
    localStorage.clear();
    localStorage.setItem("cleanvest-lang", "tr");
  });

  it("cuzdan baglamadan stat kartlari ve getiri egrisi render olur", async () => {
    render(<App />);

    // Baslik: "Cleanvest" ve "scUSD" ayri span'lerde olabilir
    const heading = screen.getByRole("heading", { level: 1 });
    expect(heading.textContent).toContain("Cleanvest");
    expect(heading.textContent).toContain("scUSD");

    // Getiri egrisi sabitleri (spec ile birebir)
    expect(screen.getByText(/Dürüst Getiri Egrisi/i)).toBeInTheDocument();
    expect(screen.getAllByText("%3.05").length).toBeGreaterThan(0);
    expect(screen.getAllByText("%2.91").length).toBeGreaterThan(0);
    expect(screen.getAllByText("%2.92").length).toBeGreaterThan(0);

    // Cikis kapisi invariant mesaji
    expect(screen.getByText(/CIKISLAR ASLA KILITLENMEZ/)).toBeInTheDocument();

    // Cuzdan bagla butonu: TEK olmali (header'da degil, panelde)
    const walletBtns = screen.getAllByRole("button", { name: /Cuzdan Bagla/i });
    expect(walletBtns).toHaveLength(1);
  });

  it("dil butonu mevcut dili gosterir (TR)", () => {
    render(<App />);
    // Mevcut dil TR -> buton "TR" gosterir, hedef English
    const langBtn = screen.getByRole("button", { name: /Switch to English/i });
    expect(langBtn.textContent).toBe("TR");
  });

  it("dil degistirme TR -> EN calisir (localStorage kalici)", async () => {
    const user = userEvent.setup();
    render(<App />);

    // TR'de 'Dürüst Getiri Egrisi'
    expect(screen.getByText(/Dürüst Getiri Egrisi/i)).toBeInTheDocument();

    // EN'ye gec: TR iken buton "TR", hedef English
    const langBtn = screen.getByRole("button", { name: /Switch to English/i });
    expect(langBtn.textContent).toBe("TR");
    await user.click(langBtn);

    // Artik EN metinler
    expect(await screen.findByText(/Honest Yield Curve/i)).toBeInTheDocument();
    expect(localStorage.getItem("cleanvest-lang")).toBe("en");

    // Buton artik "EN" gosterir ve hedef Turkce olur
    const enBtn = screen.getByRole("button", { name: /Switch to Turkce/i });
    expect(enBtn.textContent).toBe("EN");
  });

  it("Yatir/Cik tablari gecer; hesap bagli degilken islem butonu gizli", async () => {
    const user = userEvent.setup();
    render(<App />);

    // Cik tabina gec (tab metni "scUSD → cUSD" icerir)
    const redeemTab = screen.getByRole("button", { name: /scUSD → cUSD/i });
    await user.click(redeemTab);

    // Hesap bagli degilken "slippage korumali" islem butonu YOK
    // (once Cuzdan Bagla istenir - bu guvenlik icin dogru)
    expect(screen.queryByRole("button", { name: /slippage korumali/i })).toBeNull();

    // Yatir'a geri don
    const depositTab = screen.getByRole("button", { name: /cUSD → scUSD/i });
    await user.click(depositTab);
    expect(screen.queryByRole("button", { name: /slippage korumali/i })).toBeNull();
  });

  it("erc-4626 kalkani notu gorunur (guvenlik bilgisi)", () => {
    render(<App />);
    expect(screen.getByText(/ERC-4626 inflation-attack kalkani/i)).toBeInTheDocument();
  });

  it("tier esikleri ekranda dogru", () => {
    render(<App />);
    const ranges = screen.getAllByText(/\$250k|12\.5M/i);
    expect(ranges.length).toBeGreaterThanOrEqual(2);
  });
});
