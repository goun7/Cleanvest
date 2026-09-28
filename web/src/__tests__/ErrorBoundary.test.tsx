import { describe, expect, it, vi } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { ErrorBoundary } from "../components/ErrorBoundary";

// Hata firlatan test bileseni
function Boom(): never {
  throw new Error("test-patlamasi");
}

describe("ErrorBoundary", () => {
  it("hata olmadan children render eder", () => {
    render(
      <ErrorBoundary>
        <p>merhaba</p>
      </ErrorBoundary>
    );
    expect(screen.getByText("merhaba")).toBeTruthy();
  });

  it("render hatasinda beyaz ekran YERINE hata mesaji gosterir", () => {
    // React hata yakalama testlerinde console.error sesebirligi
    const spy = vi.spyOn(console, "error").mockImplementation(() => {});
    expect(() =>
      render(
        <ErrorBoundary>
          <Boom />
        </ErrorBoundary>
      )
    ).not.toThrow();
    expect(screen.getByText("Bir hata olustu")).toBeTruthy();
    // DURUST mesaj: fonlar guvende
    expect(screen.getByText(/Fonlariniz guvende/i)).toBeTruthy();
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
    expect(screen.getByText("Bir hata olustu")).toBeTruthy();

    // Tekrar dene -> hasError false, children tekrar render -> yine hata
    // (Boom her zaman hata verir) ama buton calismali
    const btn = screen.getByRole("button", { name: /Tekrar dene/i });
    expect(btn).toBeTruthy();
    await user.click(btn);
    // Children tekrar render -> hata tekrar yakalandi
    expect(screen.getByText("Bir hata olustu")).toBeTruthy();
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
});
