import { Component, type ErrorInfo, type ReactNode } from "react";

/**
 * ErrorBoundary — React render hatalarinda beyaz ekran ONLER.
 *
 * WCAG 4.1.3 + genel UX: beklenmeyen hata durumunda kullaniciyi
 * bilgilendirir ve uygulamanin gerisini yasamda tutar.
 *
 * Not: sadece RENDER hatalarini yakalar (event handler icindeki
 * hatalar degil - onlar zaten try/catch ile submit'te yakalanir).
 */
interface Props {
  children: ReactNode;
}
interface State {
  hasError: boolean;
  message: string;
}

export class ErrorBoundary extends Component<Props, State> {
  constructor(props: Props) {
    super(props);
    this.state = { hasError: false, message: "" };
  }

  static getDerivedStateFromError(error: Error): State {
    return { hasError: true, message: error.message ?? "Bilinmeyen hata" };
  }

  componentDidCatch(error: Error, info: ErrorInfo): void {
    // Konsola yaz - gelistirici icin; kullaniciya gosterilmez
    console.error("ErrorBoundary yakaladi:", error, info.componentStack);
  }

  render(): ReactNode {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-fx-bg p-6 text-slate-200">
          <div className="mx-auto max-w-md rounded-xl border border-fx-red/30 bg-fx-red/5 p-6">
            <h1 className="mb-2 text-lg font-semibold text-fx-red">
              Bir hata olustu
            </h1>
            <p className="mb-4 text-sm text-slate-400">
              Uygulama beklenmeyen bir hata ile karsilasti. Fonlariniz
              guvende — bu sadece arayuz hatasidir, sozlesmeler etkilenmez.
            </p>
            <p className="mb-4 break-words font-mono text-xs text-slate-500">
              {this.state.message}
            </p>
            <button
              type="button"
              className="rounded-lg bg-fx-glow px-4 py-2 text-sm font-medium text-fx-bg hover:opacity-90"
              onClick={() => this.setState({ hasError: false, message: "" })}
            >
              Tekrar dene
            </button>
          </div>
        </div>
      );
    }
    return this.props.children;
  }
}
