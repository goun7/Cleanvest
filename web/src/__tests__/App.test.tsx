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
    // Pro mod varsayilan: panel bekleyen testler icin (Sade mod panelleri gizler)
    localStorage.setItem("cleanvest-pro", "1");
  });

  it("cuzdan baglamadan stat kartlari ve getiri egrisi render olur", async () => {
    render(<App />);

    // Baslik: "Cleanvest" ve "scUSD" ayri span'lerde olabilir
    const heading = screen.getByRole("heading", { level: 1 });
    expect(heading.textContent).toContain("Cleanvest");
    expect(heading.textContent).toContain("scUSD");

    // Getiri egrisi sabitleri (spec ile birebir)
    expect(screen.getByText(/Dürüst Getiri Eğrisi/i)).toBeInTheDocument();
    expect(screen.getAllByText("%3.05").length).toBeGreaterThan(0);
    expect(screen.getAllByText("%2.91").length).toBeGreaterThan(0);
    expect(screen.getAllByText("%2.92").length).toBeGreaterThan(0);

    // Cikis kapisi invariant mesaji
    expect(screen.getByText(/ÇIKIŞLAR ASLA KİTLENMEZ/)).toBeInTheDocument();

    // Cuzdan bagla butonu: TEK olmali (header'da degil, panelde)
    const walletBtns = screen.getAllByRole("button", { name: /Cüzdan Bağla/i });
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

    // TR'de 'Dürüst Getiri Eğrisi'
    expect(screen.getByText(/Dürüst Getiri Eğrisi/i)).toBeInTheDocument();

    // EN'ye gec: TR iken buton "TR", hedef English
    const langBtn = screen.getByRole("button", { name: /Switch to English/i });
    expect(langBtn.textContent).toBe("TR");
    await user.click(langBtn);

    // Artik EN metinler
    expect(await screen.findByText(/Honest Yield Curve/i)).toBeInTheDocument();
    expect(localStorage.getItem("cleanvest-lang")).toBe("en");

    // Buton artik "EN" gosterir ve hedef Turkce olur
    const enBtn = screen.getByRole("button", { name: /Switch to Türkçe/i });
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
    expect(screen.getByText(/ERC-4626 enflasyon saldırısı kalkanı/i)).toBeInTheDocument();
  });

  it("erisilebilirlik: input label bagli + butonlar type belirtmis", async () => {
    const { container } = render(<App />);

    // Input, <label htmlFor> ile baglanmali (WCAG 1.3.1)
    const input = container.querySelector("#amount-input");
    expect(input).toBeTruthy();
    const label = container.querySelector('label[for="amount-input"]');
    expect(label).toBeTruthy();

    // Hicbir buton type belirtmemis olmamali (varsayilan submit riski)
    const buttons = container.querySelectorAll("button");
    expect(buttons.length).toBeGreaterThan(0);
    buttons.forEach((b) => {
      expect(b.getAttribute("type")).not.toBeNull();
    });

    // Tab butonlari aria-pressed vermeli
    const pressed = container.querySelectorAll('button[aria-pressed]');
    expect(pressed.length).toBeGreaterThanOrEqual(2);
  });

  it("risk seffafligi paneli render olur (akademik dayanakli)", () => {
    const { container } = render(<App />);

    // Panel basligi TR'de 'Risk Şeffaflığı'
    const headings = container.querySelectorAll("h2");
    const riskPanel = Array.from(headings).find((h) =>
      h.textContent?.includes("Risk Şeffaflığı")
    );
    expect(riskPanel).toBeTruthy();

    // 4 risk karti: junior/kota/T+2/test
    const panel = riskPanel?.closest("section");
    expect(panel).toBeTruthy();
    const cards = panel?.querySelectorAll(".rounded-xl.border");
    expect(cards?.length).toBeGreaterThanOrEqual(4);

    // WCAG 1.3.1: region role + aria-label (ekran okuyucu navigasyonu)
    expect(panel?.getAttribute("role")).toBe("region");
    expect(panel?.getAttribute("aria-label")).toContain("Risk");

    // Test sayisi i18n'den gelir (STALE onlemi: hard-coded DEGIL)
    expect(panel?.textContent).toContain("187");

    // Junior karti canli durum (role=status)
    const juniorCard = panel?.querySelector('[role="status"]');
    expect(juniorCard).toBeTruthy();

    // Junior tampon gosterilmeli (>= %3 kontrolu)
    expect(panel?.textContent).toContain("Junior tampon");
    // T+2 cikis garantisi
    expect(panel?.textContent).toContain("T+2");
  });

  it("footer taze test sayisini gosterir (stale degil)", () => {
    const { container } = render(<App />);
    const footer = container.querySelector("footer");
    expect(footer).toBeTruthy();
    // Stale "122/122" gecmiste yanlis sayiydi; taze sayi olmali
    expect(footer?.textContent).not.toMatch(/122\/122/);
  });

  it("tier esikleri ekranda dogru", () => {
    render(<App />);
    const ranges = screen.getAllByText(/\$250k|12\.5M/i);
    expect(ranges.length).toBeGreaterThanOrEqual(2);
  });

  // SADE/PRO mod toggle (kullanici onayi, docs/44)
  it("SADE mod panelleri gizler, PRO mod gosterir", async () => {
    localStorage.setItem("cleanvest-pro", "0");
    const user = userEvent.setup();
    render(<App />);

    // Sade moddayiz: getiri egrisi YOK, buton "Pro Mod"a gecisi gosterir
    expect(screen.queryByText(/Dürüst Getiri Eğrisi/i)).not.toBeInTheDocument();
    const toggle = screen.getByRole("button", { name: /Sade Mod/i });
    expect(toggle.getAttribute("aria-pressed")).toBe("false");

    // Pro mod'a gec
    await user.click(toggle);

    // Artik paneller gorunur
    expect(screen.getByText(/Dürüst Getiri Eğrisi/i)).toBeInTheDocument();
    expect(toggle.getAttribute("aria-pressed")).toBe("true");
    expect(localStorage.getItem("cleanvest-pro")).toBe("1");
  });

  it("PRO mod'dan SADE mod'a geri donus calisir", async () => {
    localStorage.setItem("cleanvest-pro", "1");
    const user = userEvent.setup();
    render(<App />);

    // Pro moddayiz: paneller var, buton "Pro Mod" gosterir (mevcut durumu)
    expect(screen.getByText(/Dürüst Getiri Eğrisi/i)).toBeInTheDocument();
    const toggle = screen.getByRole("button", { name: /Pro Mod/i });
    expect(toggle.getAttribute("aria-pressed")).toBe("true");

    // Sade mod'a gec
    await user.click(toggle);

    // Paneller gizlendi
    expect(screen.queryByText(/Dürüst Getiri Eğrisi/i)).not.toBeInTheDocument();
    expect(localStorage.getItem("cleanvest-pro")).toBe("0");
  });
});
