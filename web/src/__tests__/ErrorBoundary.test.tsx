import { describe, expect, it, vi, beforeEach } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { ErrorBoundary } from "../components/ErrorBoundary";
import { getLang, setLang, t } from "../lib/i18n";

// Hata firlatan test bileseni
function Boom(): never {
  throw new Error("test-patlamasi");
}

// Test ortaminda dil sabitle (jsdom navigator farkli olabilir);
// metinler i18n'den alinir - hard-coded DEGIL (tek kaynak kurali)
function tr(key: string): string {
  return t(getLang(), key);
}

describe("ErrorBoundary", () => {
  beforeEach(() => {
    setLang("tr");
  });

  it("hata olmadan children render eder", () => {
    render(
      <ErrorBoundary>
        <p>merhaba</p>
      </ErrorBoundary>
    );
    expect(screen.getByText("merhaba")).toBeTruthy();
  });

  it("render hatasinda beyaz ekran YERINE hata mesaji gosterir", () => {
    const spy = vi.spyOn(console, "error").mockImplementation(() => {});
    expect(() =>
      render(
        <ErrorBoundary>
          <Boom />
        </ErrorBoundary>
      )
    ).not.toThrow();
    expect(screen.getByText(tr("errTitle"))).toBeTruthy();
    // DURUST mesaj: fonlar guvende - i18n'den al (hard-coded DEGIL)
    expect(
      screen.getByText(new RegExp(tr("errBody").slice(0, 12), "i"))
    ).toBeTruthy();
    spy.mockRestore();
  });

  it("'Tekrar dene' state'i sifirlar ve children tekrar render olur", async () => {
    const spy = vi.spyOn(console, "error").mockImplementation(() => {});
    const user = userEvent.setup();

    render(
      <ErrorBoundary>
        <Boom />
      </ErrorBoundary>
    );
    expect(screen.getByText(tr("errTitle"))).toBeTruthy();

    // Tekrar dene -> hasError false, children tekrar render -> yine hata
    const btn = screen.getByRole("button", { name: /Tekrar dene/i });
    expect(btn).toBeTruthy();
    await user.click(btn);
    // Children tekrar render -> hata tekrar yakalandi
    expect(screen.getByText(tr("errTitle"))).toBeTruthy();
    spy.mockRestore();
  });

  it("buton 'Tekrar dene' type=button (form submit etmez)", () => {
    const spy = vi.spyOn(console, "error").mockImplementation(() => {});
    render(
      <ErrorBoundary>
        <Boom />
      </ErrorBoundary>
    );
    const btn = screen.getByRole("button", { name: /Tekrar dene/i });
    expect(btn.getAttribute("type")).toBe("button");
    spy.mockRestore();
  });

  it("rol=alert ile ekran okuyucuya bildirir (WCAG 4.1.3)", () => {
    const spy = vi.spyOn(console, "error").mockImplementation(() => {});
    render(
      <ErrorBoundary>
        <Boom />
      </ErrorBoundary>
    );
    // Hata bolgesi role=alert olmali (canli bolge)
    const alert = screen.getByRole("alert");
    expect(alert).toBeTruthy();
    spy.mockRestore();
  });
});
